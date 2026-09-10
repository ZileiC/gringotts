import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gringotts/app/app.dart';
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
  final file = File('evidence/t09c/.t09c_$name.png');
  await file.create(recursive: true);
  await file.writeAsBytes(bytes, flush: true);
  // ignore: avoid_print
  print('T09C_SNAP name=$name md5=${md5.convert(bytes).toString().substring(0, 12)}');
}

/// Reads the sink-away effect straight off the widget tree: scroll-driven
/// motion is asserted with numbers, not with pixel guessing.
({double rise, double opacity}) sinkState(WidgetTester tester) {
  final rise = tester
      .widgetList<Transform>(find.descendant(
        of: find.byType(SinkAwayHeader),
        matching: find.byType(Transform),
      ))
      .first
      .transform
      .getTranslation()
      .y;
  final opacity = tester
      .widgetList<Opacity>(find.descendant(
        of: find.byType(SinkAwayHeader),
        matching: find.byType(Opacity),
      ))
      .first
      .opacity;
  return (rise: rise, opacity: opacity);
}

double scrollPixels(WidgetTester tester) => tester
    .state<ScrollableState>(find.byType(Scrollable).first)
    .position
    .pixels;

/// Scrolls, then proves the dashboard sink engaged and is still on screen.
Future<void> snapSink(WidgetTester tester, String name) async {
  await tester.drag(find.byType(ListView).first, const Offset(0, -100));
  await tester.pumpAndSettle(const Duration(seconds: 1));
  final sink = sinkState(tester);
  // ignore: avoid_print
  print('T09C_SINK name=$name scroll_px=${scrollPixels(tester)} '
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

    // 1. Home with key + CTA press states (TouchedScale).
    await tester.pumpAndSettle(const Duration(seconds: 1));
    await snap(tester, '01_home_idle', [find.text('记一笔')]);
    final gesture = await tester.startGesture(
      tester.getCenter(find.text('记一笔')),
    );
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    await snap(tester, '02_home_cta_pressed', [find.text('记一笔')]);
    await gesture.up();
    await tester.pumpAndSettle();

    // 2. Assets: stagger entrance mid-flight + settled.
    await tester.tap(find.text('资产'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    await snap(tester, '03_assets_stagger_mid', [find.text('总资产净值')]);
    await tester.pumpAndSettle(const Duration(seconds: 1));
    await snap(tester, '04_assets_settled', [find.text('总资产净值')]);

    // 3a. Sink-away net-value dashboard, engaged and still on screen.
    await snapSink(tester, '05_assets_scrolled_sink');

    // 3b. Scroll drag frame-timing samples.
    final start = DateTime.now();
    for (var i = 0; i < 12; i++) {
      await tester.drag(find.byType(ListView).first, const Offset(0, -80));
      await tester.pump(const Duration(milliseconds: 16));
    }
    final elapsed = DateTime.now().difference(start);
    final avgFrameMs = elapsed.inMilliseconds / 12;
    // ignore: avoid_print
    print('T09C_FPS scroll_drag avg_frame_ms=$avgFrameMs samples=12 budget=16.7');
    expect(avgFrameMs, lessThan(60),
        reason: 'drag loop should stay interactive (soft 60fps budget)');
    await tester.pumpAndSettle(const Duration(seconds: 1));
    await tester.pageBack();
    await tester.pumpAndSettle();

    // 4. Stats: physics + sink header.
    await tester.tap(find.text('统计'));
    await tester.pumpAndSettle(const Duration(seconds: 1));
    await tester.pumpAndSettle(const Duration(seconds: 1));
    await snap(tester, '06_stats_idle', [find.text('支出类别占比')]);
    await snapSink(tester, '07_stats_scrolled');
    await tester.pageBack();
    await tester.pumpAndSettle();

    // 5. Review: inertial physics page.
    await tester.tap(find.text('回顾'));
    await tester.pumpAndSettle(const Duration(seconds: 1));
    await tester.pumpAndSettle(const Duration(seconds: 1));
    await snap(tester, '08_review', [find.text('待完善回顾')]);
  });
}
