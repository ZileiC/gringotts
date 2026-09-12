import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gringotts/data/app_database.dart';
import 'package:gringotts/data/repositories/budget_repository.dart';
import 'package:gringotts/domain/models.dart';
import 'package:path/path.dart' as p;

void main() {
  // The migration test reopens the same file sequentially with a fresh
  // AppDatabase; drift's multi-instance debug guard is a false positive there.
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  late AppDatabase db;
  late BudgetRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = BudgetRepository(db);
  });

  tearDown(() async => db.close());

  group('BudgetRepository upsert', () {
    test('creates a row, then same month updates it in place', () async {
      final first = await repo.upsert(
        yearMonth: '2026-09',
        incomeCents: 500000,
        savingsTargetCents: 140000,
      );
      expect(first.incomeCents, 500000);
      expect(first.savingsTargetCents, 140000);
      expect(first.deletedAt, isNull);
      expect(first.id, isNotEmpty);

      final second = await repo.upsert(
        yearMonth: '2026-09',
        incomeCents: 520000,
        savingsTargetCents: 120000,
      );
      expect(second.id, first.id, reason: 'month key is unique: update, not insert');
      expect(second.incomeCents, 520000);
      expect(second.savingsTargetCents, 120000);

      final all = await db.select(db.budgetMonths).get();
      expect(all, hasLength(1), reason: 'no duplicate row for the same month');
    });

    test('rows are integer cents only and support zero values', () async {
      final row = await repo.upsert(
        yearMonth: '2026-08',
        incomeCents: 0,
        savingsTargetCents: 0,
      );
      expect(row.incomeCents, 0);
      expect(row.savingsTargetCents, 0);
    });
  });

  group('BudgetRepository reads', () {
    test('getByMonth returns the live row or null', () async {
      await repo.upsert(
        yearMonth: '2026-09',
        incomeCents: 500000,
        savingsTargetCents: 140000,
      );
      final found = await repo.getByMonth('2026-09');
      expect(found, isNotNull);
      expect(found!.incomeCents, 500000);
      expect(await repo.getByMonth('2026-10'), isNull);
    });

    test('listMonths is chronological and excludes tombstoned rows', () async {
      await repo.upsert(
          yearMonth: '2026-10', incomeCents: 100, savingsTargetCents: 0);
      await repo.upsert(
          yearMonth: '2026-08', incomeCents: 100, savingsTargetCents: 0);
      final sep = await repo.upsert(
          yearMonth: '2026-09', incomeCents: 100, savingsTargetCents: 0);
      await repo.softDelete(sep.id);

      final months = await repo.listMonths();
      expect(months.map((b) => b.yearMonth), ['2026-08', '2026-10']);
    });

    test('watchByMonth emits the live row', () async {
      final stream = repo.watchByMonth('2026-09');
      await repo.upsert(
        yearMonth: '2026-09',
        incomeCents: 300000,
        savingsTargetCents: 60000,
      );
      final row = await stream.first;
      expect(row, isNotNull);
      expect(row!.incomeCents, 300000);
    });
  });

  group('BudgetRepository tombstone', () {
    test('softDelete hides the row but keeps the raw row', () async {
      final row = await repo.upsert(
        yearMonth: '2026-09',
        incomeCents: 500000,
        savingsTargetCents: 140000,
      );
      expect(await repo.softDelete(row.id), 1);
      expect(await repo.getByMonth('2026-09'), isNull);
      expect(await repo.listMonths(), isEmpty);

      final raw = await db.select(db.budgetMonths).get();
      expect(raw, hasLength(1), reason: 'physical row must remain');
      expect(raw.single.deletedAt, isNotNull);
      expect(raw.single.incomeCents, 500000, reason: 'raw values preserved');
    });

    test('upsert revives a tombstoned month on the same row', () async {
      final row = await repo.upsert(
        yearMonth: '2026-09',
        incomeCents: 500000,
        savingsTargetCents: 140000,
      );
      await repo.softDelete(row.id);

      final revived = await repo.upsert(
        yearMonth: '2026-09',
        incomeCents: 480000,
        savingsTargetCents: 130000,
      );
      expect(revived.id, row.id, reason: 'unique month key must not conflict');
      expect(revived.deletedAt, isNull);
      expect(revived.incomeCents, 480000);
      expect((await repo.listMonths()), hasLength(1));
    });
  });

  group('V2 -> V3 migration', () {
    test('adds budget_months with no backfill and preserves existing data',
        () async {
      final dir = await Directory.systemTemp.createTemp('gringotts_v2v3_');
      addTearDown(() => dir.delete(recursive: true));
      final file = File(p.join(dir.path, 'v2.sqlite'));

      // Build a real current-schema database, insert data, then strip the V3
      // table and downgrade the stamp: this reproduces a genuine V2 file whose
      // DDL was produced by drift itself.
      var db = AppDatabase(NativeDatabase(file));
      final seeded = await db.into(db.transactions).insertReturning(
            TransactionsCompanion.insert(
              amountCents: 1234,
              type: TransactionType.expense,
              occurredAt: DateTime(2026, 9, 1),
            ),
          );
      await db.customStatement('DROP TABLE budget_months');
      await db.customStatement('PRAGMA user_version = 2');
      await db.close();

      // Reopen: drift sees user_version 2 and runs onUpgrade(2, 3).
      db = AppDatabase(NativeDatabase(file));
      final migrated = BudgetRepository(db);

      // No backfill: historical months correctly have no budget.
      expect(await migrated.listMonths(), isEmpty);
      // The new table is fully usable (createTable ran).
      final created = await migrated.upsert(
        yearMonth: '2026-09',
        incomeCents: 500000,
        savingsTargetCents: 140000,
      );
      expect(created.incomeCents, 500000);

      // Existing rows survived the migration untouched.
      final transactions = await db.liveTransactions.get();
      expect(transactions.map((t) => t.id), contains(seeded.id));
      expect(transactions.single.amountCents, 1234);
      expect(await db.liveCategories.get(), hasLength(9));

      await db.close();
    });
  });
}
