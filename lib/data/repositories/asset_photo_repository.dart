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

  /// Next free display index for [assetId]: one past the highest live sort,
  /// i.e. the append position at the end of the photo strip (T-09D).
  Future<int> nextSort(String assetId) async {
    final maxSort = _db.assetPhotos.sort.max();
    final row = await (_db.selectOnly(_db.assetPhotos)
          ..addColumns([maxSort])
          ..where(_db.assetPhotos.assetId.equals(assetId) &
              _db.assetPhotos.deletedAt.isNull()))
        .getSingle();
    final current = row.read(maxSort);
    return current == null ? 0 : current + 1;
  }

  /// Promotes [photoId] to cover by swapping its [sort] with the current
  /// cover's (T-09D: set-cover = sort swap, no drag reordering).
  ///
  /// Returns the number of rows rewritten (0 when nothing had to change).
  Future<int> setCover({
    required String assetId,
    required String photoId,
  }) {
    return _db.transaction(() async {
      final live = await watchForAsset(assetId).get();
      if (live.isEmpty) return 0;
      final cover = live.first;
      if (cover.id == photoId) return 0;
      AssetPhoto? target;
      for (final p in live) {
        if (p.id == photoId) {
          target = p;
          break;
        }
      }
      final chosen = target;
      if (chosen == null) return 0;
      final now = DateTime.now().toUtc();
      // Defensive: equal sorts would make the swap a no-op, so push the new
      // cover strictly below the old one.
      final coverNewSort = chosen.sort;
      final chosenNewSort =
          chosen.sort == cover.sort ? cover.sort - 1 : cover.sort;
      await (_db.update(_db.assetPhotos)..where((r) => r.id.equals(cover.id)))
          .write(AssetPhotosCompanion(
        sort: Value(coverNewSort),
        updatedAt: Value(now),
      ));
      await (_db.update(_db.assetPhotos)
            ..where((r) => r.id.equals(chosen.id)))
          .write(AssetPhotosCompanion(
        sort: Value(chosenNewSort),
        updatedAt: Value(now),
      ));
      return 2;
    });
  }

  /// Display source of truth for an asset's photos.
  ///
  /// Live rows sorted by [sort] (lowest = cover). Assets without rows fall
  /// back to the legacy single `Asset.photoPath`. The list tile cover and the
  /// detail page hero wall both call this, so the cover image can never
  /// diverge between the two pages.
  static List<String> displayPaths({
    required List<AssetPhoto> photos,
    String? legacyPath,
  }) {
    if (photos.isNotEmpty) {
      return photos.map((p) => p.path).toList(growable: false);
    }
    if (legacyPath != null && legacyPath.isNotEmpty) {
      return <String>[legacyPath];
    }
    return const <String>[];
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
