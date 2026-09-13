import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gringotts/app/app.dart';
import 'package:gringotts/data/app_database.dart';
import 'package:gringotts/domain/models.dart';
import 'package:gringotts/services/cpd_calculator.dart';
import 'package:gringotts/services/photo_service.dart';
import 'package:gringotts/ui/tokens.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart'
    show ImagePickerOptions, ImagePickerPlatform, MultiImagePickerOptions;
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';

/// T-09D evidence: edit completion - purchase date (CPD recompute) + photo
/// add / delete(tombstone) / set-cover, ending on the list cover update.
/// Also proves the floating snackbar clears the confirm CTA (T-09C2 ruling).
///
/// Evidence preconditions declared up front (AGENTS.md evidence clause):
/// - the dev DB accumulates assets, so every tap is preceded by ensureVisible;
/// - the seeded rows (asset + photos) and the dev DB state are read back and
///   asserted before the UI interacts with them.
Future<void> snap(WidgetTester tester, String name) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(const Key('app_repaint_boundary')),
  );
  final ui.Image image = await boundary.toImage(pixelRatio: 1.0);
  final ByteData? data = await image.toByteData(format: ui.ImageByteFormat.png);
  final bytes = data!.buffer.asUint8List();
  expect(bytes.sublist(0, 4), <int>[0x89, 0x50, 0x4e, 0x47],
      reason: 'frame $name must be PNG');
  // T-10b IA update: reruns must not overwrite the original ticket evidence.
  final file = File('evidence/regression/.t09d_$name.png');
  await file.create(recursive: true);
  await file.writeAsBytes(bytes, flush: true);
  // ignore: avoid_print
  print('T09D_SNAP name=$name md5=${md5.convert(bytes).toString().substring(0, 12)}');
}

Widget harness(ProviderContainer container) => RepaintBoundary(
      key: const Key('app_repaint_boundary'),
      child: UncontrolledProviderScope(
        container: container,
        child: const GringottsApp(),
      ),
    );

/// Picker stand-in: returns real hash-named files produced by the app's own
/// PhotoService pipeline, so the sheet exercises compression + sha256 naming
/// for real (no platform channel involved).
class FakePicker extends ImagePickerPlatform {
  FakePicker(this.files);

  final List<XFile> files;
  int multiCalls = 0;

  @override
  Future<XFile?> getImageFromSource({
    required ImageSource source,
    ImagePickerOptions options = const ImagePickerOptions(),
  }) async =>
      files.isEmpty ? null : files.first;

  @override
  Future<List<XFile>> getMultiImageWithOptions({
    MultiImagePickerOptions options = const MultiImagePickerOptions(),
  }) async {
    multiCalls++;
    return files;
  }
}

/// Files on disk for the fake picker, written through the real pipeline.
Future<String> savePhoto(String seed) async {
  final dir = await getApplicationSupportDirectory();
  final photosDir = '${dir.path}${Platform.pathSeparator}photos';
  final bytes =
      List<int>.generate(64 * 64 * 3, (i) => (i * 7 + seed.hashCode) % 256);
  return PhotoService.saveCompressedBridge(bytes, directory: photosDir);
}

/// Path currently shown as the list tile cover for [assetId].
String listCoverPath(WidgetTester tester, String assetId) {
  final image = tester.widget<Image>(find.byKey(Key('asset_cover_$assetId')));
  return (image.image as FileImage).file.path;
}

/// Highest consecutive edit-sheet thumbnail index + 1 (strip length).
int thumbCount(WidgetTester tester) {
  var count = 0;
  while (find.byKey(Key('edit_photo_$count')).evaluate().isNotEmpty) {
    count++;
  }
  return count;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('T-09D: edit asset - date + photos + cover -> list cover updates',
      (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(harness(container));
    await tester.pumpAndSettle(const Duration(seconds: 2));

    final db = container.read(databaseProvider);
    final assetRepo = container.read(assetRepositoryProvider);
    final photoRepo = container.read(assetPhotoRepositoryProvider);
    final runId = DateTime.now().millisecondsSinceEpoch % 1000000;
    final assetName = 'T09D资产$runId';

    // ---------- precondition: seed 1 asset + 2 photos (legacy + rows) ----------
    final photoA = await savePhoto('A$runId');
    final photoB = await savePhoto('B$runId');
    final photoC = await savePhoto('C$runId');
    final photoD = await savePhoto('D$runId');
    expect(File(photoA).existsSync(), isTrue);
    final asset = await db.into(db.assets).insertReturning(
          AssetsCompanion.insert(
            name: assetName,
            category: AssetCategory.digital,
            valueCents: 730000,
            purchasedAt: DateTime(2025, 6, 1),
            // Legacy single-photo field kept populated on purpose: rows must win.
            photoPath: Value(photoA),
          ),
        );
    await photoRepo.createAll(asset.id, [photoA, photoB]);
    final seeded = await photoRepo.getForAsset(asset.id);
    expect(seeded.map((p) => p.path).toList(), [photoA, photoB]);
    expect(seeded.map((p) => p.sort).toList(), [0, 1]);

    // Photo picker stand-in for the sheet's "相册" action.
    ImagePickerPlatform.instance = FakePicker(<XFile>[XFile(photoC), XFile(photoD)]);

    // ---------- 1. list cover = lowest sort in asset_photos ----------
    // T-12c IA: the assets tab is a top-level peer.
    await tester.tap(find.byKey(const Key('tab_assets')));
    await tester.pumpAndSettle(const Duration(seconds: 2));
    await tester.ensureVisible(find.text(assetName));
    await tester.pumpAndSettle(const Duration(milliseconds: 300));
    expect(find.text(assetName), findsOneWidget);
    expect(listCoverPath(tester, asset.id), photoA,
        reason: 'cover = sort 0 row, not the legacy photoPath duplicate');
    await snap(tester, '01_list_cover_before');

    // ---------- 2. open detail -> edit sheet ----------
    await tester.tap(find.text(assetName));
    await tester.pumpAndSettle(const Duration(seconds: 2));
    await tester.ensureVisible(find.byKey(const Key('detail_edit_button')));
    await tester.pumpAndSettle(const Duration(milliseconds: 300));
    await tester.tap(find.byKey(const Key('detail_edit_button')));
    await tester.pumpAndSettle(const Duration(seconds: 1));
    expect(find.byKey(const Key('edit_date_button')), findsOneWidget);
    expect(find.text('购买日期 2025-06-01'), findsOneWidget,
        reason: 'the sheet starts from the stored purchase date');
    expect(thumbCount(tester), 2, reason: 'both seeded photos are listed');
    expect(find.text('封面'), findsOneWidget);
    expect(find.byKey(const Key('edit_photo_cover_0')), findsNothing,
        reason: 'the cover slot has no set-cover action');
    await snap(tester, '02_edit_sheet');

    // ---------- 3. purchase date -> CPD recompute ----------
    await tester.ensureVisible(find.byKey(const Key('edit_date_button')));
    await tester.pumpAndSettle(const Duration(milliseconds: 200));
    await tester.tap(find.byKey(const Key('edit_date_button')));
    await tester.pumpAndSettle(const Duration(seconds: 1));
    expect(find.byType(DatePickerDialog), findsOneWidget);
    await tester.tap(find.descendant(
      of: find.byType(DatePickerDialog),
      matching: find.text('10'),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle(const Duration(seconds: 1));
    expect(find.text('购买日期 2025-06-10'), findsOneWidget,
        reason: 'the picked date is applied to the field');
    await snap(tester, '03_date_picked');

    // ---------- 4. add photos (multi-picker -> PhotoService -> next sort) ----
    await tester.ensureVisible(find.byKey(const Key('edit_photo_add_gallery')));
    await tester.pumpAndSettle(const Duration(milliseconds: 200));
    await tester.tap(find.byKey(const Key('edit_photo_add_gallery')));
    await tester.pumpAndSettle(const Duration(seconds: 2));
    expect(thumbCount(tester), 4, reason: 'two photos were appended');
    final afterAdd = await photoRepo.getForAsset(asset.id);
    expect(afterAdd, hasLength(4));
    expect(afterAdd.take(2).map((p) => p.path).toList(), [photoA, photoB],
        reason: 'existing photos keep their slots');
    expect(afterAdd.map((p) => p.sort).toList(), [0, 1, 2, 3],
        reason: 'new photos take the next free sort (end of the strip)');
    // The two appended files went through the real pipeline (picker bytes ->
    // compress -> sha256 name). Files handed to the picker were already
    // compressed, so a re-encode produces a new content hash: assert they are
    // fresh, distinct, on-disk files rather than a fixed path.
    final addedFirst = afterAdd[2].path;
    final addedSecond = afterAdd[3].path;
    for (final added in <String>[addedFirst, addedSecond]) {
      expect(<String>[photoA, photoB].contains(added), isFalse);
      expect(File(added).existsSync(), isTrue,
          reason: 'the appended photo file must exist on disk');
    }
    expect(addedFirst, isNot(addedSecond));
    // ignore: avoid_print
    print('T09D_ADD rows=${afterAdd.map((p) => p.sort).join(",")} '
        'seeded=[0:${photoA.split(Platform.pathSeparator).last.substring(0, 8)}'
        ',1:${photoB.split(Platform.pathSeparator).last.substring(0, 8)}] '
        'added=[2:${addedFirst.split(Platform.pathSeparator).last.substring(0, 8)}'
        ',3:${addedSecond.split(Platform.pathSeparator).last.substring(0, 8)}]');
    await snap(tester, '04_photos_added');

    // ---------- 5. delete a photo: tombstone, row survives ----------
    await tester.ensureVisible(find.byKey(const Key('edit_photo_delete_3')));
    await tester.pumpAndSettle(const Duration(milliseconds: 200));
    await tester.tap(find.byKey(const Key('edit_photo_delete_3')));
    await tester.pumpAndSettle(const Duration(seconds: 1));
    expect(thumbCount(tester), 3, reason: 'the deleted photo left the strip');
    final afterDelete = await photoRepo.getForAsset(asset.id);
    expect(afterDelete.map((p) => p.path).toList(),
        [photoA, photoB, addedFirst]);
    final rawRows = await db.select(db.assetPhotos).get();
    final tombstoned = rawRows.singleWhere((r) => r.path == addedSecond);
    expect(tombstoned.deletedAt, isNotNull,
        reason: 'delete is a tombstone, never a physical delete');
    // ignore: avoid_print
    print('T09D_DELETE live=${afterDelete.length} raw_rows=${rawRows.length} '
        'tombstoned=${tombstoned.path.split(Platform.pathSeparator).last.substring(0, 8)}');

    // ---------- 6. set cover = sort swap ----------
    await tester.ensureVisible(find.byKey(const Key('edit_photo_cover_1')));
    await tester.pumpAndSettle(const Duration(milliseconds: 200));
    await tester.tap(find.byKey(const Key('edit_photo_cover_1')));
    await tester.pumpAndSettle(const Duration(seconds: 1));
    final afterCover = await photoRepo.getForAsset(asset.id);
    expect(afterCover.first.path, photoB, reason: 'chosen photo is the cover');
    expect(afterCover.map((p) => p.sort).toList(), [0, 1, 2]);
    final byPath = {for (final p in afterCover) p.path: p.sort};
    expect(byPath[photoB], 0);
    expect(byPath[photoA], 1, reason: 'sorts are swapped, not renumbered');
    expect(byPath[addedFirst], 2);
    expect(find.byKey(const Key('edit_photo_cover_0')), findsNothing,
        reason: 'the new cover slot shows the badge instead');
    await snap(tester, '05_cover_swapped');

    // ---------- 7. save: date persisted, CPD text recomputed on detail ------
    await tester.ensureVisible(find.byKey(const Key('edit_save')));
    await tester.pumpAndSettle(const Duration(milliseconds: 200));
    await tester.tap(find.byKey(const Key('edit_save')));
    await tester.pumpAndSettle(const Duration(seconds: 2));

    final updated = (await assetRepo.getLiveAssets())
        .singleWhere((a) => a.id == asset.id);
    expect(updated.purchasedAt, DateTime(2025, 6, 10));
    expect(updated.updatedAt.isAfter(asset.updatedAt), isTrue,
        reason: 'the edit refreshed updated_at');
    // Detail numbers come from the same CpdCalculator as the list.
    final expectedDays = CpdCalculator.heldDays(
      purchasedAt: updated.purchasedAt,
      asOf: DateTime.now(),
    );
    final expectedCpd = CpdCalculator.cpdForAsset(updated);
    final expectedCpdYuan = expectedCpd % 100 == 0
        ? '¥${expectedCpd ~/ 100}/天'
        : '¥${(expectedCpd / 100).toStringAsFixed(1)}/天';
    expect(find.text('持有 $expectedDays 天'), findsOneWidget,
        reason: 'holding days recomputed from the new date');
    expect(find.text(expectedCpdYuan), findsOneWidget,
        reason: 'CPD recomputed from the same source');
    // ignore: avoid_print
    print('T09D_CPD purchased=${updated.purchasedAt.toIso8601String()} '
        'days=$expectedDays cpd=$expectedCpd label=$expectedCpdYuan');
    await snap(tester, '06_detail_after_save');

    // ---------- 8. back to the list: cover image switched ----------
    await tester.pageBack();
    await tester.pumpAndSettle(const Duration(seconds: 2));
    await tester.ensureVisible(find.text(assetName));
    await tester.pumpAndSettle(const Duration(milliseconds: 300));
    expect(listCoverPath(tester, asset.id), photoB,
        reason: 'the list main image follows the new cover');
    await snap(tester, '07_list_cover_after');

    // Keep the dev DB tidy: tombstone the asset this run seeded AND the photo
    // rows it attached (T-13b: the rows used to stay live, so every pass left
    // three live asset_photos behind).
    for (final p in await photoRepo.getForAsset(asset.id)) {
      await photoRepo.softDelete(p.id);
    }
    await assetRepo.softDelete(asset.id);
    await tester.pumpAndSettle(const Duration(seconds: 1));
    final leftoverPhotos = await photoRepo.getForAsset(asset.id);
    // ignore: avoid_print
    print('T09D_TEARDOWN asset_tombstoned=true '
        'live_photos=${leftoverPhotos.length}');
  });

  testWidgets('T-09D: floating snackbar clears the confirm CTA', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    // T-13b hygiene: the confirm below writes a formal record; retire every row
    // this run created so the dev database is left exactly as it was found
    // (this script used to leave a live expense behind, which broke the strict
    // preconditions of t10b/t13b on the next full regression).
    final txRepo = container.read(transactionRepositoryProvider);
    final txBefore = (await txRepo.watchAll().first).map((t) => t.id).toSet();
    addTearDown(() async {
      for (final row in await txRepo.watchAll().first) {
        if (!txBefore.contains(row.id)) {
          await txRepo.softDelete(row.id);
        }
      }
    });
    await tester.pumpWidget(harness(container));
    await tester.pumpAndSettle(const Duration(seconds: 2));

    // T-10b IA: the keypad lives on the secondary speed-entry page.
    await tester.tap(find.byKey(const Key('home_record_cta')));
    await tester.pumpAndSettle(const Duration(seconds: 2));
    // The page scrolls on short surfaces: bring the keypad into view first.
    await tester.ensureVisible(find.byKey(const Key('key_1')));
    await tester.pumpAndSettle();
    for (final String key in <String>['1', '2', '3']) {
      await tester.tap(find.byKey(Key('key_$key')));
      await tester.pump();
    }
    final cta = find.byKey(const Key('confirm_cta'));
    expect(cta, findsOneWidget);
    await tester.tap(find.descendant(
      of: cta,
      matching: find.byType(TextButton),
    ));
    // Let the snackbar slide in (250 ms) - the sheen is still sweeping, which
    // is exactly the overlap the ruling removes.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final snackBar = tester.widget<SnackBar>(find.byType(SnackBar));
    expect(snackBar.behavior, SnackBarBehavior.floating);
    expect(
      snackBar.margin,
      const EdgeInsets.fromLTRB(
        AppSpacing.m,
        0,
        AppSpacing.m,
        AppSpacing.snackBarCtaInset,
      ),
      reason: 'the CTA inset is a token, not a magic number',
    );
    final barRect = tester.getRect(find
        .descendant(of: find.byType(SnackBar), matching: find.byType(Material))
        .first);
    final ctaRect = tester.getRect(cta);
    // ignore: avoid_print
    print('T09D_SNACKBAR behavior=${snackBar.behavior} '
        'inset=${AppSpacing.snackBarCtaInset} bar_bottom=${barRect.bottom} '
        'cta_top=${ctaRect.top} overlap=${barRect.overlaps(ctaRect)}');
    expect(barRect.overlaps(ctaRect), isFalse,
        reason: 'the snackbar must not cover the confirm button (sheen)');
    expect(barRect.bottom, lessThanOrEqualTo(ctaRect.top));
    await snap(tester, '08_snackbar_above_cta');
  });
}
