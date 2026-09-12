import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gringotts/app/app.dart';
import 'package:gringotts/domain/seed_ids.dart';
import 'package:gringotts/ui/tokens.dart';
import 'package:integration_test/integration_test.dart';

/// T-11 speed-entry evidence: idle / input / income frames, plus the retained
/// capability assertions and the 3x3-grid invariants.
///
/// Preconditions declared up front (AGENTS.md evidence clause): the draft
/// count is read back before and after, and the draft this script creates is
/// tombstoned at teardown.
Future<void> snap(WidgetTester tester, String name, List<Finder> required) async {
  for (final f in required) {
    expect(f, findsWidgets, reason: 'missing before snap $name');
  }
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(const Key('app_repaint_boundary')),
  );
  final ui.Image image = await boundary.toImage(pixelRatio: 1.0);
  final ByteData? data = await image.toByteData(format: ui.ImageByteFormat.png);
  final bytes = data!.buffer.asUint8List();
  expect(bytes.sublist(0, 4), <int>[0x89, 0x50, 0x4e, 0x47],
      reason: 'frame $name must be PNG');
  final file = File('evidence/t11/.t11_$name.png');
  await file.create(recursive: true);
  await file.writeAsBytes(bytes, flush: true);
  // ignore: avoid_print
  print('T11_SNAP name=$name md5=${md5.convert(bytes).toString().substring(0, 12)}');
}

BoxDecoration cellDecoration(WidgetTester tester, String id) =>
    tester
        .widget<AnimatedContainer>(find.byKey(Key('category_cell_$id')))
        .decoration as BoxDecoration;

Color? cellBorder(WidgetTester tester, String id) =>
    (cellDecoration(tester, id).border as Border?)?.top.color;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('T-11 speed entry: idle / input / income + retained capabilities',
      (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(
      RepaintBoundary(
        key: const Key('app_repaint_boundary'),
        child: UncontrolledProviderScope(
          container: container,
          child: const GringottsApp(),
        ),
      ),
    );
    await tester.pumpAndSettle(const Duration(seconds: 2));

    final txRepo = container.read(transactionRepositoryProvider);
    final draftsBefore = await txRepo.watchDrafts().first;
    // ignore: avoid_print
    print('T11_PRECONDITION drafts_before=${draftsBefore.length}');

    // T-10b IA: launch = analysis home -> 记一笔 -> speed-entry page.
    await tester.tap(find.byKey(const Key('home_record_cta')));
    await tester.pumpAndSettle(const Duration(seconds: 2));

    // Retained capability: top bar keeps back + review/assets/stats entries.
    expect(find.byKey(const Key('quick_back')), findsOneWidget);
    expect(find.byKey(const Key('quick_review')), findsOneWidget);
    expect(find.byKey(const Key('quick_assets')), findsOneWidget);
    expect(find.byKey(const Key('quick_stats')), findsOneWidget);

    // Layout: 12 keys with a decimal, no C key; nine grid cells.
    for (final key in <String>[
      '7', '8', '9', '4', '5', '6', '1', '2', '3', '.', '0', 'backspace',
    ]) {
      expect(find.byKey(Key('key_$key')), findsOneWidget, reason: 'key $key');
    }
    expect(find.byKey(const Key('key_C')), findsNothing);
    for (final id in <String>[
      categoryIdDining, categoryIdTransport, categoryIdShopping,
      categoryIdHousing, categoryIdEntertainment, categoryIdStudy,
      categoryIdMedical, categoryIdGift, categoryIdOther,
    ]) {
      expect(find.byKey(Key('category_cell_$id')), findsOneWidget);
    }
    expect(
      find.descendant(
        of: find.byKey(const Key('category_grid')),
        matching: find.byType(Scrollable),
      ),
      findsNothing,
      reason: 'category grid never scrolls (horizontal)',
    );

    // ---- frame 1: idle (empty amount, no draft yet) ----
    expect(find.text('¥ 0'), findsOneWidget);
    expect(find.byKey(const Key('entry_clear')), findsNothing);
    await snap(tester, '01_idle', [
      find.byKey(const Key('entry_name')),
      find.byKey(const Key('confirm_cta')),
    ]);

    // ---- frame 2: input (name -> category suggestion + amount + decimal) ----
    await tester.enterText(find.byKey(const Key('entry_name')), '瑞幸');
    await tester.pumpAndSettle();
    expect(cellBorder(tester, categoryIdDining), AppColors.goldAccent,
        reason: 'the name parser suggests 餐饮 for 瑞幸');
    await tester.ensureVisible(find.byKey(const Key('key_1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('key_1')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('key_5')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('key_.')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('key_5')));
    await tester.pump();
    expect(find.text('¥ 15.5'), findsOneWidget);
    expect(find.byKey(const Key('entry_clear')), findsOneWidget);
    await snap(tester, '02_input', [find.text('¥ 15.5')]);

    // Backspace stays functional (retained keypad capability): 15.5 -> 15.
    await tester.tap(find.byKey(const Key('key_backspace')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('key_backspace')));
    await tester.pump();
    expect(find.text('¥ 15'), findsOneWidget);

    // ---- frame 3: income mode ----
    await tester.tap(find.text('收入'));
    await tester.pumpAndSettle();
    await snap(tester, '03_income', [find.text('收入')]);

    // ---- retained capability: draft 入库 ----
    await tester.tap(find.byKey(const Key('confirm_cta')));
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.textContaining('已入账'), findsOneWidget);
    await tester.pumpAndSettle(const Duration(seconds: 2));
    final draftsAfter = await txRepo
        .watchDrafts()
        .firstWhere((l) => l.length == draftsBefore.length + 1)
        .timeout(const Duration(seconds: 10));
    final created = draftsAfter.firstWhere((t) => !draftsBefore.any((b) => b.id == t.id));
    expect(created.isDraft, isTrue);
    expect(created.amountCents, 1500);
    expect(created.type.name, 'income');
    // ignore: avoid_print
    print('T11_DRAFT id=${created.id} amount=${created.amountCents} '
        'type=${created.type.name} merchant=${created.merchant}');
    addTearDown(() => txRepo.softDelete(created.id));

    // Confirm cleared the keypad (T-11: clear lives on the amount row).
    expect(find.text('¥ 0'), findsOneWidget);
  });
}
