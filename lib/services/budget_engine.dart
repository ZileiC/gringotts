/// Monthly budget engine (T-10, DESIGN_MAIN §2).
///
/// Pure functions over integer cents only. Nothing here touches the database:
/// callers pass in the month's budget row and its transactions, which makes
/// every boundary (leap years, month rollover, overspend, missing budget)
/// deterministic to unit test.
///
/// Spending scope follows the T-05 铁律: only confirmed expenses count.
/// Drafts, income and transfer placeholders are all excluded.
library;

import 'dart:math' as math;

import '../data/app_database.dart';
import '../domain/models.dart';
import 'statistics_service.dart';

/// Derived budget figures for one calendar month.
///
/// The budget-derived fields ([budgetCents], [fixedDailyCents],
/// [remainingCents], [todayQuotaCents], [todayRemainingCents]) are null when
/// no budget row exists for the month - the home page then shows onboarding
/// instead of fake numbers.
/// Actual spending ([spentCents], [todaySpentCents]) is always computed.
class BudgetSnapshot {
  const BudgetSnapshot({
    required this.budgetCents,
    required this.fixedDailyCents,
    required this.remainingCents,
    required this.liveDailyCents,
    required this.todayQuotaCents,
    required this.todayRemainingCents,
    required this.spentCents,
    required this.todaySpentCents,
    required this.todayCount,
    required this.daysInMonth,
    required this.remainingDays,
  });

  /// Spendable ceiling for the month: income - planned savings.
  final int? budgetCents;

  /// Fixed baseline quota: budgetCents / daysInMonth, floored.
  final int? fixedDailyCents;

  /// budgetCents - spentCents. May be negative (overspent).
  final int? remainingCents;

  /// Live quota: remainingCents / remainingDays, floored and clamped at 0.
  ///
  /// Superseded by [todayQuotaCents]/[todayRemainingCents] (T-15c): the old
  /// 'leftover spread over the days left'口径 put today's own spending back on
  /// today. Kept for callers/tests that still read it; the home Hero and the
  /// quick-entry preview no longer do.
  final int? liveDailyCents;

  /// 今日额度 Q_d (DESIGN_MAIN section 2.2 v2):
  /// floor((B + I - E-) / D) in integer cents, floored toward -infinity.
  ///
  /// Null when there is no live budget row, and null for a history month
  /// (section 2.3: a past month has no 'today').
  final int? todayQuotaCents;

  /// 今天还能花 = Q_d - T (1:1, never clamped: negative means overspent).
  /// Null whenever [todayQuotaCents] is null.
  final int? todayRemainingCents;

  /// Confirmed expense total for the month.
  final int spentCents;

  /// Confirmed expense total for today.
  final int todaySpentCents;

  /// Number of confirmed expense transactions today.
  final int todayCount;

  final int daysInMonth;
  final int remainingDays;

  /// True when a budget exists for the month.
  bool get hasBudget => budgetCents != null;

  /// True when confirmed spending already exceeds the budget.
  bool get isOverspent => remainingCents != null && remainingCents! < 0;

  /// Spent / budget as a display ratio (0..1 clamped, 1 when overspent).
  ///
  /// A non-positive budget has no meaningful ratio: full when anything was
  /// spent, empty otherwise.
  double get spentRatio {
    final budget = budgetCents;
    if (budget == null) return 0;
    if (budget <= 0) return spentCents > 0 ? 1 : 0;
    final ratio = spentCents / budget;
    return ratio < 0 ? 0 : (ratio > 1 ? 1 : ratio);
  }
}

/// Stateless budget calculator.
class BudgetEngine {
  BudgetEngine._();

  /// `YYYY-MM` calendar key used by the `budget_months` table.
  static String monthKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}';

  /// Gregorian leap-year rule (400/100/4).
  static bool isLeapYear(int year) =>
      (year % 4 == 0 && year % 100 != 0) || year % 400 == 0;

  /// Real number of days in [year]-[month] (28/29/30/31).
  static int daysInMonth(int year, int month) {
    assert(month >= 1 && month <= 12, 'month must be 1..12');
    switch (month) {
      case 2:
        return isLeapYear(year) ? 29 : 28;
      case 4:
      case 6:
      case 9:
      case 11:
        return 30;
      default:
        return 31;
    }
  }

  /// Days left in the month including today: daysInMonth - day + 1.
  static int remainingDays({required int year, required int month, required int day}) {
    // Guard against invalid input so callers can never divide by zero.
    return math.max(1, daysInMonth(year, month) - day + 1);
  }

  /// Spendable ceiling: income - planned savings (may be <= 0).
  static int budgetCents({required int incomeCents, required int savingsTargetCents}) =>
      incomeCents - savingsTargetCents;

  /// Fixed baseline quota, floored toward negative infinity.
  static int fixedDailyCents({required int budgetCents, required int daysInMonth}) {
    assert(daysInMonth > 0);
    return _floorDiv(budgetCents, daysInMonth);
  }

  /// Live quota: remaining / days left, floored, clamped at 0 for display.
  static int liveDailyCents({required int remainingCents, required int remainingDays}) {
    assert(remainingDays > 0);
    return math.max(0, _floorDiv(remainingCents, remainingDays));
  }

  /// 今日额度 Q_d = floor((B + I - E-) / D) (DESIGN_MAIN section 2.2 v2).
  ///
  /// [budgetCents] is B (income - planned savings), [tempIncomeCents] is the
  /// month's confirmed income I (section 2.2b/11.7) and
  /// [spentBeforeTodayCents] is E- = S - T, the month's confirmed spending
  /// excluding today. Integer cents, floored toward -infinity, never clamped.
  static int todayQuotaCents({
    required int budgetCents,
    required int tempIncomeCents,
    required int spentBeforeTodayCents,
    required int remainingDays,
  }) {
    assert(remainingDays > 0);
    return _floorDiv(
      budgetCents + tempIncomeCents - spentBeforeTodayCents,
      remainingDays,
    );
  }

  /// 今天还能花 = Q_d - T. The 1:1 invariant (a record of X drops it by exactly
  /// X) and the no-clamp rule (section 2.3) both live here, once, so no caller
  /// can drift into a second formula.
  static int todayRemainingCents({
    required int todayQuotaCents,
    required int todaySpentCents,
  }) =>
      todayQuotaCents - todaySpentCents;

  /// Confirmed expense cents in [year]-[month] (drafts/income/transfer excluded).
  static int spentCentsInMonth(
    List<Transaction> transactions, {
    required int year,
    required int month,
  }) {
    var total = 0;
    for (final t in transactions) {
      if (!_countsAsSpending(t)) continue;
      final at = t.occurredAt;
      if (at.year == year && at.month == month) total += t.amountCents;
    }
    return total;
  }

  /// Confirmed expense cents and count on the same local day as [day].
  static ({int cents, int count}) todaySpending(
    List<Transaction> transactions, {
    required DateTime day,
  }) {
    var cents = 0;
    var count = 0;
    for (final t in transactions) {
      if (!_countsAsSpending(t)) continue;
      final at = t.occurredAt;
      if (at.year == day.year && at.month == day.month && at.day == day.day) {
        cents += t.amountCents;
        count++;
      }
    }
    return (cents: cents, count: count);
  }

  /// Full snapshot for [now]'s month.
  ///
  /// [budget] may be null (or tombstoned) - the budget-derived figures then
  /// stay null while actual spending is still reported.
  static BudgetSnapshot compute({
    BudgetMonth? budget,
    required List<Transaction> transactions,
    required DateTime now,
    bool isCurrentMonth = true,
  }) {
    final days = daysInMonth(now.year, now.month);
    final left = remainingDays(year: now.year, month: now.month, day: now.day);
    final spent = spentCentsInMonth(transactions, year: now.year, month: now.month);
    final today = todaySpending(transactions, day: now);

    final live = budget != null && budget.deletedAt == null ? budget : null;
    if (live == null) {
      return BudgetSnapshot(
        budgetCents: null,
        fixedDailyCents: null,
        remainingCents: null,
        liveDailyCents: null,
        todayQuotaCents: null,
        todayRemainingCents: null,
        spentCents: spent,
        todaySpentCents: today.cents,
        todayCount: today.count,
        daysInMonth: days,
        remainingDays: left,
      );
    }

    final monthly = budgetCents(
      incomeCents: live.incomeCents,
      savingsTargetCents: live.savingsTargetCents,
    );
    final remaining = monthly - spent;

    // T-15c: 今天还能花 shares the v2 formula the Hero and the quick-entry
    // preview both read. A history month has no 'today' (section 2.3), so the
    // two derived values stay null there.
    int? quota;
    int? todayLeft;
    if (isCurrentMonth) {
      // 临时收入 I: the ONE income aggregation from section 11.7, month-scoped
      // (this engine receives every month's rows, like the other helpers).
      final tempIncome = StatisticsService.totals(
        transactions
            .where((t) =>
                t.occurredAt.year == now.year && t.occurredAt.month == now.month)
            .toList(),
      ).incomeCents;
      final quotaValue = todayQuotaCents(
        budgetCents: monthly,
        tempIncomeCents: tempIncome,
        spentBeforeTodayCents: spent - today.cents,
        remainingDays: left,
      );
      quota = quotaValue;
      todayLeft = todayRemainingCents(
        todayQuotaCents: quotaValue,
        todaySpentCents: today.cents,
      );
    }

    return BudgetSnapshot(
      budgetCents: monthly,
      fixedDailyCents: fixedDailyCents(budgetCents: monthly, daysInMonth: days),
      remainingCents: remaining,
      liveDailyCents: liveDailyCents(remainingCents: remaining, remainingDays: left),
      todayQuotaCents: quota,
      todayRemainingCents: todayLeft,
      spentCents: spent,
      todaySpentCents: today.cents,
      todayCount: today.count,
      daysInMonth: days,
      remainingDays: left,
    );
  }

  /// A transaction counts as spending only when confirmed, alive and expense.
  static bool _countsAsSpending(Transaction t) =>
      !t.isDraft &&
      t.deletedAt == null &&
      t.type == TransactionType.expense;

  /// Mathematical floor division (Dart's `~/` truncates toward zero).
  static int _floorDiv(int numerator, int denominator) {
    final q = numerator ~/ denominator;
    final r = numerator % denominator;
    return (r != 0 && numerator < 0) ? q - 1 : q;
  }
}
