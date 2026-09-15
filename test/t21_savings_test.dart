import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gringotts/app/app.dart';
import 'package:gringotts/data/app_database.dart';
import 'package:gringotts/data/repositories/budget_repository.dart';
import 'package:gringotts/data/repositories/repositories.dart';
import 'package:gringotts/domain/models.dart';
import 'package:gringotts/pages/home_page.dart';
import 'package:gringotts/services/budget_engine.dart';
import 'package:gringotts/services/savings_plan.dart';
import 'package:gringotts/ui/tokens.dart';
import 'package:path/path.dart' as p;

BudgetMonth _budget({
  int savingsTargetCents = 50000,
  DateTime? confirmedAt,
  DateTime? skippedAt,
  DateTime? deletedAt,
}) =>
    BudgetMonth(
      id: 'b1',
      yearMonth: '2026-09',
      incomeCents: 300000,
      savingsTargetCents: savingsTargetCents,
      createdAt: DateTime(2026, 9, 1),
      updatedAt: DateTime(2026, 9, 1),
      savingsConfirmedAt: confirmedAt,
      savingsSkippedAt: skippedAt,
      deletedAt: deletedAt,
    );

void main() {
  group('SavingsPlan (pure rules)', () {
    test('prompt only with planned savings > 0 and no decision yet', () {
      expect(SavingsPlan.shouldPrompt(null), isFalse);
      expect(SavingsPlan.shouldPrompt(_budget(savingsTargetCents: 0)), isFalse);
      expect(SavingsPlan.shouldPrompt(_budget()), isTrue);
      expect(
        SavingsPlan.shouldPrompt(
            _budget(confirmedAt: DateTime(2026, 9, 30, 12))),
        isFalse,
      );
      expect(
        SavingsPlan.shouldPrompt(_budget(skippedAt: DateTime(2026, 9, 28))),
        isFalse,
      );
      expect(
        SavingsPlan.shouldPrompt(
            _budget(deletedAt: DateTime(2026, 9, 5))),
        isFalse,
        reason: 'a tombstoned budget row never prompts',
      );
    });

    test('asset date = last day of the month at 12:00', () {
      expect(SavingsPlan.lastDayNoon(DateTime(2026, 9, 1)),
          DateTime(2026, 9, 30, 12));
      expect(SavingsPlan.lastDayNoon(DateTime(2026, 2, 1)),
          DateTime(2026, 2, 28, 12));
      expect(SavingsPlan.lastDayNoon(DateTime(2024, 2, 1)),
          DateTime(2024, 2, 29, 12));
    });

    test('asset name follows the month', () {
      expect(SavingsPlan.assetName(DateTime(2026, 9, 1)), '9 月计划存款');
      expect(SavingsPlan.assetName(DateTime(2026, 12, 1)), '12 月计划存款');
    });

    test('month-end hint covers the last three days only', () {
      final sept = DateTime(2026, 9, 1); // 30 days
      expect(SavingsPlan.isMonthEnd(DateTime(2026, 9, 28), sept), isTrue);
      expect(SavingsPlan.isMonthEnd(DateTime(2026, 9, 29), sept), isTrue);
      expect(SavingsPlan.isMonthEnd(DateTime(2026, 9, 30), sept), isTrue);
      expect(SavingsPlan.isMonthEnd(DateTime(2026, 9, 27), sept), isFalse);
      expect(SavingsPlan.isMonthEnd(DateTime(2026, 10, 1), sept), isFalse,
          reason: 'a different month never shows the hint');
    });

    test('month key parses back to the first day', () {
      expect(SavingsPlan.monthOfKey('2026-09'), DateTime(2026, 9, 1));
      expect(SavingsPlan.monthOfKey('2026-12'), DateTime(2026, 12, 1));
    });
  });

  group('SavingsPlanService (confirmation flow, real database)', () {
    late AppDatabase db;
    late BudgetRepository budgetRepo;
    late AssetRepository assetRepo;
    late SavingsPlanService service;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      budgetRepo = BudgetRepository(db);
      assetRepo = AssetRepository(db);
      service = SavingsPlanService(budgetRepo: budgetRepo, assetRepo: assetRepo);
    });

    tearDown(() async => db.close());

    test('confirm writes exactly one savings asset and the timestamp',
        () async {
      final budget = await budgetRepo.upsert(
        yearMonth: '2026-09',
        incomeCents: 300000,
        savingsTargetCents: 50000,
      );
      expect(await assetRepo.getLiveAssets(), isEmpty,
          reason: 'T-21 acceptance 5: nothing lands before the user acts');

      final asset = await service.confirm(budget);
      expect(asset.name, '9 月计划存款');
      expect(asset.category, AssetCategory.savings);
      expect(asset.valueCents, 50000);
      expect(asset.purchasedAt, DateTime(2026, 9, 30, 12));
      expect(asset.note, SavingsPlan.assetNote);

      final live = await assetRepo.getLiveAssets();
      expect(live, hasLength(1), reason: 'exactly one asset, never two');
      final after = await budgetRepo.getByMonth('2026-09');
      expect(after!.savingsConfirmedAt, isNotNull);
      expect(after.savingsSkippedAt, isNull);
      expect(SavingsPlan.shouldPrompt(after), isFalse,
          reason: 'the card must stop prompting once confirmed');
    });

    test('重复确认 returns the existing asset and creates no second row',
        () async {
      final budget = await budgetRepo.upsert(
        yearMonth: '2026-09',
        incomeCents: 300000,
        savingsTargetCents: 50000,
      );
      final first = await service.confirm(budget);
      final confirmed = await budgetRepo.getByMonth('2026-09');
      final second = await service.confirm(confirmed!);
      expect(second.id, first.id);
      final live = await assetRepo.getLiveAssets();
      expect(live, hasLength(1));
      expect(live.single.valueCents, 50000);
    });

    test('skip writes only the timestamp: zero assets', () async {
      final budget = await budgetRepo.upsert(
        yearMonth: '2026-09',
        incomeCents: 300000,
        savingsTargetCents: 50000,
      );
      await service.skip(budget);
      final after = await budgetRepo.getByMonth('2026-09');
      expect(after!.savingsSkippedAt, isNotNull);
      expect(after.savingsConfirmedAt, isNull);
      expect(await assetRepo.getLiveAssets(), isEmpty,
          reason: '这个月没攒够 must not fabricate an asset');
      expect(SavingsPlan.shouldPrompt(after), isFalse);
    });
  });

  group('V3 -> V4 migration', () {
    test('addColumn keeps V3 rows readable and adds the new columns', () async {
      final dir = Directory.systemTemp.createTempSync('gringotts_t21_v4');
      final file = File(p.join(dir.path, 'v3.sqlite'));
      addTearDown(() {
        if (dir.existsSync()) dir.deleteSync(recursive: true);
      });

      // Build a real V3 database: create the current schema, then drop every
      // V4 column again and set user_version back to 3.
      final v3 = AppDatabase(NativeDatabase(file));
      await v3.customStatement('SELECT 1');
      await v3.customStatement(
          'ALTER TABLE budget_months DROP COLUMN savings_confirmed_at');
      await v3.customStatement(
          'ALTER TABLE budget_months DROP COLUMN savings_skipped_at');
      await v3.customStatement('ALTER TABLE assets DROP COLUMN note');
      await v3.customStatement(
          "INSERT INTO budget_months (id, year_month, income_cents, "
          "savings_target_cents, created_at, updated_at) "
          "VALUES ('b1', '2026-08', 300000, 50000, 0, 0)");
      await v3.customStatement('PRAGMA user_version = 3');
      await v3.close();

      // Reopen with T-21 code: onUpgrade(3 -> 4) must add the three columns.
      final migrated = AppDatabase(NativeDatabase(file));
      final rows = await migrated.select(migrated.budgetMonths).get();
      expect(rows, hasLength(1), reason: 'old data survives the migration');
      expect(rows.first.yearMonth, '2026-08');
      expect(rows.first.incomeCents, 300000);
      expect(rows.first.savingsTargetCents, 50000);
      expect(rows.first.savingsConfirmedAt, isNull);
      expect(rows.first.savingsSkippedAt, isNull);
      expect(await migrated.select(migrated.assets).get(), isEmpty);

      // The new columns are writable after the migration.
      await BudgetRepository(migrated).markSavingsSkipped('b1');
      final after = await migrated.select(migrated.budgetMonths).getSingle();
      expect(after.savingsSkippedAt, isNotNull);
      await migrated.close();
    });
  });

  group('home savings card (widget + real database)', () {
    testWidgets('card shows, confirm creates one asset and clears the card',
        (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(() async => db.close());
      final month = DateTime.now();
      await BudgetRepository(db).upsert(
        yearMonth: BudgetEngine.monthKey(month),
        incomeCents: 300000,
        savingsTargetCents: 50000,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [databaseProvider.overrideWithValue(db)],
          child: MaterialApp(
            theme: buildAppTheme(),
            home: const HomePage(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('home_savings_card')), findsOneWidget);
      expect(find.text('存进资产'), findsOneWidget);
      expect(find.text('这个月没攒够'), findsOneWidget);

      await tester.tap(find.byKey(const Key('savings_confirm')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('home_savings_card')), findsNothing,
          reason: 'the refreshed budget row stops prompting');
      final live = await AssetRepository(db).getLiveAssets();
      expect(live, hasLength(1));
      expect(live.single.category, AssetCategory.savings);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    });

    testWidgets('skip clears the card without writing an asset',
        (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(() async => db.close());
      await BudgetRepository(db).upsert(
        yearMonth: BudgetEngine.monthKey(DateTime.now()),
        incomeCents: 300000,
        savingsTargetCents: 50000,
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [databaseProvider.overrideWithValue(db)],
          child: MaterialApp(
            theme: buildAppTheme(),
            home: const HomePage(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('savings_skip')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('home_savings_card')), findsNothing);
      expect(await AssetRepository(db).getLiveAssets(), isEmpty);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    });
  });
}