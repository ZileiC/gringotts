import 'package:drift/drift.dart';

import '../app_database.dart';

/// Data access layer for monthly budgets (T-10).
///
/// One live row per `YYYY-MM` month key. The unique index on `year_month`
/// means writing a month again updates the existing row (upsert) rather than
/// inserting a duplicate. Removal follows the tombstone pattern - rows are
/// never physically deleted.
class BudgetRepository {
  BudgetRepository(this._db);

  final AppDatabase _db;

  static final RegExp _monthKeyPattern = RegExp(r'^\d{4}-\d{2}$');

  /// Creates or updates the budget for [yearMonth] (`YYYY-MM`).
  ///
  /// A tombstoned row for the same month is revived (its tombstone cleared)
  /// so the unique month key is never violated.
  Future<BudgetMonth> upsert({
    required String yearMonth,
    required int incomeCents,
    required int savingsTargetCents,
  }) {
    assert(_monthKeyPattern.hasMatch(yearMonth),
        'year_month must be YYYY-MM, got "$yearMonth"');
    assert(incomeCents >= 0, 'income_cents must be a non-negative integer');
    assert(savingsTargetCents >= 0,
        'savings_target_cents must be a non-negative integer');
    return _db.transaction(() async {
      final existing = await (_db.select(_db.budgetMonths)
            ..where((b) => b.yearMonth.equals(yearMonth)))
          .getSingleOrNull();
      if (existing == null) {
        return _db.into(_db.budgetMonths).insertReturning(
              BudgetMonthsCompanion.insert(
                yearMonth: yearMonth,
                incomeCents: incomeCents,
                savingsTargetCents: savingsTargetCents,
              ),
            );
      }
      final now = DateTime.now().toUtc();
      await (_db.update(_db.budgetMonths)
            ..where((b) => b.id.equals(existing.id)))
          .write(BudgetMonthsCompanion(
        incomeCents: Value(incomeCents),
        savingsTargetCents: Value(savingsTargetCents),
        updatedAt: Value(now),
        deletedAt: const Value(null),
      ));
      return (_db.select(_db.budgetMonths)
            ..where((b) => b.id.equals(existing.id)))
          .getSingle();
    });
  }

  /// Live budget for [yearMonth], or null when the month has no budget.
  Future<BudgetMonth?> getByMonth(String yearMonth) {
    return (_db.select(_db.budgetMonths)
          ..where((b) => b.yearMonth.equals(yearMonth) & b.deletedAt.isNull()))
        .getSingleOrNull();
  }

  /// Reactive live budget for [yearMonth] (home page / budget sheet).
  Stream<BudgetMonth?> watchByMonth(String yearMonth) {
    return (_db.select(_db.budgetMonths)
          ..where((b) => b.yearMonth.equals(yearMonth) & b.deletedAt.isNull()))
        .watchSingleOrNull();
  }

  /// One-shot list of live budgets, chronologically ascending.
  Future<List<BudgetMonth>> listMonths() {
    return (_db.select(_db.budgetMonths)
          ..where((b) => b.deletedAt.isNull())
          ..orderBy([(b) => OrderingTerm.asc(b.yearMonth)]))
        .get();
  }

  /// Reactive chronological list of live budgets.
  Stream<List<BudgetMonth>> watchMonths() {
    return (_db.select(_db.budgetMonths)
          ..where((b) => b.deletedAt.isNull())
          ..orderBy([(b) => OrderingTerm.asc(b.yearMonth)]))
        .watch();
  }

  /// Marks the month's planned savings as turned into an asset (T-21).
  Future<int> markSavingsConfirmed(String id, {DateTime? at}) {
    final now = (at ?? DateTime.now()).toUtc();
    return (_db.update(_db.budgetMonths)..where((b) => b.id.equals(id)))
        .write(BudgetMonthsCompanion(
      savingsConfirmedAt: Value(now),
      updatedAt: Value(now),
    ));
  }

  /// Marks the month's planned savings as skipped (T-21). No asset is written.
  Future<int> markSavingsSkipped(String id, {DateTime? at}) {
    final now = (at ?? DateTime.now()).toUtc();
    return (_db.update(_db.budgetMonths)..where((b) => b.id.equals(id)))
        .write(BudgetMonthsCompanion(
      savingsSkippedAt: Value(now),
      updatedAt: Value(now),
    ));
  }

  /// Tombstones a budget row (never physically deletes).
  Future<int> softDelete(String id) {
    final now = DateTime.now().toUtc();
    return (_db.update(_db.budgetMonths)..where((b) => b.id.equals(id))).write(
      BudgetMonthsCompanion(
        deletedAt: Value(now),
        updatedAt: Value(now),
      ),
    );
  }
}
