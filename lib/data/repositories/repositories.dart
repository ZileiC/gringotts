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

  /// Stream of all live draft transactions (for the review page).
  Stream<List<Transaction>> watchDrafts() {
    return (_db.select(_db.transactions)
          ..where((t) => t.deletedAt.isNull() & t.isDraft.equals(true))
          ..orderBy([(u) => OrderingTerm.desc(u.occurredAt)]))
        .watch();
  }

  /// Count of live drafts that occurred today (home badge).
  Stream<int> watchTodayDraftCount() {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));
    final countExpr = _db.transactions.id.count();
    final query = _db.selectOnly(_db.transactions)
      ..addColumns([countExpr])
      ..where(_db.transactions.deletedAt.isNull() &
          _db.transactions.isDraft.equals(true) &
          _db.transactions.occurredAt.isBiggerOrEqualValue(startOfDay) &
          _db.transactions.occurredAt.isSmallerThanValue(endOfDay));
    return query.map((row) => row.read(countExpr) ?? 0).watchSingle();
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
  /// Updates mutable fields on a transaction (category/merchant/note).
  Future<int> updateFields(
    String id, {
    String? categoryId,
    String? merchant,
    String? note,
  }) {
    final now = DateTime.now().toUtc();
    return (_db.update(_db.transactions)..where((t) => t.id.equals(id)))
        .write(TransactionsCompanion(
      categoryId: Value(categoryId),
      merchant: Value(merchant),
      note: Value(note),
      updatedAt: Value(now),
    ));
  }
  /// Permanently marks a draft transaction as a confirmed record.
  Future<int> confirmDraft(String id) {
    return (_db.update(_db.transactions)
          ..where((t) => t.id.equals(id) & t.isDraft.equals(true)))
        .write(TransactionsCompanion(
          isDraft: const Value(false),
          updatedAt: Value(DateTime.now().toUtc()),
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

  /// Stream of all non-deleted assets, newest purchase first.
  Stream<List<Asset>> watchAll() => _db.liveAssets.watch();
}
