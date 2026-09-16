import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gringotts/data/app_database.dart';
import 'package:gringotts/domain/models.dart';
import 'package:gringotts/services/budget_engine.dart';
import 'package:gringotts/services/statistics_service.dart';

/// T-15c acceptance: TICKETS_M2A assertions (1)-(9) against the frozen v2
/// formula (DESIGN_MAIN section 2.2):
///
///   Q_d = floor((B + I - E-) / D)     (integer cents, floor)
///   今天还能花 = Q_d - T                (1:1, never clamped)
///
/// Widget evidence for (6)/(7) lives in home_page_test.dart and
/// quick_entry_layout_test.dart; this file owns the engine-level evidence.
Transaction _tx({
  required int amountCents,
  required DateTime occurredAt,
  TransactionType type = TransactionType.expense,
  bool isDraft = false,
  DateTime? deletedAt,
}) =>
    Transaction(
      id: 'tx-$amountCents-${type.name}-${occurredAt.microsecondsSinceEpoch}-'
          '${deletedAt?.microsecondsSinceEpoch ?? 0}',
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
  required int incomeCents,
  required int savingsTargetCents,
  String yearMonth = '2026-09',
  DateTime? deletedAt,
}) =>
    BudgetMonth(
      id: 'b-$yearMonth',
      yearMonth: yearMonth,
      incomeCents: incomeCents,
      savingsTargetCents: savingsTargetCents,
      createdAt: DateTime(2026, 9, 1),
      updatedAt: DateTime(2026, 9, 1),
      deletedAt: deletedAt,
    );

void main() {
  test('(1) 1:1 invariant: recording X drops 今天还能花 by exactly X', () {
    for (final days in <int>[1, 15, 30]) {
      final quota = BudgetEngine.todayQuotaCents(
        budgetCents: 140000,
        tempIncomeCents: 0,
        spentBeforeTodayCents: 75310,
        remainingDays: days,
      );
      for (final spentToday in <int>[0, 1, 4290, 50000]) {
        final before = BudgetEngine.todayRemainingCents(
          todayQuotaCents: quota,
          todaySpentCents: spentToday,
        );
        final after = BudgetEngine.todayRemainingCents(
          todayQuotaCents: quota,
          todaySpentCents: spentToday + 4290,
        );
        expect(after - before, -4290, reason: 'D=$days T=$spentToday');
      }
    }
  });

  test('(2) incident replay: 43.12 -> 0.22 (B=1400.00, E-=753.10, D=15)', () {
    final budget = _budget(incomeCents: 140000, savingsTargetCents: 0);
    final before = BudgetEngine.compute(
      budget: budget,
      transactions: <Transaction>[
        _tx(amountCents: 75310, occurredAt: DateTime(2026, 9, 10)),
      ],
      now: DateTime(2026, 9, 16),
    );
    expect(before.remainingDays, 15);
    expect(before.todayQuotaCents, 4312,
        reason: 'floor((140000 - 75310) / 15) = floor(64690/15) = 4312 = 43.12');
    expect(before.todayRemainingCents, 4312);

    final after = BudgetEngine.compute(
      budget: budget,
      transactions: <Transaction>[
        _tx(amountCents: 75310, occurredAt: DateTime(2026, 9, 10)),
        _tx(amountCents: 4290, occurredAt: DateTime(2026, 9, 16)),
      ],
      now: DateTime(2026, 9, 16),
    );
    expect(after.todaySpentCents, 4290);
    expect(after.todayQuotaCents, 4312,
        reason: 'E- excludes today, so Q_d does not move within the day');
    expect(after.todayRemainingCents, 22, reason: '43.12 - 42.90 = 0.22');
    expect(after.todayRemainingCents, before.todayRemainingCents! - 4290);
  });

  test('(3) overspend stays negative - never clamped to 0', () {
    final quota = BudgetEngine.todayQuotaCents(
      budgetCents: 100000,
      tempIncomeCents: 0,
      spentBeforeTodayCents: 0,
      remainingDays: 10,
    );
    expect(quota, 10000);
    expect(
      BudgetEngine.todayRemainingCents(
          todayQuotaCents: quota, todaySpentCents: 12500),
      -2500,
    );
    // Exactly at the quota the value is 0; one cent past it is negative.
    expect(
      BudgetEngine.todayRemainingCents(
          todayQuotaCents: quota, todaySpentCents: 10000),
      0,
    );
    final over = BudgetEngine.todayRemainingCents(
        todayQuotaCents: quota, todaySpentCents: 10001);
    expect(over, -1);
    expect(over, isNot(0), reason: 'old formula clamped this to 0.00');
  });

  test('(4) cross-day: D drops by one and the value is recomputed', () {
    final budget = _budget(incomeCents: 140000, savingsTargetCents: 0);
    final rows = <Transaction>[
      _tx(amountCents: 75310, occurredAt: DateTime(2026, 9, 10)),
      _tx(amountCents: 4290, occurredAt: DateTime(2026, 9, 16)),
    ];
    final day16 = BudgetEngine.compute(
        budget: budget, transactions: rows, now: DateTime(2026, 9, 16));
    final day17 = BudgetEngine.compute(
        budget: budget, transactions: rows, now: DateTime(2026, 9, 17));

    expect(day16.remainingDays, 15);
    expect(day17.remainingDays, 14);
    expect(day16.todayRemainingCents, 22);
    // E- now carries the 42.90 and D is one smaller: floor(60400/14) = 4314.
    expect(day17.todayQuotaCents, 4314);
    expect(day17.todayRemainingCents, 4314);
  });

  test('(5) no budget row -> derived values are null (no invented numbers)', () {
    final s = BudgetEngine.compute(
        budget: null, transactions: const <Transaction>[], now: DateTime(2026, 9, 16));
    expect(s.budgetCents, isNull);
    expect(s.fixedDailyCents, isNull);
    expect(s.remainingCents, isNull);
    expect(s.todayQuotaCents, isNull);
    expect(s.todayRemainingCents, isNull);
    expect(s.spentCents, 0);
    expect(s.remainingDays, 15);
  });

  test('(5b) tombstoned budget row -> derived values are null again', () {
    final budget = _budget(
        incomeCents: 140000, savingsTargetCents: 0, deletedAt: DateTime(2026, 9, 16));
    final s = BudgetEngine.compute(
        budget: budget, transactions: const <Transaction>[], now: DateTime(2026, 9, 16));
    expect(s.todayQuotaCents, isNull);
    expect(s.todayRemainingCents, isNull);
  });

  test('(6) history month produces no 今天还能花 (engine half)', () {
    final budget = _budget(incomeCents: 140000, savingsTargetCents: 0);
    final s = BudgetEngine.compute(
      budget: budget,
      transactions: const <Transaction>[],
      now: DateTime(2026, 9, 30),
      isCurrentMonth: false,
    );
    expect(s.todayQuotaCents, isNull);
    expect(s.todayRemainingCents, isNull);
    // The month baseline (Q_base) and the month totals are still available.
    expect(s.fixedDailyCents, 4666, reason: 'floor(140000/30)');
    expect(s.budgetCents, 140000);
    expect(s.spentCents, 0);
  });

  test('(7) source: Hero and quick-entry preview share todayRemainingCents', () {
    final hero = File('lib/pages/home_page.dart').readAsStringSync();
    final preview = File('lib/pages/quick_entry_page.dart').readAsStringSync();
    expect(hero, contains('todayRemainingCents'));
    expect(preview, contains('todayRemainingCents'));
    expect(preview.contains('liveDailyCents'), isFalse,
        reason: 'the preview must not keep the retired formula');

    final engine = File('lib/services/budget_engine.dart').readAsStringSync();
    expect(engine, contains('static int todayQuotaCents('));
    expect(engine, contains('static int todayRemainingCents('));
  });

  test('(8) chart 1 allowance stays Q_base (fixedDailyCents, untouched)', () {
    final stats = File('lib/pages/stats_page.dart').readAsStringSync();
    expect(stats, contains('BudgetEngine.fixedDailyCents'));
    expect(stats.contains('todayRemainingCents'), isFalse);
    expect(stats.contains('todayQuotaCents'), isFalse);
    expect(BudgetEngine.fixedDailyCents(budgetCents: 140000, daysInMonth: 30), 4666);
  });

  test('(9) temporary income enters the numerator (spread over D)', () {
    final budget = _budget(incomeCents: 140000, savingsTargetCents: 0);
    final rows = <Transaction>[
      _tx(amountCents: 75310, occurredAt: DateTime(2026, 9, 10)),
    ];
    final base = BudgetEngine.compute(
        budget: budget, transactions: rows, now: DateTime(2026, 9, 16));
    expect(base.todayQuotaCents, 4312);

    final income = _tx(
      amountCents: 30000,
      type: TransactionType.income,
      occurredAt: DateTime(2026, 9, 16),
    );
    final withIncome = BudgetEngine.compute(
      budget: budget,
      transactions: <Transaction>[...rows, income],
      now: DateTime(2026, 9, 16),
    );
    expect(withIncome.todayQuotaCents, 6312,
        reason: 'floor((140000 + 30000 - 75310) / 15) = floor(94690/15) = 6312');
    // Identical to the frozen formula fed by the section 11.7 aggregate.
    expect(
      withIncome.todayQuotaCents,
      BudgetEngine.todayQuotaCents(
        budgetCents: base.budgetCents!,
        tempIncomeCents: StatisticsService.totals(<Transaction>[income]).incomeCents,
        spentBeforeTodayCents: base.spentCents - base.todaySpentCents,
        remainingDays: base.remainingDays,
      ),
    );

    // Long-press delete (tombstone) -> quota returns to the original value.
    final tombstoned = _tx(
      amountCents: 30000,
      type: TransactionType.income,
      occurredAt: DateTime(2026, 9, 16),
      deletedAt: DateTime(2026, 9, 16, 23),
    );
    final afterDelete = BudgetEngine.compute(
      budget: budget,
      transactions: <Transaction>[...rows, tombstoned],
      now: DateTime(2026, 9, 16),
    );
    expect(afterDelete.todayQuotaCents, base.todayQuotaCents);
  });

  test('(9b) source: there is exactly one income summation (11.7 reused)', () {
    final engine = File('lib/services/budget_engine.dart').readAsStringSync();
    expect(engine, contains('StatisticsService.totals'));
    expect(engine.contains('TransactionType.income'), isFalse,
        reason: 'the engine must not roll its own income loop');
  });

  test('(9c) drafts and transfers never enter the numerator', () {
    final budget = _budget(incomeCents: 140000, savingsTargetCents: 0);
    final clean = BudgetEngine.compute(
        budget: budget, transactions: const <Transaction>[], now: DateTime(2026, 9, 16));
    final noisy = BudgetEngine.compute(
      budget: budget,
      transactions: <Transaction>[
        _tx(
            amountCents: 99999,
            type: TransactionType.income,
            occurredAt: DateTime(2026, 9, 16),
            isDraft: true),
      ],
      now: DateTime(2026, 9, 16),
    );
    expect(noisy.todayQuotaCents, clean.todayQuotaCents);
  });
}
