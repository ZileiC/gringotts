import 'dart:io';
import 'dart:ui' as ui;

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gringotts/app/app.dart';
import 'package:gringotts/data/app_database.dart';
import 'package:gringotts/domain/models.dart';
import 'package:gringotts/services/photo_service.dart';
import 'package:gringotts/ui/motion.dart';
import 'package:gringotts/ui/tokens.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';

/// T-09C2 evidence: base motions (section 4) read back with numbers, plus the
/// reduce-motion degradation pass with the P4 haptic assertion.
Future<void> snap(WidgetTester tester, String name) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(const Key('app_repaint_boundary')),
  );
  final ui.Image image = await boundary.toImage(pixelRatio: 1.0);
  final ByteData? data = await image.toByteData(format: ui.ImageByteFormat.png);
  final bytes = data!.buffer.asUint8List();
  expect(bytes.sublist(0, 4), <int>[0x89, 0x50, 0x4e, 0x47],
      reason: 'frame $name must be PNG');
  final file = File('evidence/t09c2/.t09c2_$name.png');
  await file.create(recursive: true);
  await file.writeAsBytes(bytes, flush: true);
  // ignore: avoid_print
  print('T09C2_SNAP name=$name md5=${md5.convert(bytes).toString().substring(0, 12)}');
}

Widget harness(ProviderContainer container) => RepaintBoundary(
      key: const Key('app_repaint_boundary'),
      child: UncontrolledProviderScope(
        container: container,
        child: const GringottsApp(),
      ),
    );

/// The high-frequency chip bar is the only ListView on the home page; the
/// prefill row renders its chip in a Wrap, so this stays unambiguous.
Finder barChips() =>
    find.descendant(of: find.byType(ListView), matching: find.byType(MotionChip));

Finder barChip(int index) => barChips().at(index);

BoxDecoration chipDecoration(WidgetTester tester, int index) => tester
    .widget<DecoratedBox>(find
        .descendant(
          of: barChip(index),
          matching: find.byType(DecoratedBox),
        )
        .first)
    .decoration as BoxDecoration;

String hex(Color? color) =>
    color == null ? 'none' : '#${color.toARGB32().toRadixString(16).padLeft(8, '0')}';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('T-09C2 base motions: chip 150 ms, sheen 600 ms one-shot, '
      'count-up spring, hero easeOutCubic', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(harness(container));
    await tester.pumpAndSettle(const Duration(seconds: 2));

    // ---------- 1. category chip: 150 ms AnimatedContainer ----------
    final barChipsBefore = tester.widgetList<MotionChip>(barChips()).toList();
    expect(barChipsBefore, isNotEmpty,
        reason: 'high-frequency chip bar must render recent categories');
    final chipIndex =
        barChipsBefore.indexWhere((MotionChip c) => !c.selected);
    expect(chipIndex, isNonNegative,
        reason: 'the bar must offer at least one unselected category');
    final label = barChipsBefore[chipIndex].label;
    final animated = tester.widget<AnimatedContainer>(find
        .descendant(
          of: barChip(chipIndex),
          matching: find.byType(AnimatedContainer),
        )
        .first);
    expect(animated.duration, const Duration(milliseconds: 150));
    final before = chipDecoration(tester, chipIndex).color;

    await tester.tap(barChip(chipIndex));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 75));
    final mid = chipDecoration(tester, chipIndex).color;
    await tester.pumpAndSettle();
    final settled = chipDecoration(tester, chipIndex).color;
    // ignore: avoid_print
    print('T09C2_CHIP label=$label duration=${animated.duration.inMilliseconds}ms '
        'before=${hex(before)} mid=${hex(mid)} settled=${hex(settled)}');
    expect(mid, isNot(before), reason: 'the 150 ms transition must be running');
    expect(mid, isNot(AppColors.goldContainer));
    expect(settled, AppColors.goldContainer);
    await snap(tester, '01_chip_selected');

    // ---------- 2. confirm sheen: 600 ms, one shot ----------
    for (final String key in <String>['1', '2', '3']) {
      await tester.tap(find.text(key));
      await tester.pump();
    }
    final cta = find.descendant(
      of: find.byType(SheenSweep),
      matching: find.byType(TextButton),
    );
    expect(cta, findsOneWidget);
    await tester.tap(cta);
    await tester.pump();
    final sheen = tester.state<SheenSweepState>(find.byType(SheenSweep));
    // The confirm also raises the section 4 snackbar, which sits exactly over
    // the CTA; dismiss it so the 600 ms sweep is visible in the frame. The
    // sweep itself is unaffected and keeps running.
    ScaffoldMessenger.of(tester.element(find.byType(Scaffold).first))
        .hideCurrentSnackBar();
    await tester.pump(const Duration(milliseconds: 300));
    // ignore: avoid_print
    print('T09C2_SHEEN sweeping=${sheen.isSweeping} '
        'progress=${sheen.progress.toStringAsFixed(3)}');
    expect(sheen.isSweeping, isTrue);
    expect(sheen.progress, greaterThan(0.0));
    expect(sheen.progress, lessThan(1.0));
    await snap(tester, '02_confirm_sheen_mid');
    await tester.pumpAndSettle();
    expect(sheen.isSweeping, isFalse, reason: 'the sheen is one-shot');
    expect(sheen.progress, 1.0);
    await tester.pump(const Duration(seconds: 2));
    expect(sheen.isSweeping, isFalse, reason: 'the sheen must never loop');

    // ---------- 3. seed a 2-photo asset so the hero wall really relays ----------
    final db = container.read(databaseProvider);
    final photoRepo = container.read(assetPhotoRepositoryProvider);
    final runId = DateTime.now().millisecondsSinceEpoch % 1000000;
    final assetName = 'T09C2 Hero $runId';
    final photoA = await PhotoServiceBridge.savePng('A$runId');
    final photoB = await PhotoServiceBridge.savePng('B$runId');
    final asset = await db.into(db.assets).insertReturning(
          AssetsCompanion.insert(
            name: assetName,
            category: AssetCategory.ordinary,
            valueCents: 600000,
            purchasedAt: DateTime(2025, 6, 1),
            photoPath: Value(photoA),
          ),
        );
    await photoRepo.createAll(asset.id, [photoA, photoB]);
    await tester.pumpAndSettle(const Duration(seconds: 1));

    // ---------- 4. net-value count-up (assets page) ----------
    await tester.tap(find.byIcon(Icons.inventory_2));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    final counter =
        tester.state<CountUpNumberState>(find.byType(CountUpNumber));
    final midCents = counter.shownCents;
    // ignore: avoid_print
    print('T09C2_COUNTUP counting=${counter.isCounting} mid=$midCents');
    expect(counter.isCounting, isTrue);
    // One extra frame flushes the counted value into the paint before snapping.
    await tester.pump();
    await snap(tester, '03_net_value_countup_mid');
    await tester.pumpAndSettle();
    final finalCents = counter.shownCents;
    // ignore: avoid_print
    print('T09C2_COUNTUP counting=${counter.isCounting} settled=$finalCents');
    expect(counter.isCounting, isFalse);
    expect(counter.shownCents, finalCents, reason: 'must land exactly');
    expect(midCents, greaterThan(0));
    expect(midCents, lessThan(finalCents));

    // ---------- 4. hero relay curve + flow ----------
    // Only the relaying heroes are ours: FloatingActionButton ships its own
    // internal Hero with the framework default curve.
    List<Hero> relayHeroes(WidgetTester tester) => tester
        .widgetList<Hero>(find.byType(Hero))
        .where((Hero h) =>
            h.tag is String && (h.tag as String).startsWith('asset_photo_'))
        .toList();

    final listHeroes = relayHeroes(tester);
    expect(listHeroes, isNotEmpty);
    for (final Hero h in listHeroes) {
      expect(h.curve, Curves.easeOutCubic, reason: 'list tile hero curve');
    }
    // ignore: avoid_print
    print('T09C2_HERO list_heroes=${listHeroes.length} curve=easeOutCubic');
    // Enter the seeded asset (it has two photos, so the wall really relays).
    // The dev DB accumulates assets, so bring the fresh tile into view first.
    await tester.ensureVisible(find.text(assetName));
    await tester.pumpAndSettle(const Duration(milliseconds: 300));
    await tester.tap(find.text(assetName));
    await tester.pumpAndSettle(const Duration(seconds: 2));
    expect(find.byType(OutlinedButton), findsNWidgets(4),
        reason: 'the detail action row must be on screen');
    final detailHeroes = relayHeroes(tester);
    expect(detailHeroes, isNotEmpty, reason: 'hero relay must reach detail');
    for (final Hero h in detailHeroes) {
      expect(h.curve, Curves.easeOutCubic, reason: 'detail hero curve');
    }
    await snap(tester, '04_detail_hero_relay');
    await tester.pageBack();
    await tester.pumpAndSettle(const Duration(seconds: 1));
    expect(find.byType(FloatingActionButton), findsOneWidget,
        reason: 'reverse hero must land back on the assets list');
    expect(relayHeroes(tester), isNotEmpty,
        reason: 'the list-side hero destinations must be back');
    // Keep the dev DB tidy: tombstone the asset this run seeded.
    await container.read(assetRepositoryProvider).softDelete(asset.id);
    await tester.pumpAndSettle(const Duration(seconds: 1));
  });

  testWidgets('T-09C2 reduce-motion degrades every motion, keeps haptics',
      (tester) async {
    final binding = tester.binding;
    binding.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(binding.platformDispatcher.clearAccessibilityFeaturesTestValue);

    final List<MethodCall> haptics = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform,
            (MethodCall call) async {
      if (call.method == 'HapticFeedback.vibrate') {
        haptics.add(call);
      }
      return null;
    });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });

    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(harness(container));
    await tester.pumpAndSettle(const Duration(seconds: 2));

    // TouchedScale: no scale animation, haptic still delivered.
    expect(
      find.descendant(
        of: find.byType(TouchedScale),
        matching: find.byType(ScaleTransition),
      ),
      findsNothing,
    );
    for (final AnimatedContainer box in tester.widgetList<AnimatedContainer>(
      find.descendant(
        of: find.byType(MotionChip),
        matching: find.byType(AnimatedContainer),
      ),
    )) {
      expect(box.duration, Duration.zero, reason: 'chip switches instantly');
    }
    final barChipsBefore = tester.widgetList<MotionChip>(barChips()).toList();
    expect(barChipsBefore, isNotEmpty,
        reason: 'high-frequency chip bar must render recent categories');
    final chipIndex =
        barChipsBefore.indexWhere((MotionChip c) => !c.selected);
    expect(chipIndex, isNonNegative,
        reason: 'the bar must offer at least one unselected category');
    await tester.tap(barChip(chipIndex));
    await tester.pump();
    expect(chipDecoration(tester, chipIndex).color, AppColors.goldContainer,
        reason: 'reduce-motion snaps to the selected colour');

    for (final String key in <String>['1', '2']) {
      await tester.tap(find.text(key));
      await tester.pump();
    }
    await tester.tap(find.descendant(
      of: find.byType(SheenSweep),
      matching: find.byType(TextButton),
    ));
    await tester.pump();
    final sheen = tester.state<SheenSweepState>(find.byType(SheenSweep));
    expect(sheen.isSweeping, isFalse, reason: 'sheen is skipped');
    expect(sheen.progress, 0.0);
    expect(haptics.map((MethodCall c) => c.arguments),
        contains('HapticFeedbackType.mediumImpact'),
        reason: 'P4: the confirm haptic survives reduce-motion');
    await tester.pump();
    expect(find.byType(SnackBar), findsOneWidget,
        reason: 'taps still work under reduce-motion');
    // ignore: avoid_print
    print('T09C2_REDUCED haptics=${haptics.length} confirm_haptic=ok snackbar=ok');

    // Count-up renders the target straight away.
    await tester.tap(find.byIcon(Icons.inventory_2));
    await tester.pumpAndSettle(const Duration(seconds: 1));
    final counter =
        tester.state<CountUpNumberState>(find.byType(CountUpNumber));
    expect(counter.isCounting, isFalse);
    // ignore: avoid_print
    print('T09C2_REDUCED countup_instant=${counter.shownCents}');
    await snap(tester, '05_reduce_motion_assets');

    // Sink-away renders untransformed.
    await tester.drag(find.byType(ListView).first, const Offset(0, -120));
    await tester.pumpAndSettle(const Duration(seconds: 1));
    expect(
      find.descendant(
        of: find.byType(SinkAwayHeader),
        matching: find.byType(Transform),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.byType(SinkAwayHeader),
        matching: find.byType(Opacity),
      ),
      findsNothing,
    );
    await snap(tester, '06_reduce_motion_scrolled');
  });
}

/// Test bridge: saves deterministic photos through the real PhotoService
/// (same approach as the T-09B flow test).
class PhotoServiceBridge {
  static Future<String> savePng(String seed) async {
    final dir = await getApplicationSupportDirectory();
    final photosDir = '${dir.path}${Platform.pathSeparator}photos';
    final bytes =
        List<int>.generate(64 * 64 * 3, (i) => (i * 7 + seed.hashCode) % 256);
    return PhotoService.saveCompressedBridge(bytes, directory: photosDir);
  }
}
