import 'package:flutter_test/flutter_test.dart';
import 'package:gringotts/data/app_database.dart';
import 'package:gringotts/domain/models.dart';
import 'package:gringotts/services/statistics_service.dart';

Transaction _tx({
  required int amountCents,
  required TransactionType type,
  required DateTime occurredAt,
  bool isDraft = false,
  String? categoryId,
  DateTime? deletedAt,
}) =>
    Transaction(
      id: 'tx-$amountCents-${type.name}-${occurredAt.millisecondsSinceEpoch}',
      amountCents: amountCents,
      type: type,
      categoryId: categoryId,
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
  required int incomeCents,
  required int savingsTargetCents,
  String yearMonth = '2026-09',
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
  final day = DateTime(2026, 9, 9);

  group('StatisticsService: aggregation scope (drafts never counted)', () {
    test('confirmed expense counts; identical draft amount does not', () {
      final transactions = [
        _tx(amountCents: 2800, type: TransactionType.expense, occurredAt: day),
        _tx(
          amountCents: 2800,
          type: TransactionType.expense,
          occurredAt: day,
          isDraft: true,
        ),
      ];
      final totals = StatisticsService.totals(transactions);
      expect(totals.expenseCents, 2800, reason: 'draft must be excluded');
      expect(totals.incomeCents, 0);
      expect(totals.netCents, -2800);
    });

    test('tombstoned rows are excluded', () {
      final transactions = [
        _tx(
          amountCents: 5000,
          type: TransactionType.expense,
          occurredAt: day,
          deletedAt: day,
        ),
      ];
      expect(StatisticsService.totals(transactions).expenseCents, 0);
    });

    test('transfer placeholder never enters expense/income/net', () {
      final transactions = [
        _tx(amountCents: 9900, type: TransactionType.transfer, occurredAt: day),
      ];
      final t = StatisticsService.totals(transactions);
      expect(t.expenseCents, 0);
      expect(t.incomeCents, 0);
      expect(t.netCents, 0);
    });

    test('category totals: drafts skipped, null category kept as 未分类', () {
      final transactions = [
        _tx(
          amountCents: 1500,
          type: TransactionType.expense,
          occurredAt: day,
          categoryId: 'dining',
        ),
        _tx(
          amountCents: 1500,
          type: TransactionType.expense,
          occurredAt: day,
          categoryId: 'dining',
          isDraft: true,
        ),
        _tx(
          amountCents: 3000,
          type: TransactionType.expense,
          occurredAt: day,
        ),
      ];
      final result = StatisticsService.expenseByCategory(transactions);
      expect(result.length, 2);
      // Sorted by amount desc: null first (3000), then dining (1500).
      expect(result.first.categoryId, isNull);
      expect(result.first.cents, 3000);
      expect(result.last.categoryId, 'dining');
      expect(result.last.cents, 1500);
    });
  });

  group('StatisticsService: day view = every day of the selected month', () {
    // T-21 acceptance 1: the bar count equals the month length (28/29/30/31)
    // and each label x is the integer data-point index.
    for (final c in <({int year, int month, int days})>[
      (year: 2026, month: 2, days: 28),
      (year: 2024, month: 2, days: 29),
      (year: 2026, month: 4, days: 30),
      (year: 2026, month: 10, days: 31),
    ]) {
      test('${c.year}-${c.month} has ${c.days} buckets, labels aligned', () {
        final month = DateTime(c.year, c.month, 1);
        final points = StatisticsService.monthDays(
          const <Transaction>[],
          month: month,
        );
        expect(points.length, c.days);
        expect(StatisticsService.monthDayLabels(month).length, c.days);
        for (var i = 0; i < points.length; i++) {
          expect(points[i].label, '${c.month}/${i + 1}',
              reason: 'index $i must carry day ${i + 1}');
        }
        // The chart-1 x value is the data-point index, never length / 6.
        final bars = StatisticsService.spendBars(points);
        expect(bars.length, c.days);
        for (var i = 0; i < bars.length; i++) {
          expect(bars[i].index, i);
          expect(bars[i].label, points[i].label);
        }
      });
    }

    test('day buckets aggregate that day only, other months excluded', () {
      final transactions = [
        _tx(
          amountCents: 1500,
          type: TransactionType.expense,
          occurredAt: DateTime(2026, 9, 9, 12),
        ),
        _tx(
          amountCents: 2000,
          type: TransactionType.income,
          occurredAt: DateTime(2026, 9, 9, 18),
        ),
        _tx(
          amountCents: 9999,
          type: TransactionType.expense,
          occurredAt: DateTime(2026, 8, 9, 12),
        ),
        _tx(
          amountCents: 8888,
          type: TransactionType.expense,
          occurredAt: DateTime(2025, 9, 9, 12),
        ),
        _tx(
          amountCents: 1000,
          type: TransactionType.income,
          occurredAt: DateTime(2026, 9, 9, 20),
          isDraft: true,
        ),
      ];
      final points = StatisticsService.monthDays(
        transactions,
        month: DateTime(2026, 9, 1),
      );
      expect(points.length, 30);
      final ninth = points[8];
      expect(ninth.label, '9/9');
      expect(ninth.expenseCents, 1500);
      expect(ninth.incomeCents, 2000, reason: 'draft income excluded');
      expect(ninth.netCents, 500);
      // Every other day is empty.
      expect(points.where((p) => p.expenseCents > 0).length, 1);
    });
  });

  group('StatisticsService: income baseline (保底收入均摊, derived only)', () {
    test('budget income is amortised over the month length', () {
      final budget = _budget(incomeCents: 300000, savingsTargetCents: 60000);
      expect(
        StatisticsService.incomeBaselinePerDay(
          budget: budget,
          month: DateTime(2026, 9, 1),
        ),
        10000,
      );
      // 2026-02 (28 days) -> 300000 / 28 = 10714.28.. floored.
      expect(
        StatisticsService.incomeBaselinePerDay(
          budget: _budget(
              incomeCents: 300000,
              savingsTargetCents: 0,
              yearMonth: '2026-02'),
          month: DateTime(2026, 2, 1),
        ),
        10714,
      );
    });

    test('no budget row and a tombstoned row both mean null', () {
      expect(
        StatisticsService.incomeBaselinePerDay(
          budget: null,
          month: DateTime(2026, 9, 1),
        ),
        isNull,
      );
      expect(
        StatisticsService.incomeBaselinePerDay(
          budget: _budget(
            incomeCents: 300000,
            savingsTargetCents: 0,
            deletedAt: DateTime(2026, 9, 2),
          ),
          month: DateTime(2026, 9, 1),
        ),
        isNull,
      );
    });

    test('monthDays stamps the amortised baseline on every bucket', () {
      final points = StatisticsService.monthDays(
        const <Transaction>[],
        month: DateTime(2026, 9, 1),
        baselineIncomePerDayCents: 10000,
      );
      expect(points.length, 30);
      expect(points.every((p) => p.baselineIncomeCents == 10000), isTrue);
      expect(points.every((p) => p.incomeLineCents == 10000), isTrue);
      // Without a budget there is no baseline and the line is 0.
      final bare = StatisticsService.monthDays(
        const <Transaction>[],
        month: DateTime(2026, 9, 1),
      );
      expect(bare.every((p) => p.baselineIncomeCents == 0), isTrue);
    });

    test('temp income adds on top of the baseline for the income line', () {
      final points = StatisticsService.monthDays(
        [
          _tx(
            amountCents: 80000,
            type: TransactionType.income,
            occurredAt: DateTime(2026, 9, 12, 10),
          ),
        ],
        month: DateTime(2026, 9, 1),
        baselineIncomePerDayCents: 10000,
      );
      final twelfth = points[11];
      expect(twelfth.label, '9/12');
      expect(twelfth.incomeCents, 80000, reason: 'temporary income flow');
      expect(twelfth.baselineIncomeCents, 10000);
      expect(twelfth.incomeLineCents, 90000,
          reason: 'chart 2 income = 保底均摊 + 临时收入');
    });
  });

  group('StatisticsService: month / year buckets', () {
    test('monthly trend: 12 buckets, other years excluded', () {
      final transactions = [
        _tx(
          amountCents: 3000,
          type: TransactionType.expense,
          occurredAt: DateTime(2026, 8, 5),
        ),
        _tx(
          amountCents: 8000,
          type: TransactionType.income,
          occurredAt: DateTime(2026, 8, 20),
        ),
        _tx(
          amountCents: 1200,
          type: TransactionType.expense,
          occurredAt: DateTime(2026, 9, 1),
        ),
        _tx(
          amountCents: 500,
          type: TransactionType.income,
          occurredAt: DateTime(2026, 9, 2),
        ),
        // Same month name, different year: must not merge into 8月.
        _tx(
          amountCents: 7777,
          type: TransactionType.expense,
          occurredAt: DateTime(2025, 8, 5),
        ),
      ];
      final trend = StatisticsService.monthlyTrend(
        transactions,
        year: 2026,
        baselineIncomeByMonth: const <int, int>{8: 500000, 9: 450000},
      );
      expect(trend.length, 12);
      expect(trend[7].label, '8月');
      expect(trend[7].expenseCents, 3000);
      expect(trend[7].incomeCents, 8000);
      expect(trend[7].baselineIncomeCents, 500000);
      expect(trend[7].incomeLineCents, 508000);
      expect(trend[8].label, '9月');
      expect(trend[8].expenseCents, 1200);
      expect(trend[8].baselineIncomeCents, 450000);
      expect(trend[8].netCents, -700);
      // 2025 rows are excluded from a 2026 view.
      expect(trend[7].expenseCents, isNot(3000 + 7777));
      // Months without a budget keep a 0 baseline.
      expect(trend[0].baselineIncomeCents, 0);
    });

    test('yearly trend across two years carries the year baselines', () {
      final transactions = [
        _tx(
          amountCents: 10000,
          type: TransactionType.income,
          occurredAt: DateTime(2025, 5, 1),
        ),
        _tx(
          amountCents: 4000,
          type: TransactionType.expense,
          occurredAt: DateTime(2026, 3, 3),
        ),
      ];
      final trend = StatisticsService.yearlyTrend(
        transactions,
        baselineIncomeByYear: const <int, int>{2025: 120000, 2026: 130000},
      );
      expect(trend.length, 2);
      expect(trend[0].label, '2025年');
      expect(trend[0].incomeCents, 10000);
      expect(trend[0].baselineIncomeCents, 120000);
      expect(trend[1].label, '2026年');
      expect(trend[1].expenseCents, 4000);
      expect(trend[1].baselineIncomeCents, 130000);
      expect(trend[1].netCents, -4000);
    });
  });

  group('StatisticsService: chart-1 bars (allowance split)', () {
    test('over-limit tail is split out; inside stays one segment', () {
      final points = StatisticsService.monthDays(
        [
          _tx(
            amountCents: 15000,
            type: TransactionType.expense,
            occurredAt: DateTime(2026, 9, 1),
          ),
          _tx(
            amountCents: 8000,
            type: TransactionType.expense,
            occurredAt: DateTime(2026, 9, 2),
          ),
          _tx(
            amountCents: 80000,
            type: TransactionType.income,
            occurredAt: DateTime(2026, 9, 2),
          ),
        ],
        month: DateTime(2026, 9, 1),
        baselineIncomePerDayCents: 10000,
      );
      final bars = StatisticsService.spendBars(
        points,
        allowanceByIndex: List<int?>.filled(points.length, 10000),
      );
      final first = bars[0];
      expect(first.overLimit, isTrue);
      expect(first.baseCents, 10000);
      expect(first.overCents, 5000);
      expect(first.hasTempIncome, isFalse);
      final second = bars[1];
      expect(second.overLimit, isFalse);
      expect(second.baseCents, 8000);
      expect(second.overCents, 0);
      expect(second.tempIncomeCents, 80000);
      expect(second.hasTempIncome, isTrue);
    });

    test('no budget: null allowance means no baseline and no red segment', () {
      final points = StatisticsService.monthDays(
        [
          _tx(
            amountCents: 15000,
            type: TransactionType.expense,
            occurredAt: DateTime(2026, 9, 1),
          ),
        ],
        month: DateTime(2026, 9, 1),
      );
      final bars = StatisticsService.spendBars(points);
      expect(bars[0].allowanceCents, isNull);
      expect(bars[0].overLimit, isFalse);
      expect(bars[0].overCents, 0);
      expect(bars[0].baseCents, 15000);
    });
  });

  group('StatisticsService: net balance', () {
    test('income minus expense, draft income excluded', () {
      final transactions = [
        _tx(
          amountCents: 10000,
          type: TransactionType.income,
          occurredAt: day,
        ),
        _tx(
          amountCents: 3000,
          type: TransactionType.expense,
          occurredAt: day,
        ),
        _tx(
          amountCents: 500,
          type: TransactionType.income,
          occurredAt: day,
          isDraft: true,
        ),
      ];
      final totals = StatisticsService.totals(transactions);
      expect(totals.netCents, 7000,
          reason: 'draft income 500 must not inflate balance');
    });
  });
}