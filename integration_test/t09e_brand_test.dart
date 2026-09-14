import 'dart:io';
import 'dart:ui' as ui;

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gringotts/app/app.dart';
import 'package:gringotts/pages/quick_entry_page.dart';
import 'package:gringotts/ui/splash.dart';
import 'package:gringotts/ui/tokens.dart';
import 'package:integration_test/integration_test.dart';

/// T-09E brand evidence: the launch brand frame (canvas solid + logo 38% +
/// Playfair wordmark) on the real Windows engine, plus the bundled brand asset.
///
/// Evidence preconditions declared up front (AGENTS.md evidence clause):
/// - the production wiring is asserted first (real `GringottsApp`: the brand
///   moment is mounted on the first frame and gone once it finishes);
/// - the *frame capture* uses the same widget tree with an extended hold
///   ([SplashGate.holdDuration] override) so the capture cannot race the real
///   clock - the plate, the asset, the 38% geometry and the wordmark are the
///   production ones (only the hold length differs, documented in WORKLOG);
/// - the logo must be decoded (`RenderImage.image != null`) before the capture,
///   otherwise the PNG would be evidence of an empty plate.
Future<void> snap(WidgetTester tester, String name) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(const Key('app_repaint_boundary')),
  );
  final ui.Image image = await boundary.toImage(pixelRatio: 1.0);
  final ByteData? data = await image.toByteData(format: ui.ImageByteFormat.png);
  final bytes = data!.buffer.asUint8List();
  expect(bytes.sublist(0, 4), <int>[0x89, 0x50, 0x4e, 0x47],
      reason: 'frame $name must be PNG');
  final file = File('evidence/t09e/.t09e_$name.png');
  await file.create(recursive: true);
  await file.writeAsBytes(bytes, flush: true);
  // ignore: avoid_print
  print('T09E_SNAP name=$name md5=${md5.convert(bytes).toString().substring(0, 12)}');
}

Widget harness(ProviderContainer container, {required Widget child}) =>
    RepaintBoundary(
      key: const Key('app_repaint_boundary'),
      child: UncontrolledProviderScope(container: container, child: child),
    );

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('T-09E: production launch shows the brand moment then the home',
      (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(harness(container, child: const GringottsApp()));

    // First frame of the real app: the brand moment is on screen and the start
    // page is already mounted underneath it (no navigation layer). Since T-12c
    // that start page is the tab shell (analysis / assets / statistics) that
    // carries the 记一笔 action - the old "keypad home" wording is gone.
    expect(find.byKey(SplashGate.brandMomentKey), findsOneWidget,
        reason: 'the splash is visible on the very first frame');
    expect(find.text('记一笔'), findsOneWidget,
        reason: 'the tab shell is mounted from frame one');

    await tester.pumpAndSettle(const Duration(seconds: 1));
    expect(find.byKey(SplashGate.brandMomentKey), findsNothing,
        reason: 'the brand moment removes itself when it ends');
    expect(find.text('记一笔'), findsOneWidget);
    // ignore: avoid_print
    print('T09E_LAUNCH hold=${SplashGate.hold.inMilliseconds}ms '
        'fade=${SplashGate.fade.inMilliseconds}ms splash_removed=true home=记一笔');
    // T-14: the frame shows the analysis home once the brand moment is gone
    // (the old name said "keyboard", which was the M1.0 IA).
    await snap(tester, '02_home_after_splash');
  });

  testWidgets('T-09E: brand frame spec (canvas + logo 38% + Playfair wordmark)',
      (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    // The brand asset must be bundled in the built app (real bundle read).
    final asset = await rootBundle.load('brand/gringotts-logo.png');
    final magic = asset.buffer
        .asUint8List()
        .sublist(0, 4)
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
    expect(asset.lengthInBytes, greaterThan(1000000),
        reason: 'the brand logo ships with the app bundle');
    // ignore: avoid_print
    print('T09E_BRAND_ASSET bytes=${asset.lengthInBytes} magic=$magic');

    // Same tree as production, hold extended so the capture is deterministic.
    await tester.pumpWidget(harness(
      container,
      child: MaterialApp(
        title: 'Gringotts',
        theme: buildAppTheme(),
        builder: (context, child) => SplashGate(
          holdDuration: const Duration(seconds: 30),
          child: child ?? const SizedBox.shrink(),
        ),
        home: const QuickEntryPage(),
      ),
    ));

    // Let the logo PNG decode (real async work), then capture.
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    final moment = find.byKey(SplashGate.brandMomentKey);
    expect(moment, findsOneWidget, reason: 'the brand moment is holding');
    expect(tester.widget<ColoredBox>(moment).color, AppColors.canvas,
        reason: 'canvas solid plate');

    final wordmark = tester.widget<Text>(find.byKey(SplashGate.wordmarkKey));
    expect(wordmark.data, 'Gringotts');
    expect(wordmark.style?.fontFamily, 'PlayfairDisplay');
    expect(wordmark.style?.color, AppColors.goldAccent);
    expect(wordmark.style?.fontSize, AppFont.h4);
    final wordmarkSize = wordmark.style?.fontSize;

    final shortest = tester.view.physicalSize.shortestSide /
        tester.view.devicePixelRatio;
    final logoRect = tester.getRect(find.byKey(SplashGate.logoKey));
    expect(logoRect.width, closeTo(shortest * SplashGate.logoFraction, 0.5),
        reason: 'logo edge = 38% of the shortest side');
    final decoded = tester.renderObject<RenderImage>(find.descendant(
      of: find.byKey(SplashGate.logoKey),
      matching: find.byType(RawImage),
    ));
    expect(decoded.image, isNotNull,
        reason: 'the brand logo is decoded before the frame is captured');
    // ignore: avoid_print
    print('T09E_BRAND_FRAME canvas=#${AppColors.canvas.toARGB32().toRadixString(16)} '
        'window_shortest=${shortest.toStringAsFixed(1)} '
        'logo_edge=${logoRect.width.toStringAsFixed(1)} '
        'fraction=${(logoRect.width / shortest).toStringAsFixed(3)} '
        'wordmark=${wordmark.data} font=${wordmark.style?.fontFamily} '
        'wordmark_size=$wordmarkSize '
        'logo_decoded=true');
    await snap(tester, '01_splash_brand_frame');

    // Tear the tree down so the extended hold never blocks test teardown.
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
