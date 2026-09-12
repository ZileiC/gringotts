import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gringotts/data/app_database.dart';
import 'package:gringotts/domain/models.dart';

/// T-12c Part B: the draft pipeline is abolished - the speed-entry confirm key
/// writes a formal record (`is_draft = false`) that counts immediately. The
/// `is_draft` column and its exclusion from the statistics scope are kept for
/// legacy rows, which is what this file now pins down.
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

  /// Confirmed expense sum for the local day containing [now].
  Future<int> confirmedExpenseTotal(DateTime now) async {
    final start = DateTime(now.year, now.month, now.day);
    final end = start.add(const Duration(days: 1));
    final sumExpr = db.transactions.amountCents.sum();
    final query = db.selectOnly(db.transactions)
      ..addColumns([sumExpr])
      ..where(db.transactions.deletedAt.isNull() &
          db.transactions.isDraft.equals(false) &
          db.transactions.type.equalsValue(TransactionType.expense) &
          db.transactions.occurredAt.isBiggerOrEqualValue(start) &
          db.transactions.occurredAt.isSmallerThanValue(end));
    final row = await query.getSingle();
    return row.read(sumExpr) ?? 0;
  }

  group('T-03 / T-12c: statistics scope counts formal records only', () {
    test('a formal record counts in the day expense total immediately',
        () async {
      await createSchema();
      final now = DateTime.now();

      // What the speed-entry confirm key does now: is_draft = false.
      await db.into(db.transactions).insert(
            TransactionsCompanion.insert(
              amountCents: 1500,
              type: TransactionType.expense,
              source: const Value(TransactionSource.manual),
              occurredAt: now,
            ),
          );

      expect(await confirmedExpenseTotal(now), 1500,
          reason: 'no confirmation step sits between recording and reporting');
    });

    test('a legacy draft row is still excluded from the confirmed total',
        () async {
      await createSchema();
      final now = DateTime.now();

      await db.into(db.transactions).insert(
            TransactionsCompanion.insert(
              amountCents: 1500,
              type: TransactionType.expense,
              source: const Value(TransactionSource.manual),
              isDraft: const Value(true),
              occurredAt: now,
            ),
          );

      expect(await confirmedExpenseTotal(now), 0,
          reason: 'the is_draft exclusion is retained for legacy rows');

      // Promoting a legacy row (raw update) makes it count.
      final updated = await (db.update(db.transactions)
            ..where((t) => t.isDraft.equals(true)))
          .write(TransactionsCompanion(isDraft: const Value(false)));
      expect(updated, 1);
      expect(await confirmedExpenseTotal(now), 1500);
    });
  });
}
