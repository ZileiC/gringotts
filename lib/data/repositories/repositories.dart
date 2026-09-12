import 'package:drift/drift.dart';

import '../../domain/models.dart';
import '../../domain/seed_ids.dart';
import '../app_database.dart';

/// Data access layer for bookkeeping transactions.
///
/// Physical deletes are never exposed; all removals go through [softDelete].
class TransactionRepository {
  TransactionRepository(this._db);

  final AppDatabase _db;

  /// Creates a transaction row. Amount must be provided in integer cents.
  Future<Transaction> create({
    required int amountCents,
    required TransactionType type,
    String? categoryId,
    String? merchant,
    String? note,
    required DateTime occurredAt,
    bool isDraft = false,
    TransactionSource source = TransactionSource.manual,
  }) {
    assert(amountCents >= 0, 'amount_cents must be a non-negative integer');
    return _db.into(_db.transactions).insertReturning(
          TransactionsCompanion.insert(
            amountCents: amountCents,
            type: type,
            categoryId: Value(categoryId),
            merchant: Value(merchant),
            note: Value(note),
            occurredAt: occurredAt,
            isDraft: Value(isDraft),
            source: Value(source),
          ),
        );
  }

  /// Stream of all non-deleted transactions, newest first.
  Stream<List<Transaction>> watchAll() => _db.liveTransactions.watch();

  /// Soft-deletes a transaction by setting its tombstone timestamp.
  ///
  /// The row is never physically removed (sync-ready tombstone pattern).
  Future<int> softDelete(String id) {
    return (_db.update(_db.transactions)
          ..where((t) => t.id.equals(id)))
        .write(TransactionsCompanion(
          deletedAt: Value(DateTime.now().toUtc()),
          updatedAt: Value(DateTime.now().toUtc()),
        ));
  }

  /// Restores a soft-deleted transaction by clearing its tombstone.
  Future<int> restore(String id) {
    return (_db.update(_db.transactions)
          ..where((t) => t.id.equals(id)))
        .write(TransactionsCompanion(deletedAt: const Value(null)));
  }

  /// Sum of non-draft expense cents for a local day range (T-03 test hook).
  Future<int> confirmedExpenseCentsInRange(DateTime start, DateTime end) async {
    final sumExpr = _db.transactions.amountCents.sum();
    final query = _db.selectOnly(_db.transactions)
      ..addColumns([sumExpr])
      ..where(_db.transactions.deletedAt.isNull() &
          _db.transactions.isDraft.equals(false) &
          _db.transactions.type.equalsValue(TransactionType.expense) &
          _db.transactions.occurredAt.isBiggerOrEqualValue(start) &
          _db.transactions.occurredAt.isSmallerThanValue(end));
    final row = await query.getSingle();
    return row.read(sumExpr) ?? 0;
  }
  /// Stream of recent non-draft transactions for frequency analysis.
  Stream<List<Transaction>> watchRecent({int windowDays = 14}) {
    final cutoff =
        DateTime.now().toUtc().subtract(Duration(days: windowDays));
    return (_db.select(_db.transactions)
          ..where((t) =>
              t.deletedAt.isNull() &
              t.isDraft.equals(false) &
              t.occurredAt.isBiggerOrEqualValue(cutoff))
          ..orderBy([(u) => OrderingTerm.desc(u.occurredAt)]))
        .watch();
  }

  /// Distinct live merchants, most recent first (history association).
  Future<List<String>> distinctMerchants({int limit = 50}) async {
    final rows = await (_db.select(_db.transactions)
          ..where((t) =>
              t.deletedAt.isNull() & t.merchant.isNotNull() & t.merchant.equals('').not())
          ..orderBy([(u) => OrderingTerm.desc(u.occurredAt)]))
        .get();
    final seen = <String>{};
    final result = <String>[];
    for (final row in rows) {
      final m = row.merchant!;
      if (seen.add(m)) result.add(m);
      if (result.length >= limit) break;
    }
    return result;
  }

  /// Most frequent [categoryId] for a merchant in history, or null.
  Future<String?> merchantCategory(String merchant) async {
    final rows = await (_db.select(_db.transactions)
          ..where((t) =>
              t.deletedAt.isNull() &
              t.merchant.equals(merchant) &
              t.categoryId.isNotNull()))
        .get();
    if (rows.isEmpty) return null;
    final counts = <String, int>{};
    for (final row in rows) {
      final id = row.categoryId!;
      counts[id] = (counts[id] ?? 0) + 1;
    }
    String? best;
    var bestCount = 0;
    counts.forEach((id, count) {
      if (count > bestCount) {
        best = id;
        bestCount = count;
      }
    });
    return best;
  }
  /// Full-field edit for the ledger sheet (T-12).
  ///
  /// Every editable column is written explicitly, so a `null` merchant/note
  /// actually clears the field. `is_draft` and `source` are deliberately
  /// untouched (the draft pipeline is abolished; `updated_at` is refreshed).
  Future<int> updateTransaction({
    required String id,
    required int amountCents,
    required TransactionType type,
    required String? categoryId,
    required String? merchant,
    required String? note,
    required DateTime occurredAt,
  }) {
    assert(amountCents >= 0, 'amount_cents must be a non-negative integer');
    final now = DateTime.now().toUtc();
    return (_db.update(_db.transactions)..where((t) => t.id.equals(id)))
        .write(TransactionsCompanion(
      amountCents: Value(amountCents),
      type: Value(type),
      categoryId: Value(categoryId),
      merchant: Value(merchant),
      note: Value(note),
      occurredAt: Value(occurredAt),
      updatedAt: Value(now),
    ));
  }
}

/// Data access layer for categories (fixed seeds + user-defined).
class CategoryRepository {
  CategoryRepository(this._db);

  final AppDatabase _db;

  /// Stream of all non-deleted categories in fixed sort order.
  Stream<List<Category>> watchAll() => _db.liveCategories.watch();

  /// All seed category ids in canonical order (dining .. other).
  List<String> get seedIds => const [
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

  /// Creates a user-defined category.
  Future<Category> createCustom({
    required String name,
    String? icon,
    required int sort,
  }) {
    return _db.into(_db.categories).insertReturning(
          CategoriesCompanion.insert(
            name: name,
            icon: Value(icon),
            sort: sort,
            isCustom: const Value(true),
          ),
        );
  }
}

/// Data access layer for asset records.
class AssetRepository {
  AssetRepository(this._db);

  final AppDatabase _db;

  /// Creates an asset row. Value must be provided in integer cents.
  Future<Asset> create({
    required String name,
    required AssetCategory category,
    required int valueCents,
    required DateTime purchasedAt,
    String? photoPath,
    AssetStatus status = AssetStatus.inService,
  }) {
    assert(valueCents >= 0, 'value_cents must be a non-negative integer');
    return _db.into(_db.assets).insertReturning(
          AssetsCompanion.insert(
            name: name,
            category: category,
            valueCents: valueCents,
            purchasedAt: purchasedAt,
            photoPath: Value(photoPath),
            status: Value(status),
          ),
        );
  }

  /// Updates mutable asset fields (T-09C edit entry).
  Future<int> updateAsset({
    required String id,
    required String name,
    required AssetCategory category,
    required int valueCents,
    required DateTime purchasedAt,
  }) {
    final now = DateTime.now().toUtc();
    return (_db.update(_db.assets)..where((a) => a.id.equals(id))).write(
      AssetsCompanion(
        name: Value(name),
        category: Value(category),
        valueCents: Value(valueCents),
        purchasedAt: Value(purchasedAt),
        updatedAt: Value(now),
      ),
    );
  }

  /// Marks an asset as sold with the realized price.
  Future<int> markSold({
    required String id,
    required int soldPriceCents,
    required DateTime soldAt,
  }) {
    assert(soldPriceCents >= 0, 'sold_price_cents must be non-negative');
    return (_db.update(_db.assets)
          ..where((a) => a.id.equals(id)))
        .write(AssetsCompanion(
          status: const Value(AssetStatus.sold),
          soldPriceCents: Value(soldPriceCents),
          soldAt: Value(soldAt),
          updatedAt: Value(DateTime.now().toUtc()),
        ));
  }

  /// Soft-deletes an asset by setting its tombstone timestamp.
  Future<int> softDelete(String id) {
    return (_db.update(_db.assets)
          ..where((a) => a.id.equals(id)))
        .write(AssetsCompanion(
          deletedAt: Value(DateTime.now().toUtc()),
          updatedAt: Value(DateTime.now().toUtc()),
        ));
  }

  /// One-shot fetch of live assets (CPD tests / integration assertions).
  Future<List<Asset>> getLiveAssets() => _db.liveAssets.get();

  /// Stream of in-service assets only.
  Stream<List<Asset>> watchInService() {
    return (_db.select(_db.assets)
          ..where((a) =>
              a.deletedAt.isNull() & a.status.equalsValue(AssetStatus.inService))
          ..orderBy([(u) => OrderingTerm.desc(u.purchasedAt)]))
        .watch();
  }

  /// Stream of sold assets only (realization review section).
  Stream<List<Asset>> watchSold() {
    return (_db.select(_db.assets)
          ..where((a) =>
              a.deletedAt.isNull() & a.status.equalsValue(AssetStatus.sold))
          ..orderBy([(u) => OrderingTerm.desc(u.soldAt)]))
        .watch();
  }

  /// Marks a retired asset (no longer used but kept).
  Future<int> markRetired(String id) {
    return (_db.update(_db.assets)..where((a) => a.id.equals(id)))
        .write(AssetsCompanion(
      status: const Value(AssetStatus.retired),
      updatedAt: Value(DateTime.now().toUtc()),
    ));
  }
  /// Stream of all non-deleted assets, newest purchase first.
  Stream<List<Asset>> watchAll() => _db.liveAssets.watch();
}
