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
import 'package:gringotts/domain/seed_ids.dart';
import 'package:gringotts/pages/asset_detail_page.dart';
import 'package:gringotts/pages/assets_page.dart';
import 'package:gringotts/services/photo_service.dart';
import 'package:gringotts/ui/motion.dart';
import 'package:gringotts/ui/tokens.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';

/// T-09C2 evidence: base motions (section 4) read back with numbers, plus the
/// reduce-motion degradation pass with the P4 haptic assertion.
///
/// T-11 update: the high-frequency chip bar and the confirm sheen are gone
/// (spec removal). The 150 ms selection beat now lives on the 3x3 category
/// grid; the sheen assertions became explicit "sheen removed" proofs.
Future<void> snap(WidgetTester tester, String name) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(const Key('app_repaint_boundary')),
  );
  final ui.Image image = await boundary.toImage(pixelRatio: 1.0);
  final ByteData? data = await image.toByteData(format: ui.ImageByteFormat.png);
  final bytes = data!.buffer.asUint8List();
  expect(bytes.sublist(0, 4), <int>[0x89, 0x50, 0x4e, 0x47],
      reason: 'frame $name must be PNG');
  // T-10b/T-11 IA updates: reruns must not overwrite the original evidence.
  final file = File('evidence/regression/.t09c2_$name.png');
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

const List<String> _gridIds = <String>[
  categoryIdDining,
  categoryIdTransport,
  categoryIdShopping,
  categoryIdHousing,
  categoryIdEntertainment,
  categoryIdStudy,
  categoryIdMedical,
  categoryIdGift,
  categoryIdOther,
];

Finder gridCell(String id) => find.byKey(Key('category_cell_$id'));

BoxDecoration cellDecoration(WidgetTester tester, String id) =>
    tester.widget<AnimatedContainer>(gridCell(id)).decoration as BoxDecoration;

Color? cellBorder(WidgetTester tester, String id) =>
    (cellDecoration(tester, id).border as Border?)?.top.color;

String firstUnselectedId(WidgetTester tester) => _gridIds.firstWhere(
      (id) => cellBorder(tester, id) != AppColors.goldAccent,
    );

String hex(Color? color) =>
    color == null ? 'none' : '#${color.toARGB32().toRadixString(16).padLeft(8, '0')}';

Future<void> enterSpeedEntry(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('home_record_key')));
  await tester.pumpAndSettle(const Duration(seconds: 2));
}

/// Tombstones the records this test creates (evidence clause: a script cleans
/// up the rows it seeds). The confirm taps below now write formal records
/// (T-12c), which are tombstoned here so they cannot leak into later runs.
Future<void> captureRecordsForCleanup(
  WidgetTester tester,
  ProviderContainer container,
) async {
  final repo = container.read(transactionRepositoryProvider);
  final before = (await repo.watchAll().first).map((t) => t.id).toSet();
  addTearDown(() async {
    for (final row in await repo.watchAll().first) {
      if (!before.contains(row.id)) await repo.softDelete(row.id);
    }
  });
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('T-09C2 base motions: grid 150 ms selection, no sheen, '
      'count-up spring, hero easeOutCubic', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await captureRecordsForCleanup(tester, container);
    await tester.pumpWidget(harness(container));
    await tester.pumpAndSettle(const Duration(seconds: 2));

    // T-10b IA: keypad motions live on the secondary speed-entry page.
    await enterSpeedEntry(tester);

    // ---------- 1. category grid: 150 ms AnimatedContainer ----------
    final cellId = firstUnselectedId(tester);
    final animated = tester.widget<AnimatedContainer>(gridCell(cellId));
    expect(animated.duration, const Duration(milliseconds: 150));
    final before = cellDecoration(tester, cellId).color;

    await tester.ensureVisible(gridCell(cellId));
    await tester.pumpAndSettle();
    await tester.tap(gridCell(cellId));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 75));
    final mid = cellDecoration(tester, cellId).color;
    await tester.pumpAndSettle();
    final settled = cellDecoration(tester, cellId).color;
    // ignore: avoid_print
    print('T09C2_GRID id=$cellId duration=${animated.duration.inMilliseconds}ms '
        'before=${hex(before)} mid=${hex(mid)} settled=${hex(settled)}');
    expect(mid, isNot(before), reason: 'the 150 ms transition must be running');
    expect(settled, AppColors.goldContainer);
    await snap(tester, '01_category_selected');

    // ---------- 2. amount + confirm still work (SheenSweep was deleted as
    // dead code in T-12; the outline-style confirm asserted below via
    // gradient == null is the remaining semantic guarantee) ----------
    await tester.ensureVisible(find.byKey(const Key('key_1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('key_1')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('key_2')));
    await tester.pump();
    expect(find.text('¥ 12'), findsOneWidget);
    final confirmDecoration = tester
        .widget<DecoratedBox>(find.descendant(
          of: find.byKey(const Key('confirm_cta')),
          matching: find.byType(DecoratedBox),
        ))
        .decoration as BoxDecoration;
    expect(confirmDecoration.gradient, isNull,
        reason: 'the confirm key is outline-style, not a gold gradient fill');

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
    // T-13b hygiene: retire the seed (rows and photos) even when the run aborts
    // mid-flight - a live asset here made later scripts render the same assets
    // screen and collided in the regression frames.
    addTearDown(() async {
      for (final p in await photoRepo.getForAsset(asset.id)) {
        await photoRepo.softDelete(p.id);
      }
      await container.read(assetRepositoryProvider).softDelete(asset.id);
    });
    await tester.pumpAndSettle(const Duration(seconds: 1));

    // ---------- 4. net-value count-up (assets page) ----------
    // Since T-12c the assets page is an IndexedStack peer, so the spring starts
    // when the seed lands (while that tab is still offstage) and has landed by
    // the time the tab is on stage - a mid-flight sample is no longer
    // observable here. The spring mechanics (monotonic rise, no overshoot,
    // exact landing, restart on value change) are covered by the unit tests in
    // test/motion_base_test.dart; this step asserts the end state on the real
    // engine. T-13b: the speed-entry page's back action is its own keyed button.
    await tester.tap(find.byKey(const Key('quick_back')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('tab_assets')));
    await tester.pumpAndSettle();
    await snap(tester, '03_net_value_settled');
    final counter = tester.state<CountUpNumberState>(
      find.byKey(const Key('assets_net_value')),
    );
    final settledCents = counter.shownCents;
    // ignore: avoid_print
    print('T09C2_COUNTUP counting=${counter.isCounting} settled=$settledCents');
    expect(counter.isCounting, isFalse, reason: 'the spring has landed');
    expect(settledCents, 600000,
        reason: 'the net value lands exactly on the seeded asset value');

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
    expect(
      find.descendant(
        of: find.byType(AssetDetailPage),
        matching: find.byType(OutlinedButton),
      ),
      findsNWidgets(4),
      reason: 'the detail action row must be on screen',
    );
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
    await captureRecordsForCleanup(tester, container);
    await tester.pumpWidget(harness(container));
    await tester.pumpAndSettle(const Duration(seconds: 2));

    // T-10b IA: keypad motions live on the secondary speed-entry page.
    await enterSpeedEntry(tester);

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
        of: find.byKey(const Key('category_grid')),
        matching: find.byType(AnimatedContainer),
      ),
    )) {
      expect(box.duration, Duration.zero, reason: 'grid switches instantly');
    }

    final cellId = firstUnselectedId(tester);
    await tester.ensureVisible(gridCell(cellId));
    await tester.pumpAndSettle();
    await tester.tap(gridCell(cellId));
    await tester.pump();
    expect(cellDecoration(tester, cellId).color, AppColors.goldContainer,
        reason: 'reduce-motion snaps to the selected colour');

    await tester.ensureVisible(find.byKey(const Key('key_1')));
    await tester.pumpAndSettle();
    for (final String key in <String>['1', '2']) {
      await tester.tap(find.byKey(Key('key_$key')));
      await tester.pump();
    }
    // The sheen widget no longer exists at all (deleted in T-12).
    await tester.tap(find.byKey(const Key('confirm_cta')));
    await tester.pump();
    expect(haptics.map((MethodCall c) => c.arguments),
        contains('HapticFeedbackType.mediumImpact'),
        reason: 'P4: the confirm haptic survives reduce-motion');
    await tester.pump();
    expect(find.byType(SnackBar), findsOneWidget,
        reason: 'taps still work under reduce-motion');
    // ignore: avoid_print
    print('T09C2_REDUCED haptics=${haptics.length} confirm_haptic=ok snackbar=ok');

    // Count-up renders the target straight away.
    await tester.tap(find.byKey(const Key('quick_back')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('tab_assets')));
    await tester.pumpAndSettle(const Duration(seconds: 1));
    final counter =
        tester.state<CountUpNumberState>(find.byType(CountUpNumber));
    expect(counter.isCounting, isFalse);
    // ignore: avoid_print
    print('T09C2_REDUCED countup_instant=${counter.shownCents}');
    await snap(tester, '05_reduce_motion_assets');

    // Sink-away renders untransformed.
    await tester.drag(
      find.descendant(
        of: find.byType(AssetsPage),
        matching: find.byType(ListView),
      ).first,
      const Offset(0, -120),
    );
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
