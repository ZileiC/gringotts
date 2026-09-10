import 'package:drift/drift.dart';

import '../app_database.dart';

/// Data access layer for asset photos (T-09B).
///
/// Tombstone-only removal; the lowest [AssetPhoto.sort] is the cover image.
class AssetPhotoRepository {
  AssetPhotoRepository(this._db);

  final AppDatabase _db;

  /// Creates one photo row. [sort] should be the next index in display order.
  Future<AssetPhoto> create({
    required String assetId,
    required String path,
    required int sort,
  }) {
    return _db.into(_db.assetPhotos).insertReturning(
          AssetPhotosCompanion.insert(
            assetId: assetId,
            path: path,
            sort: sort,
          ),
        );
  }

  /// Creates several photo rows in one batch, starting at [startSort].
  Future<List<AssetPhoto>> createAll(
    String assetId,
    List<String> paths, {
    int startSort = 0,
  }) async {
    final rows = <AssetPhotosCompanion>[
      for (var i = 0; i < paths.length; i++)
        AssetPhotosCompanion.insert(
          assetId: assetId,
          path: paths[i],
          sort: startSort + i,
        ),
    ];
    if (rows.isEmpty) return const <AssetPhoto>[];
    await _db.batch((b) => b.insertAll(_db.assetPhotos, rows));
    return (_db.select(_db.assetPhotos)
          ..where((r) => r.assetId.equals(assetId))
          ..orderBy([(u) => OrderingTerm.asc(u.sort)]))
        .get();
  }

  /// Live photos of [assetId], cover (lowest sort) first.
  Selectable<AssetPhoto> watchForAsset(String assetId) {
    return (_db.select(_db.assetPhotos)
          ..where((r) =>
              r.assetId.equals(assetId) & r.deletedAt.isNull())
          ..orderBy([(u) => OrderingTerm.asc(u.sort)]));
  }

  /// One-shot fetch of live photos for an asset, cover first.
  Future<List<AssetPhoto>> getForAsset(String assetId) =>
      watchForAsset(assetId).get();

  /// Tombstones one photo row (never physically deletes).
  Future<int> softDelete(String id) {
    final now = DateTime.now().toUtc();
    return (_db.update(_db.assetPhotos)..where((r) => r.id.equals(id))).write(
      AssetPhotosCompanion(
        deletedAt: Value(now),
        updatedAt: Value(now),
      ),
    );
  }

  /// Rewrites the whole photo list for an asset: tombstones all current rows
  /// and inserts the new list. Used by the edit form (cover = first entry).
  Future<void> replaceForAsset(String assetId, List<String> paths) async {
    final now = DateTime.now().toUtc();
    await _db.batch((b) {
      b.update(
        _db.assetPhotos,
        AssetPhotosCompanion(
          deletedAt: Value(now),
          updatedAt: Value(now),
        ),
        where: (tbl) => tbl.assetId.equals(assetId) & tbl.deletedAt.isNull(),
      );
    });
    await createAll(assetId, paths);
  }
}
