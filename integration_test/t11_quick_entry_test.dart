import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gringotts/app/app.dart';
import 'package:gringotts/data/app_database.dart';
import 'package:gringotts/data/repositories/budget_repository.dart';
import 'package:gringotts/domain/seed_ids.dart';
import 'package:gringotts/services/budget_engine.dart';
import 'package:gringotts/ui/tokens.dart';
import 'package:integration_test/integration_test.dart';

/// T-11 speed-entry evidence: idle / input / income frames, plus the retained
/// capability assertions and the 3x3-grid invariants.
///
/// Preconditions declared up front (AGENTS.md evidence clause): the live row
/// count is read back before and after, and the formal record this script
/// creates is tombstoned at teardown.
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

/// Stub budget repository for the T-11b top-of-page frame: keeps the dev DB
/// untouched (the month budget there is tombstoned) while making the link row
/// fully deterministic.
class _StubBudgetRepo implements BudgetRepository {
  _StubBudgetRepo(this.row);
  final BudgetMonth row;

  @override
  Stream<BudgetMonth?> watchByMonth(String yearMonth) => Stream.value(row);

  @override
  Future<BudgetMonth?> getByMonth(String yearMonth) async => row;

  @override
  Future<List<BudgetMonth>> listMonths() async => <BudgetMonth>[row];

  @override
  Stream<List<BudgetMonth>> watchMonths() => Stream.value(<BudgetMonth>[row]);

  @override
  Future<BudgetMonth> upsert({
    required String yearMonth,
    required int incomeCents,
    required int savingsTargetCents,
  }) =>
      throw UnimplementedError();

  @override
  Future<int> markSavingsConfirmed(String id, {DateTime? at}) =>
      throw UnimplementedError();

  @override
  Future<int> markSavingsSkipped(String id, {DateTime? at}) =>
      throw UnimplementedError();

  @override
  Future<int> softDelete(String id) => throw UnimplementedError();
}

/// Mirrors the page's yuan formatting (70004 -> 700.04).
String _money(int cents) {
  final abs = cents.abs();
  if (abs % 100 == 0) return (abs ~/ 100).toString();
  if (abs % 10 == 0) return (abs / 100).toStringAsFixed(1);
  return (abs / 100).toStringAsFixed(2);
}

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
    final liveBefore = await txRepo.watchAll().first;
    // ignore: avoid_print
    print('T11_PRECONDITION live_tx_before=${liveBefore.length}');

    // T-12c IA: launch = tab shell -> 记一笔 -> speed-entry page (child).
    await tester.tap(find.byKey(const Key('home_record_key')));
    await tester.pumpAndSettle(const Duration(seconds: 2));

    // The top bar keeps back + the expense/income switch; the old
    // review/assets/stats entries are gone (assets/stats are peer tabs).
    expect(find.byKey(const Key('quick_back')), findsOneWidget);
    expect(find.byKey(const Key('quick_review')), findsNothing);
    expect(find.byKey(const Key('quick_assets')), findsNothing);
    expect(find.byKey(const Key('quick_stats')), findsNothing);

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

    // ---- T-12c Part B: confirm writes a formal record directly ----
    await tester.tap(find.byKey(const Key('confirm_cta')));
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.textContaining('已入账'), findsOneWidget);
    await tester.pumpAndSettle(const Duration(seconds: 2));
    final liveAfter = await txRepo
        .watchAll()
        .firstWhere((l) => l.length == liveBefore.length + 1)
        .timeout(const Duration(seconds: 10));
    final created =
        liveAfter.firstWhere((t) => !liveBefore.any((b) => b.id == t.id));
    expect(created.isDraft, isFalse,
        reason: '快记即正式: the record is formal, no confirmation step');
    expect(created.amountCents, 1500);
    expect(created.type.name, 'income');
    // ignore: avoid_print
    print('T11_RECORD id=${created.id} amount=${created.amountCents} '
        'draft=${created.isDraft} type=${created.type.name}');
    addTearDown(() => txRepo.softDelete(created.id));

    // Confirm cleared the keypad (T-11: clear lives on the amount row).
    expect(find.text('¥ 0'), findsOneWidget);
  });

  testWidgets('T-11b top-of-page frame: name + amount + budget link row',
      (tester) async {
    // Precondition (AGENTS.md evidence clause): the dev DB has no live month
    // budget (the 2026-09 row is tombstoned), so the link row would be absent.
    // A stub budget repo makes it present and deterministic without writing to
    // the dev DB; the transaction set stays real and is read back below.
    final now = DateTime.now();
    final monthKey = '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}';
    final budget = BudgetMonth(
      id: 't11b-stub-budget',
      yearMonth: monthKey,
      incomeCents: 560000,
      savingsTargetCents: 200000,
      createdAt: now,
      updatedAt: now,
    );
    final container = ProviderContainer(overrides: [
      budgetRepositoryProvider.overrideWithValue(_StubBudgetRepo(budget)),
    ]);
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
    final transactions = await txRepo.watchAll().first;
    final snapshot = BudgetEngine.compute(
      budget: budget,
      transactions: transactions,
      now: now,
    );
    expect(snapshot.remainingCents, isNotNull);
    // ignore: avoid_print
    print('T11B_PRECONDITION live_tx=${transactions.length} '
        'spent=${snapshot.spentCents} remaining=${snapshot.remainingCents} '
        'remaining_days=${snapshot.remainingDays}');

    await tester.tap(find.byKey(const Key('home_record_key')));
    await tester.pumpAndSettle(const Duration(seconds: 2));

    // Link row is live before keying (amount 0).
    final baseline = BudgetEngine.liveDailyCents(
      remainingCents: snapshot.remainingCents!,
      remainingDays: snapshot.remainingDays,
    );
    expect(
      find.textContaining('记这笔后，今天还能花 ¥${_money(baseline)}'),
      findsOneWidget,
    );

    await tester.enterText(find.byKey(const Key('entry_name')), '瑞幸');
    await tester.pumpAndSettle();
    for (final key in <String>['1', '5']) {
      final finder = find.byKey(Key('key_$key'));
      await tester.ensureVisible(finder);
      await tester.pumpAndSettle();
      await tester.tap(finder);
      await tester.pumpAndSettle();
    }

    // Stop at the page top for the evidence frame (name + amount + link row).
    await tester.ensureVisible(find.byKey(const Key('entry_name')));
    await tester.pumpAndSettle();

    final projected = BudgetEngine.liveDailyCents(
      remainingCents: snapshot.remainingCents! - 1500,
      remainingDays: snapshot.remainingDays,
    );
    expect(
      find.textContaining('记这笔后，今天还能花 ¥${_money(projected)}'),
      findsOneWidget,
      reason: 'the link row must reflect the keyed amount',
    );

    // All three rows must actually be inside the captured frame.
    final screen = tester.getRect(find.byKey(const Key('app_repaint_boundary')));
    for (final finder in <Finder>[
      find.byKey(const Key('entry_name')),
      find.text('¥ 15'),
      find.textContaining('记这笔后'),
    ]) {
      final rect = tester.getRect(finder);
      expect(
        screen.top <= rect.top && rect.bottom <= screen.bottom,
        isTrue,
        reason: 'row must be visible in the frame: $finder',
      );
    }

    await snap(tester, '04_top', [
      find.byKey(const Key('entry_name')),
      find.text('¥ 15'),
      find.textContaining('记这笔后'),
    ]);
  });
}
