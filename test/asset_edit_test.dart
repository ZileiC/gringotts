import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gringotts/data/app_database.dart';
import 'package:gringotts/data/repositories/asset_photo_repository.dart';
import 'package:gringotts/data/repositories/repositories.dart';
import 'package:gringotts/domain/models.dart';
import 'package:gringotts/services/cpd_calculator.dart';

/// T-09D: asset edit completion - purchase date (CPD source of truth) and
/// photo management (add / delete-tombstone / set cover).
void main() {
  late AppDatabase db;
  late AssetRepository assetRepo;
  late AssetPhotoRepository photoRepo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    assetRepo = AssetRepository(db);
    photoRepo = AssetPhotoRepository(db);
  });

  tearDown(() async => db.close());

  Future<Asset> seedAsset() => assetRepo.create(
        name: 'Edit Asset',
        category: AssetCategory.digital,
        valueCents: 730000,
        purchasedAt: DateTime(2025, 1, 1),
      );

  group('purchase date edit', () {
    test('date change recomputes CPD + holding days and refreshes updated_at',
        () async {
      final asset = await seedAsset();
      final asOf = DateTime(2025, 1, 11);

      final daysBefore = CpdCalculator.heldDays(
        purchasedAt: asset.purchasedAt,
        asOf: asOf,
      );
      final cpdBefore = CpdCalculator.cpdForAsset(asset, asOf: asOf);
      // 2025-01-01 .. 2025-01-11 inclusive = 11 days; 730000 / 11 = 66363.6.
      expect(daysBefore, 11);
      expect(cpdBefore, 66364);

      // Backdate updated_at so the refresh below is observable (drift stores
      // the column default at second precision).
      final stale = DateTime.utc(2020, 1, 1);
      await (db.update(db.assets)..where((a) => a.id.equals(asset.id)))
          .write(AssetsCompanion(updatedAt: Value(stale)));
      final before = (await assetRepo.getLiveAssets()).single;
      expect(before.updatedAt.isAtSameMomentAs(stale), isTrue);

      // The edit sheet saves exactly these five fields.
      await assetRepo.updateAsset(
        id: asset.id,
        name: before.name,
        category: before.category,
        valueCents: before.valueCents,
        purchasedAt: DateTime(2025, 1, 6),
      );

      final updated = (await assetRepo.getLiveAssets()).single;
      expect(updated.purchasedAt, DateTime(2025, 1, 6));
      expect(updated.updatedAt.isAfter(before.updatedAt), isTrue,
          reason: 'editing the purchase date must refresh updated_at');

      // CPD + holding days are derived (same CpdCalculator the list/detail
      // pages use) - never a second algorithm.
      final daysAfter = CpdCalculator.heldDays(
        purchasedAt: updated.purchasedAt,
        asOf: asOf,
      );
      final cpdAfter = CpdCalculator.cpdForAsset(updated, asOf: asOf);
      expect(daysAfter, 6);
      expect(cpdAfter, 121667, reason: '730000 / 6 = 121666.7 -> 121667');
      expect(cpdAfter, isNot(cpdBefore));
    });
  });

  group('photo management', () {
    test('add appends at the end (next sort), cover stays first', () async {
      final asset = await seedAsset();
      await photoRepo.createAll(asset.id, ['/p/a.jpg', '/p/b.jpg']);
      expect(await photoRepo.nextSort(asset.id), 2);

      final appended = await photoRepo.create(
        assetId: asset.id,
        path: '/p/c.jpg',
        sort: await photoRepo.nextSort(asset.id),
      );
      expect(appended.sort, 2, reason: 'new photos go to the end');

      final photos = await photoRepo.getForAsset(asset.id);
      expect(photos.map((p) => p.path).toList(),
          ['/p/a.jpg', '/p/b.jpg', '/p/c.jpg']);
      expect(await photoRepo.nextSort(asset.id), 3);
    });

    test('delete is a tombstone: row stays, live list and cover move on',
        () async {
      final asset = await seedAsset();
      await photoRepo.createAll(asset.id, ['/p/a.jpg', '/p/b.jpg']);
      final photos = await photoRepo.getForAsset(asset.id);
      final removed = photos.first; // the cover

      await photoRepo.softDelete(removed.id);

      final live = await photoRepo.getForAsset(asset.id);
      expect(live.map((p) => p.path).toList(), ['/p/b.jpg']);
      expect(
        AssetPhotoRepository.displayPaths(photos: live, legacyPath: null).first,
        '/p/b.jpg',
        reason: 'the next photo becomes the cover',
      );

      // Never physically deleted: the raw row keeps its path + tombstone.
      final all = await db.select(db.assetPhotos).get();
      expect(all, hasLength(2));
      final tombstoned = all.singleWhere((r) => r.id == removed.id);
      expect(tombstoned.deletedAt, isNotNull);
      expect(tombstoned.path, removed.path);
      expect(tombstoned.updatedAt.isBefore(tombstoned.deletedAt!) ||
          tombstoned.updatedAt.isAtSameMomentAs(tombstoned.deletedAt!), isTrue);

      // A new photo appends after the highest LIVE sort (no slot reuse).
      expect(await photoRepo.nextSort(asset.id), 2);
    });

    test('set cover swaps sorts so the chosen photo becomes the cover',
        () async {
      final asset = await seedAsset();
      await photoRepo.createAll(asset.id, ['/p/a.jpg', '/p/b.jpg', '/p/c.jpg']);
      final before = await photoRepo.getForAsset(asset.id);
      expect(before.map((p) => p.sort).toList(), [0, 1, 2]);

      final written = await photoRepo.setCover(
        assetId: asset.id,
        photoId: before[2].id,
      );
      expect(written, 2, reason: 'swap rewrites exactly two rows');

      final after = await photoRepo.getForAsset(asset.id);
      expect(after.first.path, '/p/c.jpg');
      expect(
        AssetPhotoRepository.displayPaths(photos: after, legacyPath: null).first,
        '/p/c.jpg',
        reason: 'the list cover reads the same ordering',
      );
      final byPath = {for (final p in after) p.path: p.sort};
      // Exact swap: c took the old cover slot, a took c's old slot, b untouched.
      expect(byPath['/p/c.jpg'], 0);
      expect(byPath['/p/a.jpg'], 2);
      expect(byPath['/p/b.jpg'], 1);

      // Setting the current cover again is a no-op.
      expect(
        await photoRepo.setCover(assetId: asset.id, photoId: after.first.id),
        0,
      );
    });

    test('displayPaths: rows win, legacy single photoPath is the fallback',
        () async {
      final asset = await seedAsset();
      expect(await photoRepo.nextSort(asset.id), 0);
      expect(
        AssetPhotoRepository.displayPaths(
          photos: const <AssetPhoto>[],
          legacyPath: '/p/legacy.jpg',
        ),
        ['/p/legacy.jpg'],
      );
      expect(
        AssetPhotoRepository.displayPaths(
          photos: const <AssetPhoto>[],
          legacyPath: null,
        ),
        isEmpty,
      );

      await photoRepo.createAll(asset.id, ['/p/rows.jpg']);
      final rows = await photoRepo.getForAsset(asset.id);
      expect(
        AssetPhotoRepository.displayPaths(
          photos: rows,
          legacyPath: '/p/legacy.jpg',
        ),
        ['/p/rows.jpg'],
        reason: 'rows are the source of truth, the legacy path is not doubled',
      );
    });
  });
}
