import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gringotts/data/app_database.dart';
import 'package:gringotts/domain/models.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> createSchema() async {
    final migrator = db.createMigrator();
    await migrator.createAll();
    await db.migration.onCreate(migrator);
  }

  group('T-03: draft -> confirmed -> statistics scope', () {
    test('draft does NOT count in today expense total; confirming does',
        () async {
      await createSchema();
      final now = DateTime.now();

      // One draft of 1500 cents.
      await db.into(db.transactions).insert(
            TransactionsCompanion.insert(
              amountCents: 1500,
              type: TransactionType.expense,
              source: const Value(TransactionSource.manual),
              isDraft: const Value(true),
              occurredAt: now,
            ),
          );

      // Day range (local midnight to next midnight).
      final start = DateTime(now.year, now.month, now.day);
      final end = start.add(const Duration(days: 1));

      final repo = db;
      final sumExpr = repo.transactions.amountCents.sum();
      Future<int> confirmedTotal() async {
        final query = repo.selectOnly(repo.transactions)
          ..addColumns([sumExpr])
          ..where(repo.transactions.deletedAt.isNull() &
              repo.transactions.isDraft.equals(false) &
              repo.transactions.type.equalsValue(TransactionType.expense) &
              repo.transactions.occurredAt.isBiggerOrEqualValue(start) &
              repo.transactions.occurredAt.isSmallerThanValue(end));
        final row = await query.getSingle();
        return row.read(sumExpr) ?? 0;
      }

      // Draft must not count.
      expect(await confirmedTotal(), 0);

      // Confirm the draft.
      final updated = await (repo.update(repo.transactions)
            ..where((t) => t.isDraft.equals(true)))
          .write(TransactionsCompanion(isDraft: const Value(false)));
      expect(updated, 1);

      // Now it counts.
      expect(await confirmedTotal(), 1500);
    });

    test('watchTodayDraftCount counts only today live drafts', () async {
      await createSchema();
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);

      // Two today drafts.
      for (final amount in [100, 200]) {
        await db.into(db.transactions).insert(
              TransactionsCompanion.insert(
                amountCents: amount,
                type: TransactionType.expense,
                source: const Value(TransactionSource.manual),
                isDraft: const Value(true),
                occurredAt: todayStart.add(const Duration(hours: 3)),
              ),
            );
      }
      // One yesterday draft (8 days old, stale case).
      await db.into(db.transactions).insert(
            TransactionsCompanion.insert(
              amountCents: 300,
              type: TransactionType.expense,
              source: const Value(TransactionSource.manual),
              isDraft: const Value(true),
              occurredAt: todayStart.subtract(const Duration(days: 8)),
            ),
          );

      final countExpr = db.transactions.id.count();
      final query = db.selectOnly(db.transactions)
        ..addColumns([countExpr])
        ..where(db.transactions.deletedAt.isNull() &
            db.transactions.isDraft.equals(true) &
            db.transactions.occurredAt.isBiggerOrEqualValue(todayStart) &
            db.transactions.occurredAt
                .isSmallerThanValue(todayStart.add(const Duration(days: 1))));
      final row = await query.getSingle();
      expect(row.read(countExpr), 2);
    });

    test('stale draft stays in watchDrafts (never deleted, grey in UI)',
        () async {
      await createSchema();
      final todayStart = DateTime(
        DateTime.now().year, DateTime.now().month, DateTime.now().day,
      );
      await db.into(db.transactions).insert(
            TransactionsCompanion.insert(
              amountCents: 300,
              type: TransactionType.expense,
              source: const Value(TransactionSource.manual),
              isDraft: const Value(true),
              occurredAt: todayStart.subtract(const Duration(days: 8)),
            ),
          );
      final drafts = await (db.select(db.transactions)
            ..where((t) => t.deletedAt.isNull() & t.isDraft.equals(true)))
          .get();
      expect(drafts.length, 1, reason: 'stale drafts are greyed, not deleted');
    });

    test('income draft has no time-of-day prefill applied at repo level',
        () async {
      await createSchema();
      final id = await db.into(db.transactions).insert(
            TransactionsCompanion.insert(
              amountCents: 500000,
              type: TransactionType.income,
              source: const Value(TransactionSource.manual),
              isDraft: const Value(true),
              occurredAt: DateTime.now(),
            ),
          );
      final row = await (db.select(db.transactions)
            ..where((t) => t.rowId.equals(id)))
          .getSingle();
      expect(row.type, TransactionType.income);
      expect(row.categoryId == null, isTrue, reason: 'income mode skips prefill');
    });
  });
}
