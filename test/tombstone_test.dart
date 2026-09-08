import 'package:drift/drift.dart' show Value;
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

  group('tombstone pattern (soft delete, no physical delete)', () {
    test('insert -> tombstone -> query excludes tombstoned row', () async {
      await createSchema();

      final now = DateTime.now().toUtc();

      // Step 1: insert a transaction.
      await db.into(db.transactions).insert(
            TransactionsCompanion.insert(
              amountCents: 2850,
              type: TransactionType.expense,
              source: const Value(TransactionSource.manual),
              occurredAt: now,
            ),
          );

      // Verify it appears in the live query.
      var live = await db.liveTransactions.get();
      expect(live.length, 1);
      expect(live.first.amountCents, 2850);

      // Step 2: tombstone it (soft delete).
      final updated = await (db.update(db.transactions)
            ..where((t) => t.id.equals(live.first.id)))
          .write(TransactionsCompanion(
        deletedAt: Value(DateTime.now().toUtc()),
      ));
      expect(updated, 1);

      // Step 3: the live query must exclude the tombstoned row.
      live = await db.liveTransactions.get();
      expect(live, isEmpty, reason: 'tombstoned rows must not appear');

      // The raw row still exists (never physically deleted).
      final all = await db.select(db.transactions).get();
      expect(all.length, 1, reason: 'physical row must remain');
      expect(all.first.deletedAt, isNotNull);
    });

    test('categories seed: nine built-ins inserted with fixed order',
        () async {
      await createSchema();
      final seeds = await db.liveCategories.get();
      expect(seeds.length, 9);
      expect(seeds.every((c) => !c.isCustom), isTrue);
      // Canonical order per ticket: dining, transport, shopping, housing,
      // entertainment, study, medical, gift, other.
      expect(seeds.map((c) => c.name).toList(),
          ['餐饮', '交通', '购物', '居住', '娱乐', '学习', '医疗', '人情', '其他']);
    });

    test('asset insert with integer cents value', () async {
      await createSchema();
      final now = DateTime.now().toUtc();
      await db.into(db.assets).insert(
            AssetsCompanion.insert(
              name: 'iPhone',
              category: AssetCategory.digital,
              status: const Value(AssetStatus.inService),
              valueCents: 879900,
              purchasedAt: now,
            ),
          );
      final rows = await db.liveAssets.get();
      expect(rows.length, 1);
      expect(rows.first.valueCents, 879900);
    });
  });
}
