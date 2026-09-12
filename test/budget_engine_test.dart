import 'package:flutter_test/flutter_test.dart';
import 'package:gringotts/data/app_database.dart';
import 'package:gringotts/domain/models.dart';
import 'package:gringotts/services/budget_engine.dart';

Transaction _tx({
  required int amountCents,
  required TransactionType type,
  required DateTime occurredAt,
  bool isDraft = false,
  DateTime? deletedAt,
}) =>
    Transaction(
      id: 'tx-$amountCents-${type.name}-${occurredAt.microsecondsSinceEpoch}',
      amountCents: amountCents,
      type: type,
      categoryId: null,
      merchant: null,
      note: null,
      occurredAt: occurredAt,
      isDraft: isDraft,
      source: TransactionSource.manual,
      createdAt: occurredAt,
      updatedAt: occurredAt,
      deletedAt: deletedAt,
    );

BudgetMonth _budget({
  String yearMonth = '2026-09',
  required int incomeCents,
  required int savingsTargetCents,
  DateTime? deletedAt,
}) =>
    BudgetMonth(
      id: 'budget-$yearMonth',
      yearMonth: yearMonth,
      incomeCents: incomeCents,
      savingsTargetCents: savingsTargetCents,
      createdAt: DateTime(2026, 9, 1),
      updatedAt: DateTime(2026, 9, 1),
      deletedAt: deletedAt,
    );

void main() {
  group('BudgetEngine.daysInMonth (leap-year rule)', () {
    test('February: 2024 leap, 2023 common, 2000 leap, 1900 century common',
        () {
      expect(BudgetEngine.daysInMonth(2024, 2), 29);
      expect(BudgetEngine.daysInMonth(2023, 2), 28);
      expect(BudgetEngine.daysInMonth(2000, 2), 29, reason: 'divisible by 400');
      expect(BudgetEngine.daysInMonth(1900, 2), 28,
          reason: 'divisible by 100 but not 400');
      expect(BudgetEngine.isLeapYear(2024), isTrue);
      expect(BudgetEngine.isLeapYear(2100), isFalse);
    });

    test('30-day and 31-day months', () {
      for (final m in [4, 6, 9, 11]) {
        expect(BudgetEngine.daysInMonth(2026, m), 30, reason: 'month $m');
      }
      for (final m in [1, 3, 5, 7, 8, 10, 12]) {
        expect(BudgetEngine.daysInMonth(2026, m), 31, reason: 'month $m');
      }
    });
  });

  group('BudgetEngine.remainingDays (inclusive of today)', () {
    test('first / middle / last day of a 30-day month', () {
      expect(
          BudgetEngine.remainingDays(year: 2026, month: 9, day: 1), 30);
      expect(
          BudgetEngine.remainingDays(year: 2026, month: 9, day: 15), 16);
      expect(
          BudgetEngine.remainingDays(year: 2026, month: 9, day: 30), 1,
          reason: 'last day still has today');
    });

    test('leap February last day has exactly today left', () {
      expect(
          BudgetEngine.remainingDays(year: 2024, month: 2, day: 29), 1);
      expect(
          BudgetEngine.remainingDays(year: 2024, month: 2, day: 1), 29);
    });
  });

  group('BudgetEngine budget / quota formulas (floored)', () {
    test('budgetCents = income - savings (may be non-positive)', () {
      expect(
          BudgetEngine.budgetCents(incomeCents: 500000, savingsTargetCents: 140000),
          360000);
      expect(
          BudgetEngine.budgetCents(incomeCents: 100000, savingsTargetCents: 100000),
          0);
      expect(
          BudgetEngine.budgetCents(incomeCents: 50000, savingsTargetCents: 80000),
          -30000);
    });

    test('fixedDailyCents floors (never rounds up)', () {
      // 1000000 / 30 = 33333.33 -> 33333
      expect(
          BudgetEngine.fixedDailyCents(budgetCents: 1000000, daysInMonth: 30),
          33333);
      // 100 / 31 = 3.22 -> 3
      expect(BudgetEngine.fixedDailyCents(budgetCents: 100, daysInMonth: 31), 3);
      // exact division stays put
      expect(BudgetEngine.fixedDailyCents(budgetCents: 900, daysInMonth: 30), 30);
    });

    test('fixedDailyCents floors toward negative infinity for a deficit', () {
      // -100 / 3 = -33.33 -> floor = -34 (Dart ~/ alone would give -33)
      expect(BudgetEngine.fixedDailyCents(budgetCents: -100, daysInMonth: 3), -34);
    });

    test('liveDailyCents floors and clamps negatives to 0', () {
      // 100000 / 3 = 33333.33 -> 33333
      expect(
          BudgetEngine.liveDailyCents(remainingCents: 100000, remainingDays: 3),
          33333);
      expect(
          BudgetEngine.liveDailyCents(remainingCents: 100, remainingDays: 3), 33);
      expect(
          BudgetEngine.liveDailyCents(remainingCents: -1, remainingDays: 3), 0,
          reason: 'any overspend shows 0, never a negative daily quota');
      expect(
          BudgetEngine.liveDailyCents(remainingCents: -999999, remainingDays: 1),
          0);
      expect(BudgetEngine.liveDailyCents(remainingCents: 0, remainingDays: 5), 0);
    });
  });

  group('BudgetEngine spending scope (T-05 exclusion rule)', () {
    final day = DateTime(2026, 9, 10);

    test('only confirmed expenses count; drafts / income / transfer do not', () {
      final transactions = [
        _tx(amountCents: 2800, type: TransactionType.expense, occurredAt: day),
        _tx(
            amountCents: 2800,
            type: TransactionType.expense,
            occurredAt: day,
            isDraft: true),
        _tx(amountCents: 9999, type: TransactionType.income, occurredAt: day),
        _tx(amountCents: 7777, type: TransactionType.transfer, occurredAt: day),
        _tx(
            amountCents: 5000,
            type: TransactionType.expense,
            occurredAt: day,
            deletedAt: day),
      ];
      expect(
          BudgetEngine.spentCentsInMonth(transactions, year: 2026, month: 9),
          2800);
    });

    test('only the requested month counts (cross-month reset)', () {
      final transactions = [
        _tx(amountCents: 1000, type: TransactionType.expense, occurredAt: day),
        _tx(
            amountCents: 4000,
            type: TransactionType.expense,
            occurredAt: DateTime(2026, 8, 31)),
        _tx(
            amountCents: 9000,
            type: TransactionType.expense,
            occurredAt: DateTime(2026, 10, 1)),
      ];
      expect(
          BudgetEngine.spentCentsInMonth(transactions, year: 2026, month: 9),
          1000);
      expect(
          BudgetEngine.spentCentsInMonth(transactions, year: 2026, month: 8),
          4000);
      expect(
          BudgetEngine.spentCentsInMonth(transactions, year: 2026, month: 10),
          9000);
    });

    test('todaySpending isolates the local day and counts rows', () {
      final transactions = [
        _tx(amountCents: 1500, type: TransactionType.expense, occurredAt: day),
        _tx(
            amountCents: 2500,
            type: TransactionType.expense,
            occurredAt: DateTime(2026, 9, 10, 23, 59)),
        _tx(
            amountCents: 800,
            type: TransactionType.expense,
            occurredAt: DateTime(2026, 9, 9, 23, 59)),
        _tx(
            amountCents: 100,
            type: TransactionType.expense,
            occurredAt: day,
            isDraft: true),
      ];
      final today = BudgetEngine.todaySpending(transactions, day: day);
      expect(today.cents, 4000);
      expect(today.count, 2, reason: 'draft and yesterday are excluded');
    });
  });

  group('BudgetEngine.compute (snapshot)', () {
    final now = DateTime(2026, 9, 15); // 30-day month, 16 days left

    test('no budget row -> quota fields null, spending still reported', () {
      final transactions = [
        _tx(
            amountCents: 3200,
            type: TransactionType.expense,
            occurredAt: DateTime(2026, 9, 15)),
      ];
      final snapshot = BudgetEngine.compute(
        budget: null,
        transactions: transactions,
        now: now,
      );
      expect(snapshot.hasBudget, isFalse);
      expect(snapshot.budgetCents, isNull);
      expect(snapshot.fixedDailyCents, isNull);
      expect(snapshot.remainingCents, isNull);
      expect(snapshot.liveDailyCents, isNull);
      // No fake numbers, but real spending is still surfaced.
      expect(snapshot.spentCents, 3200);
      expect(snapshot.todaySpentCents, 3200);
      expect(snapshot.todayCount, 1);
      expect(snapshot.daysInMonth, 30);
      expect(snapshot.remainingDays, 16);
      expect(snapshot.spentRatio, 0);
    });

    test('tombstoned budget is treated as no budget', () {
      final snapshot = BudgetEngine.compute(
        budget: _budget(
          incomeCents: 500000,
          savingsTargetCents: 140000,
          deletedAt: DateTime(2026, 9, 2),
        ),
        transactions: const [],
        now: now,
      );
      expect(snapshot.hasBudget, isFalse);
      expect(snapshot.liveDailyCents, isNull);
    });

    test('full math: baseline vs live quota, today line, ratio', () {
      final transactions = [
        _tx(
            amountCents: 30000,
            type: TransactionType.expense,
            occurredAt: DateTime(2026, 9, 15)),
        _tx(
            amountCents: 2000,
            type: TransactionType.expense,
            occurredAt: DateTime(2026, 9, 2)),
      ];
      final snapshot = BudgetEngine.compute(
        budget: _budget(incomeCents: 500000, savingsTargetCents: 140000),
        transactions: transactions,
        now: now,
      );
      // budget 360000 over 30 days -> 12000/day baseline.
      expect(snapshot.budgetCents, 360000);
      expect(snapshot.fixedDailyCents, 12000);
      expect(snapshot.spentCents, 32000);
      expect(snapshot.remainingCents, 328000);
      // 328000 / 16 = 20500 exact.
      expect(snapshot.liveDailyCents, 20500);
      expect(snapshot.todaySpentCents, 30000);
      expect(snapshot.todayCount, 1);
      expect(snapshot.remainingDays, 16);
      expect(snapshot.isOverspent, isFalse);
      expect(snapshot.spentRatio, closeTo(32000 / 360000, 1e-9));
    });

    test('overspend: remaining negative, live clamped 0, ratio full', () {
      final transactions = [
        _tx(
            amountCents: 400000,
            type: TransactionType.expense,
            occurredAt: DateTime(2026, 9, 3)),
      ];
      final snapshot = BudgetEngine.compute(
        budget: _budget(incomeCents: 500000, savingsTargetCents: 140000),
        transactions: transactions,
        now: now,
      );
      expect(snapshot.remainingCents, -40000);
      expect(snapshot.isOverspent, isTrue);
      expect(snapshot.liveDailyCents, 0, reason: 'negative live quota clamps');
      expect(snapshot.fixedDailyCents, 12000,
          reason: 'baseline quota is untouched by spending');
      expect(snapshot.spentRatio, 1.0);
    });

    test('budget <= 0 defensive: no crash, live clamps to 0', () {
      final zeroBudget = BudgetEngine.compute(
        budget: _budget(incomeCents: 0, savingsTargetCents: 0),
        transactions: [
          _tx(
              amountCents: 500,
              type: TransactionType.expense,
              occurredAt: DateTime(2026, 9, 4)),
        ],
        now: now,
      );
      expect(zeroBudget.budgetCents, 0);
      expect(zeroBudget.fixedDailyCents, 0);
      expect(zeroBudget.remainingCents, -500);
      expect(zeroBudget.liveDailyCents, 0);
      expect(zeroBudget.spentRatio, 1.0);

      final deficit = BudgetEngine.compute(
        budget: _budget(incomeCents: 100000, savingsTargetCents: 150000),
        transactions: const [],
        now: now,
      );
      expect(deficit.budgetCents, -50000);
      // -50000 / 30 -> floor -1667.
      expect(deficit.fixedDailyCents, -1667);
      expect(deficit.liveDailyCents, 0);
      expect(deficit.spentRatio, 0);
    });

    test('editing the budget re-derives every figure immediately', () {
      final transactions = [
        _tx(
            amountCents: 10000,
            type: TransactionType.expense,
            occurredAt: DateTime(2026, 9, 5)),
      ];
      final before = BudgetEngine.compute(
        budget: _budget(incomeCents: 300000, savingsTargetCents: 60000),
        transactions: transactions,
        now: now,
      );
      final after = BudgetEngine.compute(
        budget: _budget(incomeCents: 400000, savingsTargetCents: 60000),
        transactions: transactions,
        now: now,
      );
      expect(before.budgetCents, 240000);
      expect(after.budgetCents, 340000);
      expect(before.remainingCents, 230000);
      expect(after.remainingCents, 330000);
      // 240000/30 = 8000 vs 340000/30 = 11333
      expect(before.fixedDailyCents, 8000);
      expect(after.fixedDailyCents, 11333);
      // 230000/16 = 14375 vs 330000/16 = 20625
      expect(before.liveDailyCents, 14375);
      expect(after.liveDailyCents, 20625);
    });

    test('cross-month reset: this month starts clean on the 1st', () {
      final transactions = [
        _tx(
            amountCents: 99999,
            type: TransactionType.expense,
            occurredAt: DateTime(2026, 9, 30)),
      ];
      // October: no September carry-over, full days ahead.
      final october = BudgetEngine.compute(
        budget: _budget(
          yearMonth: '2026-10',
          incomeCents: 500000,
          savingsTargetCents: 140000,
        ),
        transactions: transactions,
        now: DateTime(2026, 10, 1),
      );
      expect(october.spentCents, 0);
      expect(october.budgetCents, 360000);
      expect(october.remainingCents, 360000);
      expect(october.remainingDays, 31);
      expect(october.daysInMonth, 31);
      // 360000 / 31 = 11612.9 -> 11612
      expect(october.liveDailyCents, 11612);
    });

    test('last day of month: remainingDays == 1, live == remaining', () {
      final snapshot = BudgetEngine.compute(
        budget: _budget(incomeCents: 500000, savingsTargetCents: 140000),
        transactions: [
          _tx(
              amountCents: 50000,
              type: TransactionType.expense,
              occurredAt: DateTime(2026, 9, 30)),
        ],
        now: DateTime(2026, 9, 30),
      );
      expect(snapshot.remainingDays, 1);
      expect(snapshot.liveDailyCents, snapshot.remainingCents);
      expect(snapshot.remainingCents, 310000);
    });
  });

  group('BudgetEngine.monthKey', () {
    test('zero-pads to YYYY-MM', () {
      expect(BudgetEngine.monthKey(DateTime(2026, 9, 12)), '2026-09');
      expect(BudgetEngine.monthKey(DateTime(2026, 12, 1)), '2026-12');
      expect(BudgetEngine.monthKey(DateTime(987, 1, 1)), '0987-01');
    });
  });
}
