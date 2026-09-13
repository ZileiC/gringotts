import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gringotts/app/app.dart';
import 'package:gringotts/domain/models.dart';
import 'package:gringotts/ui/tokens.dart';
import 'package:integration_test/integration_test.dart';

/// T-13a evidence on the real engine.
///
/// Part 1 - the assets net value is the page's brand number: Playfair serif +
/// the shared gold gradient, one spec with the home hero (DESIGN_MAIN 6/7).
/// Part 4 - the month sheet on a viewport shorter than its fixed 342dp: the
/// grid scrolls instead of overflowing and the cells keep the 48dp touch
/// minimum.
///
/// Preconditions declared up front (AGENTS.md evidence clause):
/// - one asset is seeded with a fixed purchase date (2026-01-01) so the net
///   value is non-zero, and it is tombstoned again at teardown (no leftover
///   live row in the development database);
/// - no photo is attached, so no file is written into the photo directory;
/// - the short-viewport frame overrides the test view size only.
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
  final file = File('evidence/t13a/.t13a_$name.png');
  await file.create(recursive: true);
  await file.writeAsBytes(bytes, flush: true);
  // ignore: avoid_print
  print('T13A_SNAP name=$name bytes=${bytes.length} '
      'md5=${md5.convert(bytes).toString().substring(0, 12)}');
}

/// The page's single gold-gradient number (exactly one ShaderMask).
TextStyle brandNumber(WidgetTester tester, String page) {
  final mask = find.byType(ShaderMask);
  expect(mask, findsOneWidget, reason: '$page has one gold-gradient number');
  final text = tester.widget<Text>(
    find.descendant(of: mask, matching: find.byType(Text)),
  );
  expect(text.style?.fontFamily, 'PlayfairDisplay');
  expect(text.style?.fontWeight, FontWeight.w600);
  expect(text.style?.fontSize, AppFont.brandNumber);
  expect(text.style?.fontFeatures, AppFont.tabularFigures);
  return text.style!;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('T-13a: assets net value (serif + gold gradient) + month sheet '
      'at a short viewport', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final repo = container.read(assetRepositoryProvider);

    // ---- declared preconditions ----
    final before = await repo.getLiveAssets();
    final seedName = 'T13A 相机';
    expect(before.where((a) => a.name == seedName), isEmpty,
        reason: 'PRECONDITION: no leftover seed from an earlier run');
    // ignore: avoid_print
    print('T13A_PRECONDITION live_assets_before=${before.length} '
        'seed=$seedName purchased_at=2026-01-01');

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

    final asset = await repo.create(
      name: seedName,
      category: AssetCategory.digital,
      valueCents: 600000,
      purchasedAt: DateTime(2026, 1, 1),
    );

    // ---- part 1: the assets page brand number ----
    await tester.tap(find.byKey(const Key('tab_assets')));
    await tester.pumpAndSettle(const Duration(seconds: 2));
    expect(find.text('总资产净值'), findsOneWidget);
    final net = brandNumber(tester, 'AssetsPage');
    // ignore: avoid_print
    print('T13A_NET_VALUE font=${net.fontFamily} weight=${net.fontWeight} '
        'size=${net.fontSize} gradient=goldAccent->goldDeep '
        'shader_masks=${tester.widgetList<ShaderMask>(find.byType(ShaderMask)).length}');
    expect(find.textContaining('/天'), findsWidgets,
        reason: 'the CPD row that must stay sans is on screen');
    final serifNodes = tester
        .widgetList<Text>(find.byType(Text))
        .where((t) => t.style?.fontFamily == 'PlayfairDisplay')
        .length;
    expect(serifNodes, 1, reason: 'the net value is the only serif node');
    await snap(tester, '01_assets_net_value', [
      find.text('总资产净值'),
      find.textContaining('/天'),
    ]);

    // ---- part 4: the month sheet, normal then short viewport ----
    await tester.tap(find.byKey(const Key('tab_home')));
    await tester.pumpAndSettle(const Duration(seconds: 1));
    await tester.tap(find.byKey(const Key('home_month_button')));
    await tester.pumpAndSettle(const Duration(seconds: 1));
    final sheet = find.byKey(const Key('home_month_sheet'));
    expect(sheet, findsOneWidget);
    // ignore: avoid_print
    print('T13A_SHEET_NORMAL window=${tester.view.physicalSize.height} '
        'sheet_h=${tester.getSize(sheet).height.toStringAsFixed(1)} '
        'cell_h=${tester.getSize(find.byKey(const Key('month_sheet_cell_1'))).height.toStringAsFixed(1)}');
    await snap(tester, '02_month_sheet_normal', [
      sheet,
      find.byKey(const Key('month_sheet_year')),
    ]);

    // Short viewport (landscape phone / split view): 300 < the fixed 342dp.
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(800, 300);
    addTearDown(tester.view.reset);
    await tester.pumpAndSettle(const Duration(seconds: 1));
    final position = tester
        .state<ScrollableState>(find.descendant(
          of: sheet,
          matching: find.byType(Scrollable),
        ))
        .position;
    final shortSheet = tester.getSize(sheet);
    // ignore: avoid_print
    print('T13A_SHEET_SHORT viewport=${tester.view.physicalSize.width.toInt()}x'
        '${tester.view.physicalSize.height.toInt()} '
        'sheet_h=${shortSheet.height.toStringAsFixed(1)} '
        'cell_h=${tester.getSize(find.byKey(const Key('month_sheet_cell_1'))).height.toStringAsFixed(1)} '
        'max_scroll=${position.maxScrollExtent.toStringAsFixed(1)}');
    expect(shortSheet.height, lessThanOrEqualTo(300.0),
        reason: 'the sheet never grows past the viewport');
    expect(position.maxScrollExtent, greaterThan(0),
        reason: 'the grid scrolls the 342 - 300 shortfall');
    for (var month = 1; month <= 12; month++) {
      expect(tester.getSize(find.byKey(Key('month_sheet_cell_$month'))).height,
          greaterThanOrEqualTo(48),
          reason: 'month $month keeps the 48dp touch minimum');
    }
    await snap(tester, '03_month_sheet_short', [sheet]);
    // The last row is reachable on the short viewport too.
    await tester.ensureVisible(find.byKey(const Key('month_sheet_cell_12')));
    await tester.pumpAndSettle();
    expect(
      tester
          .getRect(sheet)
          .contains(tester.getCenter(find.byKey(const Key('month_sheet_cell_12')))),
      isTrue,
      reason: 'the scrolled last row is inside the visible sheet',
    );
    await snap(tester, '04_month_sheet_short_last_row', [
      find.byKey(const Key('month_sheet_cell_12')),
    ]);

    // ---- restore + dev-database hygiene ----
    tester.view.reset();
    await tester.pumpAndSettle(const Duration(seconds: 1));
    await tester.tapAt(const Offset(4, 4));
    await tester.pumpAndSettle(const Duration(seconds: 1));
    expect(sheet, findsNothing);
    await repo.softDelete(asset.id);
    final after = await repo.getLiveAssets();
    expect(after.where((a) => a.name == seedName), isEmpty,
        reason: 'the seeded asset is tombstoned again');
    // ignore: avoid_print
    print('T13A_TEARDOWN seed_tombstoned=true live_assets_after=${after.length}');
  });
}
