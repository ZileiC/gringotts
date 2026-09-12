import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gringotts/app/app.dart';
import 'package:integration_test/integration_test.dart';

/// T-09E profile-mode frame sampling (DoD: debug frame costs are *not*
/// evidence; only profile numbers are reported, and the real-device 60 fps
/// verdict stays with the user's hands-on test of the release APK).
///
/// Phases: home keypad entry + confirm, assets list scroll (heaviest surface:
/// photos + CPD + net-value dashboard), detail page entry + hero paging.
///
/// Evidence preconditions (AGENTS.md evidence clause): the dev database is read
/// first to pick a real asset name, and every tap is preceded by ensureVisible
/// / a settle, so the sampled frames are real interactions rather than misses.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('profile frame sampling: keypad, assets scroll, detail hero',
      (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const GringottsApp()),
    );
    await tester.pumpAndSettle(const Duration(seconds: 2));

    if (!kProfileMode) {
      // ignore: avoid_print
      print('PERF_SKIP mode=${kReleaseMode ? 'release' : 'debug'} '
          '(frame timings are only meaningful in profile builds)');
      return;
    }

    // Precondition: pick a real asset that actually HAS a photo, so phase 3
    // exercises the hero PageView (photo-less assets render the placeholder
    // instead, and dragging it would sample nothing).
    final assets = await container.read(assetRepositoryProvider).getLiveAssets();
    final photoRepo = container.read(assetPhotoRepositoryProvider);
    String? assetName;
    var assetPhotoCount = 0;
    for (final asset in assets) {
      final photos = await photoRepo.getForAsset(asset.id);
      final hasPhoto = photos.isNotEmpty ||
          (asset.photoPath != null && File(asset.photoPath!).existsSync());
      if (!hasPhoto) continue;
      if (assetName == null || photos.length > assetPhotoCount) {
        assetName = asset.name;
        assetPhotoCount = photos.length;
      }
    }
    // ignore: avoid_print
    print('PERF_PRECONDITION live_assets=${assets.length} '
        'target=$assetName photos_at_target=${assetPhotoCount > 0 ? assetPhotoCount : 1}');

    // ---- phase 1: keypad entry + confirm (speed-entry page) ----
    await binding.watchPerformance(() async {
      // T-10b IA: the keypad is a secondary page; T-11's page scrolls, so keys
      // are brought into view before sampling.
      await tester.tap(find.byKey(const Key('home_record_cta')));
      await tester.pumpAndSettle(const Duration(seconds: 1));
      await tester.ensureVisible(find.byKey(const Key('key_1')));
      await tester.pumpAndSettle();
      for (final key in <String>['1', '2', '3']) {
        await tester.tap(find.byKey(Key('key_$key')));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await tester.tap(find.byKey(const Key('confirm_cta')));
      await tester.pumpAndSettle(const Duration(seconds: 1));
    }, reportKey: 'home_keypad_confirm');

    // ---- phase 2: assets list scroll (dashboard sink + tiles + CPD) ----
    await binding.watchPerformance(() async {
      await tester.tap(find.byKey(const Key('quick_assets')));
      await tester.pumpAndSettle(const Duration(seconds: 2));
      for (var i = 0; i < 8; i++) {
        await tester.drag(find.byType(ListView).first, const Offset(0, -160));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await tester.pumpAndSettle(const Duration(seconds: 1));
    }, reportKey: 'assets_scroll');

    // ---- phase 3: detail page entry + hero paging ----
    final target = assetName;
    if (target != null) {
      await binding.watchPerformance(() async {
        await tester.drag(find.byType(ListView).first, const Offset(0, 4000));
        await tester.pumpAndSettle(const Duration(seconds: 1));
        await tester.ensureVisible(find.text(target).first);
        await tester.pumpAndSettle(const Duration(milliseconds: 300));
        await tester.tap(find.text(target).first);
        await tester.pumpAndSettle(const Duration(seconds: 2));
        await tester.drag(find.byType(PageView).first, const Offset(-200, 0));
        await tester.pumpAndSettle(const Duration(seconds: 1));
      }, reportKey: 'detail_hero');
    }
  });
}
