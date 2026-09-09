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

  group('StatisticsService: income/expense dual lines + net (independent)',
      () {
    test('daily trend: expense and income aggregate into separate lines',
        () {
      final transactions = [
        _tx(
          amountCents: 1500,
          type: TransactionType.expense,
          occurredAt: day,
        ),
        _tx(
          amountCents: 2000,
          type: TransactionType.income,
          occurredAt: day,
        ),
        _tx(
          amountCents: 1000,
          type: TransactionType.income,
          occurredAt: day,
          isDraft: true,
        ),
      ];
      final trend = StatisticsService.dailyTrend(
        transactions,
        now: day,
      );
      // 7 buckets; today (index 6) carries the confirmed rows.
      expect(trend.length, 7);
      final today = trend.last;
      expect(today.expenseCents, 1500);
      expect(today.incomeCents, 2000);
      expect(today.netCents, 500);
    });

    test('monthly trend: two months with expense+income each', () {
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
      ];
      final trend = StatisticsService.monthlyTrend(
        transactions,
        now: DateTime(2026, 9, 9),
      );
      expect(trend.length, 12);
      expect(trend[7].label, '8月');
      expect(trend[7].expenseCents, 3000);
      expect(trend[7].incomeCents, 8000);
      expect(trend[7].netCents, 5000);
      expect(trend[8].label, '9月');
      expect(trend[8].expenseCents, 1200);
      expect(trend[8].incomeCents, 500);
      expect(trend[8].netCents, -700);
    });

    test('yearly trend across two years', () {
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
      final trend = StatisticsService.yearlyTrend(transactions);
      expect(trend.length, 2);
      expect(trend[0].label, '2025年');
      expect(trend[0].incomeCents, 10000);
      expect(trend[1].label, '2026年');
      expect(trend[1].expenseCents, 4000);
      expect(trend[1].netCents, -4000);
    });

    test('net balance: income minus expense, draft income excluded', () {
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
