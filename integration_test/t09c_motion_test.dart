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
import 'package:gringotts/pages/assets_page.dart';
import 'package:gringotts/pages/stats_page.dart';
import 'package:gringotts/ui/motion.dart';
import 'package:integration_test/integration_test.dart';

Future<void> snap(
  WidgetTester tester,
  String name,
  List<Finder> required,
) async {
  for (final f in required) {
    expect(f, findsWidgets, reason: 'missing before snap $name');
  }
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(const Key('app_repaint_boundary')),
  );
  final ui.Image image = await boundary.toImage(pixelRatio: 1.0);
  final ByteData? data =
      await image.toByteData(format: ui.ImageByteFormat.png);
  final bytes = data!.buffer.asUint8List();
  expect(bytes.sublist(0, 4), <int>[0x89, 0x50, 0x4e, 0x47],
      reason: 'frame $name must be PNG');
  // T-10b IA update: reruns must not overwrite the original ticket evidence.
  final file = File('evidence/regression/.t09c_$name.png');
  await file.create(recursive: true);
  await file.writeAsBytes(bytes, flush: true);
  // ignore: avoid_print
  print('T09C_SNAP name=$name md5=${md5.convert(bytes).toString().substring(0, 12)}');
}

/// Reads the sink-away effect straight off the widget tree: scroll-driven
/// motion is asserted with numbers, not with pixel guessing.
///
/// [page] scopes the lookup to the visible route (T-10b: the analysis home
/// and the secondary keypad stay mounted underneath, so a global finder could
/// resolve to a different route's ListView/SinkAwayHeader).
({double rise, double opacity}) sinkState(WidgetTester tester, Finder page) {
  final header = find.descendant(
    of: page,
    matching: find.byType(SinkAwayHeader),
  );
  final rise = tester
      .widgetList<Transform>(find.descendant(
        of: header,
        matching: find.byType(Transform),
      ))
      .first
      .transform
      .getTranslation()
      .y;
  final opacity = tester
      .widgetList<Opacity>(find.descendant(
        of: header,
        matching: find.byType(Opacity),
      ))
      .first
      .opacity;
  return (rise: rise, opacity: opacity);
}

double scrollPixels(WidgetTester tester, Finder page) => tester
    .state<ScrollableState>(
      find.descendant(of: page, matching: find.byType(Scrollable)).first,
    )
    .position
    .pixels;

/// Scrolls [page], then proves the dashboard sink engaged and is still on screen.
Future<void> snapSink(WidgetTester tester, String name, Finder page) async {
  await tester.drag(
    find.descendant(of: page, matching: find.byType(ListView)).first,
    const Offset(0, -100),
  );
  await tester.pumpAndSettle(const Duration(seconds: 1));
  final sink = sinkState(tester, page);
  // ignore: avoid_print
  print('T09C_SINK name=$name scroll_px=${scrollPixels(tester, page)} '
      'rise=${sink.rise.toStringAsFixed(1)} '
      'opacity=${sink.opacity.toStringAsFixed(3)}');
  expect(sink.rise, greaterThan(1.0),
      reason: 'sink-away must engage while scrolling ($name)');
  expect(sink.opacity, lessThan(0.9),
      reason: 'sink-away must fade the dashboard ($name)');
  await snap(tester, name, const <Finder>[]);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('T-09C motion evidence: stagger + sink + scale + fps',
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

    // Precondition (evidence rule): the assets list must overflow the viewport
    // for the sink-away assertion to be meaningful. The dev DB was cleaned in
    // T-09E, so seed a deterministic scrollable list; tombstone it at teardown.
    final assetRepo = container.read(assetRepositoryProvider);
    final runId = DateTime.now().millisecondsSinceEpoch % 1000000;
    for (var i = 0; i < 12; i++) {
      final asset = await assetRepo.create(
        name: 'T09C资产$runId-$i',
        category: AssetCategory.ordinary,
        valueCents: 100000 + i * 1000,
        purchasedAt: DateTime(2025, 1, 1).add(Duration(days: i)),
      );
      addTearDown(() => assetRepo.softDelete(asset.id));
    }
    await tester.pumpAndSettle(const Duration(seconds: 1));

    // 1. Speed-entry page with key + CTA press states (TouchedScale).
    // T-10b IA: the keypad is a secondary page reached from the analysis home.
    await tester.tap(find.byKey(const Key('home_record_key')));
    await tester.pumpAndSettle(const Duration(seconds: 1));
    final ctaKey = find.byKey(const Key('confirm_cta'));
    // T-14: this snap is taken after 记一笔 pushed the page, so the frame is the
    // idle speed-entry page (the old name said "home", the M1.0 IA).
    await snap(tester, '01_quick_entry_idle', [ctaKey]);
    final gesture = await tester.startGesture(tester.getCenter(ctaKey));
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    await snap(tester, '02_home_cta_pressed', [ctaKey]);
    await gesture.up();
    await tester.pumpAndSettle();

    // 2. Assets: stagger entrance mid-flight + settled. Pop back to the shell
    // first with the speed-entry page's own back action (T-13b: pageBack()
    // looks for a Material BackButton), then switch to the assets tab.
    await tester.tap(find.byKey(const Key('quick_back')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('tab_assets')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    await snap(tester, '03_assets_stagger_mid', [find.text('总资产净值')]);
    await tester.pumpAndSettle(const Duration(seconds: 1));
    await snap(tester, '04_assets_settled', [find.text('总资产净值')]);

    // 3a. Sink-away net-value dashboard, engaged and still on screen.
    await snapSink(tester, '05_assets_scrolled_sink', find.byType(AssetsPage));

    // 3b. Scroll drag frame-timing samples.
    final start = DateTime.now();
    for (var i = 0; i < 12; i++) {
      await tester.drag(
        find.descendant(
          of: find.byType(AssetsPage),
          matching: find.byType(ListView),
        ).first,
        const Offset(0, -80),
      );
      await tester.pump(const Duration(milliseconds: 16));
    }
    final elapsed = DateTime.now().difference(start);
    final avgFrameMs = elapsed.inMilliseconds / 12;
    // ignore: avoid_print
    print('T09C_FPS scroll_drag avg_frame_ms=$avgFrameMs samples=12 budget=16.7');
    expect(avgFrameMs, lessThan(60),
        reason: 'drag loop should stay interactive (soft 60fps budget)');
    await tester.pumpAndSettle(const Duration(seconds: 1));

    // 4. Stats: physics + sink header (peer tab, T-12c).
    await tester.tap(find.byKey(const Key('tab_stats')));
    await tester.pumpAndSettle(const Duration(seconds: 1));
    await tester.pumpAndSettle(const Duration(seconds: 1));
    // T-13b: the pie section is below the fold of the lazy stats list; the
    // idle frame asserts the net card that is actually on screen.
    await snap(tester, '06_stats_idle', [find.text('净结余（收入 − 支出）')]);
    await snapSink(tester, '07_stats_scrolled', find.byType(StatsPage));

    // 5. Ledger: the statistics page's child (T-12c Part A).
    await tester.tap(find.byKey(const Key('stats_ledger_entry')));
    await tester.pumpAndSettle(const Duration(seconds: 1));
    await tester.pumpAndSettle(const Duration(seconds: 1));
    await snap(tester, '08_ledger', [find.byKey(const Key('ledger_back'))]);
  });
}
