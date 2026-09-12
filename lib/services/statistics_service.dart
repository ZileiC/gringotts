/// Aggregation service for statistics (T-05).
///
/// Pure functions over integer-cents values. Drafts are NEVER counted
/// (record-first philosophy: only confirmed records hit reports).
/// Transfer transactions are placeholders and are excluded from expense /
/// income / balance math.
library;

import '../data/app_database.dart';
import '../domain/models.dart';

/// One aggregated bucket (e.g. one category's total in a period).
class CategoryTotal {
  const CategoryTotal({required this.categoryId, required this.cents});

  final String? categoryId;

  /// Null category = backfilled drafts that have no category yet.
  final int cents;
}

/// One period bucket for the trend line chart.
class PeriodPoint {
  const PeriodPoint({required this.label, required this.expenseCents, required this.incomeCents});

  final String label;
  final int expenseCents;
  final int incomeCents;

  int get netCents => incomeCents - expenseCents;
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

  /// Day trend: 7 buckets (6 days ago .. today).
  static List<PeriodPoint> dailyTrend(List<Transaction> transactions, {DateTime? now}) {
    final today = (now ?? DateTime.now());
    final labels = <String>[];
    for (var i = 6; i >= 0; i--) {
      final d = today.subtract(Duration(days: i));
      labels.add('${d.month}/${d.day}');
    }
    return trend(
      transactions,
      key: (dt) => '${dt.month}/${dt.day}',
      orderedLabels: labels,
    );
  }

  /// Month trend: 12 buckets (Jan .. Dec of the current year).
  static List<PeriodPoint> monthlyTrend(List<Transaction> transactions, {DateTime? now}) {

    final labels = [for (var m = 1; m <= 12; m++) '$m月'];
    return trend(
      transactions,
      key: (dt) => '${dt.month}月',
      orderedLabels: labels,
    );
  }

  /// Year trend: all years seen in the data, ascending.
  static List<PeriodPoint> yearlyTrend(List<Transaction> transactions) {
    final years = <int>{};
    for (final t in transactions) {
      years.add(t.occurredAt.year);
    }
    final labels = years.map((y) => '$y年').toList()..sort();
    return trend(
      transactions,
      key: (dt) => '${dt.year}年',
      orderedLabels: labels,
    );
  }

  /// Totals for a set of transactions (net balance math).
  static ({int expenseCents, int incomeCents, int netCents}) totals(
      List<Transaction> transactions) {
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
    return (expenseCents: expense, incomeCents: income, netCents: income - expense);
  }
}
