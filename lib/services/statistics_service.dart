/// Aggregation service for statistics (T-05).
///
/// Pure functions over integer-cents values. Drafts are NEVER counted
/// (record-first philosophy: only confirmed records hit reports).
/// Transfer transactions are placeholders and are excluded from expense /
/// income / balance math.
library;

import '../data/app_database.dart';
import '../domain/models.dart';
import 'budget_engine.dart';

/// One aggregated bucket (e.g. one category's total in a period).
class CategoryTotal {
  const CategoryTotal({required this.categoryId, required this.cents});

  final String? categoryId;

  /// Null category = backfilled drafts that have no category yet.
  final int cents;
}

/// One period bucket for the trend line chart.
///
/// [incomeCents] is the confirmed income flow in the bucket (temporary
/// income); [baselineIncomeCents] is the guaranteed monthly income allocated
/// to that bucket (amortised over the days in the day view). The chart-2
/// income line plots [incomeLineCents], so a month with a budget can never
/// collapse onto the x axis.
class PeriodPoint {
  const PeriodPoint({
    required this.label,
    required this.expenseCents,
    required this.incomeCents,
    this.baselineIncomeCents = 0,
  });

  final String label;
  final int expenseCents;
  final int incomeCents;
  final int baselineIncomeCents;

  /// Income line value: 保底均摊 + 临时收入.
  int get incomeLineCents => baselineIncomeCents + incomeCents;

  int get netCents => incomeCents - expenseCents;
}

/// One bar of chart 1 (每日支出  额度对照).
///
/// [index] is the x value; it is ALWAYS the integer data-point index, so the
/// bottom labels can never drift away from the bars (T-21 diagnosis 2).
class SpendBar {
  const SpendBar({
    required this.index,
    required this.label,
    required this.expenseCents,
    required this.tempIncomeCents,
    this.allowanceCents,
  });

  final int index;
  final String label;
  final int expenseCents;

  /// Confirmed income flow on this bucket (drawn as the green dot).
  final int tempIncomeCents;

  /// Spendable allowance for the bucket: day quota in the day view, the month
  /// budget in the month view, the year's budget in the year view. Null when
  /// that period has no budget row - then no baseline is drawn.
  final int? allowanceCents;

  bool get overLimit => allowanceCents != null && expenseCents > allowanceCents!;

  /// The part of the bar inside the allowance (elevated fill + hairline edge).
  int get baseCents => overLimit ? allowanceCents! : expenseCents;

  /// The part of the bar past the allowance (painted semanticExpense).
  int get overCents => overLimit ? expenseCents - allowanceCents! : 0;

  bool get hasTempIncome => tempIncomeCents > 0;
}

/// Period totals for the statistics summary card and chart 2.
///
/// DESIGN_MAIN 11.7 freezes one definition for the page's numbers:
/// 保底收入 = the period's `budget_months.income_cents` sum (0 without a budget
/// row, never invented), 临时收入 = confirmed income flows, 支出 = confirmed
/// expense flows, 净结余 = 保底 + 临时 - 支出. The planned savings target is a
/// deduction from the spendable budget only; it never touches the balance.
class PeriodSummary {
  const PeriodSummary({
    required this.baselineIncomeCents,
    required this.tempIncomeCents,
    required this.expenseCents,
  });

  /// 保底收入: the period's budget months' income sum.
  final int baselineIncomeCents;

  /// 临时收入: the period's confirmed income flows.
  final int tempIncomeCents;

  /// 支出: the period's confirmed expense flows.
  final int expenseCents;

  /// What chart 2 plots and what the card shows as income: 保底 + 临时.
  int get incomeCents => baselineIncomeCents + tempIncomeCents;

  /// 净结余 = 保底 + 临时 - 支出 (DESIGN_MAIN 11.7).
  int get netCents => StatisticsService.netBalanceCents(
        baselineIncomeCents: baselineIncomeCents,
        tempIncomeCents: tempIncomeCents,
        expenseCents: expenseCents,
      );
}
/// One slice of a category chart (pie / donut).
///
/// [colorIndex] is the position of the slice in the canonical palette order,
/// so every chart that consumes the same totals paints identical colors.
/// [isOther] marks the merged remainder slice (beyond the named top N).
class CategorySlice {
  const CategorySlice({
    required this.categoryId,
    required this.cents,
    required this.colorIndex,
    this.isOther = false,
  });

  final String? categoryId;
  final int cents;
  final int colorIndex;
  final bool isOther;
}

/// Aggregation engine.
class StatisticsService {
  StatisticsService._();

  static bool _countable(Transaction t) =>
      !t.isDraft && t.deletedAt == null && t.type != TransactionType.transfer;

  /// Category totals for confirmed expense transactions in [transactions].
  /// Drafts and transfers never appear here.
  static List<CategoryTotal> expenseByCategory(List<Transaction> transactions) {
    final map = <String?, int>{};
    for (final t in transactions) {
      if (!_countable(t) || t.type != TransactionType.expense) continue;
      map[t.categoryId] = (map[t.categoryId] ?? 0) + t.amountCents;
    }
    final result = map.entries
        .map((e) => CategoryTotal(categoryId: e.key, cents: e.value))
        .toList();
    result.sort((a, b) => b.cents.compareTo(a.cents));
    return result;
  }

  /// Builds chart slices from [totals] (expected sorted by cents desc).
  ///
  /// The first [maxNamed] categories keep their identity; everything after is
  /// merged into a single "其他" slice. This is the single slicing function the
  /// statistics pie and the home donut both consume, so their data and colour
  /// order can never diverge.
  static List<CategorySlice> chartSlices(
    List<CategoryTotal> totals, {
    int maxNamed = 3,
  }) {
    if (totals.isEmpty) return const <CategorySlice>[];
    final namedCount = totals.length <= maxNamed ? totals.length : maxNamed;
    final slices = <CategorySlice>[
      for (var i = 0; i < namedCount; i++)
        CategorySlice(
          categoryId: totals[i].categoryId,
          cents: totals[i].cents,
          colorIndex: i,
        ),
    ];
    if (namedCount < totals.length) {
      var rest = 0;
      for (var i = namedCount; i < totals.length; i++) {
        rest += totals[i].cents;
      }
      slices.add(CategorySlice(
        categoryId: null,
        cents: rest,
        colorIndex: namedCount,
        isOther: true,
      ));
    }
    return slices;
  }

  /// Builds period points for a day/month/year range.
  ///
  /// [key] extracts the period label from a transaction's occurredAt.
  static List<PeriodPoint> trend(
    List<Transaction> transactions, {
    required String Function(DateTime) key,
    List<String> orderedLabels = const [],
  }) {
    final map = <String, ({int expense, int income})>{};
    for (final t in transactions) {
      if (!_countable(t)) continue;
      final label = key(t.occurredAt);
      final current = map[label] ?? (expense: 0, income: 0);
      if (t.type == TransactionType.expense) {
        map[label] = (expense: current.expense + t.amountCents, income: current.income);
      } else if (t.type == TransactionType.income) {
        map[label] = (expense: current.expense, income: current.income + t.amountCents);
      }
    }
    final labels = orderedLabels.isNotEmpty
        ? orderedLabels
        : (map.keys.toList()..sort());
    return [
      for (final label in labels)
        PeriodPoint(
          label: label,
          expenseCents: map[label]?.expense ?? 0,
          incomeCents: map[label]?.income ?? 0,
        ),
    ];
  }

  /// Labels for every day of [month] (`M/D`): 28/29/30/31 entries.
  static List<String> monthDayLabels(DateTime month) {
    final days = BudgetEngine.daysInMonth(month.year, month.month);
    return [for (var d = 1; d <= days; d++) '${month.month}/$d'];
  }

  /// Guaranteed income amortised over the days of [month]:
  /// `budget.incomeCents / daysInMonth`. Null without a live budget row.
  ///
  /// This is the 保底收入 side of the T-21 income semantics. It is derived on
  /// every read and never stored (data iron rule: no derived columns).
  static int? incomeBaselinePerDay({
    required BudgetMonth? budget,
    required DateTime month,
  }) {
    if (budget == null || budget.deletedAt != null) return null;
    return budget.incomeCents ~/ BudgetEngine.daysInMonth(month.year, month.month);
  }

  /// Day buckets for the whole selected month (28/29/30/31 bars).
  ///
  /// [baselineIncomePerDayCents] is the amortised guaranteed income (null when
  /// the month has no budget); it is stamped on every point so chart 2 can plot
  /// 保底均摊 + 临时收入 and never collapse onto the x axis.
  static List<PeriodPoint> monthDays(
    List<Transaction> transactions, {
    required DateTime month,
    int? baselineIncomePerDayCents,
  }) {
    final inMonth = transactions
        .where((t) =>
            t.occurredAt.year == month.year && t.occurredAt.month == month.month)
        .toList();
    final points = trend(
      inMonth,
      key: (dt) => '${dt.month}/${dt.day}',
      orderedLabels: monthDayLabels(month),
    );
    if (baselineIncomePerDayCents == null) return points;
    return [
      for (final p in points)
        PeriodPoint(
          label: p.label,
          expenseCents: p.expenseCents,
          incomeCents: p.incomeCents,
          baselineIncomeCents: baselineIncomePerDayCents,
        ),
    ];
  }
  /// Month trend: 12 buckets (Jan .. Dec of [year]).
  ///
  /// [baselineIncomeByMonth] maps 1..12 to that month's guaranteed income
  /// (budget.incomeCents); months without a budget stay 0. Rows from other
  /// years are excluded, so two Septembers can no longer merge.
  static List<PeriodPoint> monthlyTrend(
    List<Transaction> transactions, {
    required int year,
    Map<int, int> baselineIncomeByMonth = const <int, int>{},
  }) {
    final inYear = transactions.where((t) => t.occurredAt.year == year).toList();
    final points = trend(
      inYear,
      key: (dt) => '${dt.month}月',
      orderedLabels: [for (var m = 1; m <= 12; m++) '$m月'],
    );
    return [
      for (var i = 0; i < points.length; i++)
        PeriodPoint(
          label: points[i].label,
          expenseCents: points[i].expenseCents,
          incomeCents: points[i].incomeCents,
          baselineIncomeCents: baselineIncomeByMonth[i + 1] ?? 0,
        ),
    ];
  }
  /// Year trend: all years seen in the data, ascending.
  ///
  /// [baselineIncomeByYear] holds each year's guaranteed income total.
  static List<PeriodPoint> yearlyTrend(
    List<Transaction> transactions, {
    Map<int, int> baselineIncomeByYear = const <int, int>{},
  }) {
    final years = <int>{};
    for (final t in transactions) {
      years.add(t.occurredAt.year);
    }
    final labels = years.map((y) => '$y年').toList()..sort();
    final points = trend(
      transactions,
      key: (dt) => '${dt.year}年',
      orderedLabels: labels,
    );
    return [
      for (final p in points)
        PeriodPoint(
          label: p.label,
          expenseCents: p.expenseCents,
          incomeCents: p.incomeCents,
          baselineIncomeCents: baselineIncomeByYear[
                  int.tryParse(p.label.replaceAll('年', '')) ?? 0] ??
              0,
        ),
    ];
  }

  /// Builds chart-1 bars from [points].
  ///
  /// [allowanceByIndex] carries the spendable allowance per data point (the day
  /// quota in the day view, the month budget in the month view, the year's
  /// budget in the year view). A missing or null entry means 无预算 for that
  /// bucket: no baseline is drawn and nothing is painted red.
  static List<SpendBar> spendBars(
    List<PeriodPoint> points, {
    List<int?> allowanceByIndex = const <int?>[],
  }) {
    return [
      for (var i = 0; i < points.length; i++)
        SpendBar(
          index: i,
          label: points[i].label,
          expenseCents: points[i].expenseCents,
          tempIncomeCents: points[i].incomeCents,
          allowanceCents:
              i < allowanceByIndex.length ? allowanceByIndex[i] : null,
        ),
    ];
  }
  /// The one and only net-balance definition (DESIGN_MAIN 11.7):
  /// `baseline + temp - expense`. The planned savings target is deliberately
  /// absent - it reduces the spendable budget, never the balance.
  static int netBalanceCents({
    required int baselineIncomeCents,
    required int tempIncomeCents,
    required int expenseCents,
  }) =>
      baselineIncomeCents + tempIncomeCents - expenseCents;

  /// Aggregates the period [points] that chart 2 plots into the summary card's
  /// numbers. Chart 2 and the card read the same list through this function, so
  /// the income line and the card can never diverge again (T-23)。
  static PeriodSummary summarize(List<PeriodPoint> points) {
    var baseline = 0;
    var temp = 0;
    var expense = 0;
    for (final p in points) {
      baseline += p.baselineIncomeCents;
      temp += p.incomeCents;
      expense += p.expenseCents;
    }
    return PeriodSummary(
      baselineIncomeCents: baseline,
      tempIncomeCents: temp,
      expenseCents: expense,
    );
  }

  /// Totals for a set of transactions (flow math plus an optional 保底收入).
  ///
  /// [baselineIncomeCents] is the period's 保底收入 (the sum of the budget
  /// months' income); omit it for pure flow totals. [netCents] follows
  /// DESIGN_MAIN 11.7: 保底 + 临时 - 支出.
  static ({
    int baselineIncomeCents,
    int expenseCents,
    int incomeCents,
    int netCents
  }) totals(List<Transaction> transactions, {int baselineIncomeCents = 0}) {
    var expense = 0;
    var income = 0;
    for (final t in transactions) {
      if (!_countable(t)) continue;
      if (t.type == TransactionType.expense) {
        expense += t.amountCents;
      } else if (t.type == TransactionType.income) {
        income += t.amountCents;
      }
    }
    return (
      baselineIncomeCents: baselineIncomeCents,
      expenseCents: expense,
      incomeCents: income,
      netCents: netBalanceCents(
        baselineIncomeCents: baselineIncomeCents,
        tempIncomeCents: income,
        expenseCents: expense,
      ),
    );
  }
}