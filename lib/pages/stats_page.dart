import 'dart:io';
import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/app.dart';
import '../data/app_database.dart';
import '../data/repositories/repositories.dart';
import '../data/repositories/budget_repository.dart';
import '../services/budget_engine.dart';
import '../pages/ledger_page.dart';
import '../services/export_service.dart';
import '../services/chart_scale.dart';
import '../services/statistics_service.dart';
import '../ui/month_sheet.dart';
import '../ui/motion.dart';
import '../ui/tokens.dart';

enum StatsRange { daily, monthly, yearly }

/// Statistics page: range switch, category pie, dual-line trend
/// (expense/income) + net balance. Drafts never counted.
class StatsPage extends ConsumerStatefulWidget {
  const StatsPage({super.key});

  @override
  ConsumerState<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends ConsumerState<StatsPage>
    with SingleTickerProviderStateMixin {
  StatsRange _range = StatsRange.daily;
  final ScrollController _scroll = ScrollController();

  TransactionRepository get _txRepo => ref.read(transactionRepositoryProvider);

  /// Monthly budgets for the chart allowances and the amortised baseline.
  BudgetRepository get _budgetRepo => ref.read(budgetRepositoryProvider);

  /// Shared selected month: analysis / ledger / stats are one source
  /// (DESIGN_MAIN 11.4).
  DateTime get _month => ref.watch(selectedMonthProvider);

  /// Month button: reuses the home calendar sheet component.
  Future<void> _openMonthSheet() {
    return showMonthSheet(
      context,
      sheetKey: const Key('stats_month_sheet'),
      selected: _month,
      onSelected: (month) =>
          ref.read(selectedMonthProvider.notifier).select(month),
    );
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  CategoryRepository get _categoryRepo => ref.read(categoryRepositoryProvider);

  /// T-12c Part A: the ledger is the statistics page's child (明细 >).
  void _openLedger() {
    Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => const LedgerPage()));
  }

  Future<void> _export() async {
    final db = ref.read(databaseProvider);
    final dir = await _exportDirectory();
    final paths = await ExportService.exportAll(db: db, directory: dir);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('已导出 ${paths.length} 个文件到文档目录'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<String> _exportDirectory() async {
    // Windows: documents; Android: Download. path_provider covers both.
    if (Theme.of(context).platform == TargetPlatform.android) {
      return '/storage/emulated/0/Download';
    }
    // Default to the user profile Documents directory on desktop.
    final home =
        Platform.environment['USERPROFILE'] ??
        Platform.environment['HOME'] ??
        '.';
    return '$home${Platform.pathSeparator}Documents';
  }

  /// The live budget row of [month], or null.
  static BudgetMonth? _budgetOf(List<BudgetMonth> budgets, DateTime month) {
    final key = BudgetEngine.monthKey(month);
    for (final b in budgets) {
      if (b.yearMonth == key) return b;
    }
    return null;
  }

  /// Spendable budget of a row (income - planned savings); null = no row.
  static int? _spendableOf(BudgetMonth? b) => b == null
      ? null
      : BudgetEngine.budgetCents(
          incomeCents: b.incomeCents,
          savingsTargetCents: b.savingsTargetCents,
        );

  String get _periodLabel => switch (_range) {
    StatsRange.daily => '${_month.year} 年 ${_month.month} 月',
    StatsRange.monthly => '${_month.year} 年',
    StatsRange.yearly => '全部年份',
  };

  /// Chart series for the selected range: the points (one per x tick), the
  /// spendable allowance that applies to each index (null = 无预算) and the
  /// period's spendable budget (null = the period has no budget row).
  ({List<PeriodPoint> points, List<int?> allowances, int? spendableCents})
  _series(List<Transaction> txs, List<BudgetMonth> budgets) {
    switch (_range) {
      case StatsRange.daily:
        final budget = _budgetOf(budgets, _month);
        final spendable = _spendableOf(budget);
        final days = BudgetEngine.daysInMonth(_month.year, _month.month);
        final dayAllowance = spendable == null
            ? null
            : BudgetEngine.fixedDailyCents(
                budgetCents: spendable,
                daysInMonth: days,
              );
        final points = StatisticsService.monthDays(
          txs,
          month: _month,
          baselineIncomeByDayCents: StatisticsService.incomeBaselineByDay(
            budget: budget,
            month: _month,
          ),
        );
        return (
          points: points,
          allowances: List<int?>.filled(points.length, dayAllowance),
          spendableCents: spendable,
        );
      case StatsRange.monthly:
        final year = _month.year;
        final incomeByMonth = <int, int>{};
        final allowanceByMonth = <int, int?>{};
        int? spendableSum;
        for (final b in budgets) {
          final parts = b.yearMonth.split('-');
          if (parts.length != 2) continue;
          final y = int.tryParse(parts[0]);
          final m = int.tryParse(parts[1]);
          if (y != year || m == null) continue;
          incomeByMonth[m] = b.incomeCents;
          allowanceByMonth[m] = _spendableOf(b);
          spendableSum = (spendableSum ?? 0) + (_spendableOf(b) ?? 0);
        }
        final points = StatisticsService.monthlyTrend(
          txs,
          year: year,
          baselineIncomeByMonth: incomeByMonth,
        );
        return (
          points: points,
          allowances: [
            for (var i = 0; i < points.length; i++) allowanceByMonth[i + 1],
          ],
          spendableCents: spendableSum,
        );
      case StatsRange.yearly:
        final incomeByYear = <int, int>{};
        final spendableByYear = <int, int>{};
        for (final b in budgets) {
          final y = int.tryParse(b.yearMonth.split('-').first);
          if (y == null) continue;
          incomeByYear[y] = (incomeByYear[y] ?? 0) + b.incomeCents;
          spendableByYear[y] =
              (spendableByYear[y] ?? 0) + (_spendableOf(b) ?? 0);
        }
        final points = StatisticsService.yearlyTrend(
          txs,
          baselineIncomeByYear: incomeByYear,
        );
        return (
          points: points,
          allowances: [
            for (final p in points)
              spendableByYear[int.tryParse(p.label.replaceAll('年', '')) ?? 0],
          ],
          spendableCents: spendableByYear.isEmpty
              ? null
              : spendableByYear.values.fold<int>(0, (a, b) => a + b),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('统计'),
            const SizedBox(width: AppSpacing.m),
            _StatsMonthButton(month: _month, onTap: _openMonthSheet),
          ],
        ),
        actions: [
          TextButton(
            key: const Key('stats_ledger_entry'),
            onPressed: _openLedger,
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('明细'),
                Icon(
                  Icons.chevron_right,
                  size: 18,
                  color: AppColors.inkSecondary,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.s),
        ],
      ),
      body: StreamBuilder<List<BudgetMonth>>(
        stream: _budgetRepo.watchMonths(),
        builder: (context, budgetSnapshot) {
          final budgets = budgetSnapshot.data ?? const <BudgetMonth>[];
          return StreamBuilder<List<Transaction>>(
            stream: _txRepo.watchAll(),
            builder: (context, snapshot) {
              final transactions = snapshot.data ?? const <Transaction>[];
              final series = _series(transactions, budgets);
              // T-23 / DESIGN_MAIN 11.7: the summary card reads the very same
              // points chart 2 plots, so card and income line share one
              // 保底 + 临时 aggregation.
              final summary = StatisticsService.summarize(series.points);
              final bars = StatisticsService.spendBars(
                series.points,
                allowanceByIndex: series.allowances,
              );

              return ListView(
                controller: _scroll,
                physics: const InertialScrollPhysics(),
                padding: const EdgeInsets.all(AppSpacing.m),
                children: [
                  // Range switch.
                  SegmentedButton<StatsRange>(
                    segments: const [
                      ButtonSegment(value: StatsRange.daily, label: Text('日')),
                      ButtonSegment(
                        value: StatsRange.monthly,
                        label: Text('月'),
                      ),
                      ButtonSegment(value: StatsRange.yearly, label: Text('年')),
                    ],
                    selected: {_range},
                    onSelectionChanged: (s) => setState(() => _range = s.first),
                  ),
                  const SizedBox(height: AppSpacing.m),
                  // Net balance card (sinks away on scroll).
                  SinkAwayHeader(
                    controller: _scroll,
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.l),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '净结余（保底 + 临时 \u2212 支出）',
                              key: const Key('stats_net_label'),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            CountUpNumber(
                              key: const Key('stats_net_value'),
                              valueCents: summary.netCents,
                              builder: (context, cents) => Text(
                                _yuan(cents),
                                style: Theme.of(context).textTheme.displayLarge
                                    ?.copyWith(
                                      fontSize: AppFont.display - 12,
                                      // DESIGN_T09 section 8.5: a negative balance
                                      // is semanticExpense; zero and positive stay
                                      // warm ink.
                                      color: cents < 0
                                          ? AppColors.semanticExpense
                                          : AppColors.ink,
                                    ),
                              ),
                            ),
                            const SizedBox(height: AppSpacing.s),
                            Text(
                              '保底收入 ${_yuan(summary.baselineIncomeCents)} \u00b7 '
                              '临时收入 ${_yuan(summary.tempIncomeCents)} \u00b7 '
                              '支出 ${_yuan(summary.expenseCents)}',
                              key: const Key('stats_breakdown'),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              '可花预算 '
                              '${series.spendableCents == null ? '未设预算' : _yuan(series.spendableCents!)}',
                              key: const Key('stats_spendable_budget'),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.l),
                  // Chart 1 (A): bars + allowance baseline + temporary income.
                  _SpendChartCard(
                    range: _range,
                    bars: bars,
                    periodLabel: _periodLabel,
                  ),
                  const SizedBox(height: AppSpacing.l),
                  // Chart 2 (B): dual-line trend.
                  Text('收支趋势', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: AppSpacing.s),
                  _TrendChart(
                    key: const Key('stats_trend_chart'),
                    points: series.points,
                    range: _range,
                    hasBudget: bars.any((b) => b.allowanceCents != null),
                  ),
                  const SizedBox(height: AppSpacing.l),
                  // Category pie.
                  Text('支出类别占比', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: AppSpacing.s),
                  _CategoryPieCard(
                    transactions: transactions,
                    categoryRepo: _categoryRepo,
                  ),
                  const SizedBox(height: AppSpacing.l),
                  // Export button.
                  // DESIGN_T09 section 8.5: the export is a hairline gold
                  // outline key - gold as border and label only, never as a
                  // large fill (the gold-discipline charter).
                  OutlinedButton.icon(
                    key: const Key('stats_export_button'),
                    onPressed: _export,
                    icon: const Icon(Icons.file_download, size: 18),
                    label: const Text('导出 CSV / JSON（带 BOM）'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.goldAccent,
                      side: const BorderSide(color: AppColors.goldAccent),
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.all(
                          Radius.circular(AppRadius.m),
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.l,
                        vertical: AppSpacing.s + AppSpacing.xs,
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  static String _yuan(int cents) {
    final display = cents % 100 == 0
        ? (cents ~/ 100).toString()
        : (cents / 100).toStringAsFixed(2);
    return '\u00a5$display';
  }
}

/// Money label with thousands separators (DESIGN_MAIN 11.2: 1,200).
String statsMoney(int cents) {
  final sign = cents < 0 ? '-' : '';
  final abs = cents.abs();
  final yuan = (abs ~/ 100).toString();
  final buf = StringBuffer();
  for (var i = 0; i < yuan.length; i++) {
    if (i > 0 && (yuan.length - i) % 3 == 0) buf.write(',');
    buf.write(yuan[i]);
  }
  final rest = abs % 100;
  if (rest == 0) return '$sign\u00a5$buf';
  return '$sign\u00a5$buf.${rest.toString().padLeft(2, '0')}';
}

/// Bottom axis: integer x positions only, so labels can never drift away from
/// the bars / points (T-21 diagnosis 2: the old length/6 interval is banned).
/// [step] sets the density; the first and last data points always get a label.
AxisTitles _bottomAxis(
  List<String> labels, {
  required int step,
  required TextStyle? style,
}) {
  final last = labels.length - 1;
  return AxisTitles(
    sideTitles: SideTitles(
      showTitles: true,
      reservedSize: 22,
      interval: 1,
      getTitlesWidget: (value, meta) {
        final index = value.round();
        if ((value - index).abs() > 0.001) return const SizedBox.shrink();
        if (index < 0 || index >= labels.length) return const SizedBox.shrink();
        final show = index == 0 || index == last || index % step == 0;
        if (!show) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(labels[index], style: style),
        );
      },
    ),
  );
}

/// Left axis: four money ticks (0 / 1/3 / 2/3 / max), tabular figures.
AxisTitles _leftAxis(double maxY, {required TextStyle? style}) {
  final interval = maxY > 0 ? maxY / 3 : 1.0;
  return AxisTitles(
    sideTitles: SideTitles(
      showTitles: true,
      reservedSize: 58,
      interval: interval,
      getTitlesWidget: (value, meta) {
        if (value < -0.001 || value > maxY * 1.0001) {
          return const SizedBox.shrink();
        }
        return Padding(
          padding: const EdgeInsets.only(right: 4),
          child: Text(statsMoney(value.round()), style: style),
        );
      },
    ),
  );
}

TextStyle? _axisStyle(BuildContext context) => Theme.of(context)
    .textTheme
    .bodySmall
    ?.copyWith(
      fontSize: 10,
      color: AppColors.inkSecondary,
      fontFeatures: AppFont.tabularFigures,
    );

String _tempIncomeLabel(StatsRange range, int index, String label, int cents) {
  final amount = statsMoney(cents);
  return range == StatsRange.daily
      ? '${index + 1} 号 临时收入 +$amount'
      : '$label 临时收入 +$amount';
}

/// Chart 1 (A): 每日支出 - 额度对照 (bars + allowance baseline + temp income).
///
/// Month / year views draw paired expense / income bars instead of the day
/// bars; the allowance rule stays (month budget vs month spend, year budget vs
/// year spend).
class _SpendChartCard extends StatelessWidget {
  const _SpendChartCard({
    required this.range,
    required this.bars,
    required this.periodLabel,
  });

  final StatsRange range;
  final List<SpendBar> bars;
  final String periodLabel;

  bool get _paired => range != StatsRange.daily;

  String get _title => switch (range) {
    StatsRange.daily => '每日支出 \u00b7 额度对照',
    StatsRange.monthly => '每月支出 \u00b7 预算对照',
    StatsRange.yearly => '每年支出 \u00b7 预算对照',
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = _axisStyle(context);
    final hasBudget = bars.any((b) => b.allowanceCents != null);
    final flatAllowance = range == StatsRange.daily && bars.isNotEmpty
        ? bars.first.allowanceCents
        : null;
    final tempBars = [
      for (final b in bars)
        if (b.hasTempIncome) b,
    ];
    final hasRecords = bars.any(
      (b) => b.expenseCents > 0 || b.tempIncomeCents > 0,
    );

    return Card(
      key: const Key('stats_spend_chart'),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.m),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_title, style: theme.textTheme.titleLarge),
            const SizedBox(height: AppSpacing.xs),
            if (!hasBudget)
              Text(
                '先设置本月预算',
                key: const Key('stats_no_budget_hint'),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.inkSecondary,
                ),
              ),
            const SizedBox(height: AppSpacing.s),
            if (!hasRecords)
              SizedBox(
                height: 150,
                child: Center(
                  child: Text(
                    '这个周期还没有记录',
                    key: const Key('stats_spend_empty'),
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              )
            else
              SizedBox(
                height: 210,
                child: _barChart(context, style, flatAllowance),
              ),
            if (!_paired && tempBars.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.s),
              for (final b in tempBars)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Row(
                    key: Key('stats_temp_income_${b.index}'),
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: AppColors.semanticIncome,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Text(
                        _tempIncomeLabel(
                          range,
                          b.index,
                          b.label,
                          b.tempIncomeCents,
                        ),
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _barChart(BuildContext context, TextStyle? style, int? flatAllowance) {
    final scaleValues = <num>[
      for (final b in bars) b.expenseCents,
      if (_paired)
        for (final b in bars) b.tempIncomeCents,
      if (!_paired && flatAllowance != null && flatAllowance > 0) flatAllowance,
    ];
    final scale = ChartScale.resolve(scaleValues);
    final maxY = scale.maxY;
    final clamped = scale.clampedIndexes;
    final tempBars = [
      for (final b in bars)
        if (b.hasTempIncome) b,
    ];
    final allowanceScaleIndex =
        !_paired && flatAllowance != null && flatAllowance > 0
        ? bars.length
        : null;
    final clampedAllowance =
        allowanceScaleIndex != null && clamped.contains(allowanceScaleIndex);
    final drawnAllowance = flatAllowance == null
        ? null
        : math.min(flatAllowance.toDouble(), maxY);

    return LayoutBuilder(
      builder: (context, constraints) {
        final plot = _ChartPlot(
          width: constraints.maxWidth,
          height: constraints.maxHeight,
        );
        final clampedLabels = <Widget>[
          if (clampedAllowance && flatAllowance != null)
            _ClampBadge(
              key: const Key('stats_clamped_allowance'),
              text: '额度 ${statsMoney(flatAllowance)} \u2191',
            ),
          for (final b in bars)
            if (clamped.contains(b.index) && b.expenseCents > 0)
              _ClampBadge(
                key: Key('stats_clamped_expense_${b.index}'),
                text: '支出 ${statsMoney(b.expenseCents)} \u2191',
              ),
          if (_paired)
            for (final b in bars)
              if (clamped.contains(bars.length + b.index) &&
                  b.tempIncomeCents > 0)
                _ClampBadge(
                  key: Key('stats_clamped_temp_${b.index}'),
                  text: '临时收入 ${statsMoney(b.tempIncomeCents)} \u2191',
                ),
        ];

        return Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            Positioned.fill(
              child: BarChart(
                BarChartData(
                  minY: 0,
                  maxY: maxY,
                  alignment: BarChartAlignment.spaceAround,
                  gridData: const FlGridData(
                    show: true,
                    drawVerticalLine: false,
                  ),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    leftTitles: _leftAxis(maxY, style: style),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    bottomTitles: _bottomAxis(
                      [for (final b in bars) b.label],
                      step: _paired ? 2 : 5,
                      style: style,
                    ),
                  ),
                  extraLinesData: ExtraLinesData(
                    horizontalLines: [
                      if (drawnAllowance != null && drawnAllowance > 0)
                        HorizontalLine(
                          y: drawnAllowance,
                          color: AppColors.goldAccent,
                          strokeWidth: 1,
                          dashArray: const <int>[4, 3],
                        ),
                    ],
                  ),
                  barGroups: [
                    for (final b in bars)
                      BarChartGroupData(
                        x: b.index,
                        barsSpace: 2,
                        barRods: [
                          _expenseRod(b, maxY: maxY),
                          if (_paired) _incomeRod(b, maxY: maxY),
                        ],
                      ),
                  ],
                ),
              ),
            ),
            if (!_paired)
              for (final b in tempBars)
                Positioned(
                  left: plot.xForBar(b.index, bars.length) - 3.5,
                  top:
                      plot.yForValue(
                        math.min(b.expenseCents.toDouble(), maxY),
                        maxY,
                      ) -
                      3.5,
                  child: SizedBox(
                    key: Key('stats_temp_marker_${b.index}'),
                    width: 7,
                    height: 7,
                    child: const DecoratedBox(
                      decoration: BoxDecoration(
                        color: AppColors.semanticIncome,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
            if (clampedLabels.isNotEmpty)
              Positioned(
                left: plot.plotLeft,
                right: 4,
                top: 2,
                child: IgnorePointer(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 2,
                    children: clampedLabels,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  /// Expense rod: inside-allowance segment (elevated + hairline) + the part
  /// past the allowance (semanticExpense). Temporary income is an overlay
  /// marker (pixel-positioned), never a data-unit stack segment.
  BarChartRodData _expenseRod(SpendBar b, {required double maxY}) {
    final drawn = math.min(b.expenseCents.toDouble(), maxY);
    final allowance = b.allowanceCents?.toDouble();
    final drawnAllowance = allowance == null
        ? drawn
        : math.min(allowance, maxY);
    final base = math.min(drawn, drawnAllowance);
    final over = math.max(0.0, drawn - base);
    final items = <BarChartRodStackItem>[
      BarChartRodStackItem(
        0,
        base,
        AppColors.elevated,
        borderSide: const BorderSide(color: AppColors.hairline, width: 1),
      ),
      if (over > 0)
        BarChartRodStackItem(base, drawn, AppColors.semanticExpense),
    ];
    return BarChartRodData(
      toY: drawn,
      width: _paired ? 7 : 11,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(2)),
      rodStackItems: items,
    );
  }

  BarChartRodData _incomeRod(SpendBar b, {required double maxY}) {
    final drawn = math.min(b.tempIncomeCents.toDouble(), maxY);
    return BarChartRodData(
      toY: drawn,
      color: AppColors.semanticIncome,
      width: 7,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(2)),
    );
  }
}

/// Chart 2 (B): 收支趋势 (dual line).
///
/// The income line only plots amortised guaranteed income
/// (`baselineIncomeCents`); temporary income never enters the line or y-scale.
/// It is an overlay annotation: dashed leader + 3.5px dot + label.
class _TrendChart extends StatelessWidget {
  const _TrendChart({
    super.key,
    required this.points,
    required this.range,
    required this.hasBudget,
  });

  final List<PeriodPoint> points;
  final StatsRange range;
  final bool hasBudget;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = _axisStyle(context);
    final hasRecords = points.any(
      (p) =>
          p.expenseCents > 0 || p.incomeCents > 0 || p.baselineIncomeCents > 0,
    );
    if (points.isEmpty || !hasRecords) {
      return Card(
        child: SizedBox(
          height: 150,
          child: Center(
            child: Text(
              '这个周期还没有记录',
              key: const Key('stats_trend_empty'),
              style: theme.textTheme.bodySmall,
            ),
          ),
        ),
      );
    }

    final showIncomeLine =
        hasBudget && points.any((p) => p.baselineIncomeCents > 0);
    final scaleValues = <num>[
      for (final p in points) p.expenseCents,
      if (showIncomeLine)
        for (final p in points) p.baselineIncomeCents,
    ];
    final scale = ChartScale.resolve(scaleValues);
    final maxY = scale.maxY;
    final clamped = scale.clampedIndexes;
    final baselineOffset = points.length;
    final maxX = points.length <= 1 ? 1.0 : (points.length - 1).toDouble();

    final tempPoints = <({int index, int cents})>[
      for (var i = 0; i < points.length; i++)
        if (points[i].incomeCents > 0) (index: i, cents: points[i].incomeCents),
    ];

    final clampedBaselineValues = <int>{};
    final clampedExpenseValues = <int>{};
    for (var i = 0; i < points.length; i++) {
      if (clamped.contains(i)) {
        clampedExpenseValues.add(points[i].expenseCents);
      }
      if (showIncomeLine && clamped.contains(baselineOffset + i)) {
        clampedBaselineValues.add(points[i].baselineIncomeCents);
      }
    }
    final baselineLabels = clampedBaselineValues.toList()..sort();
    final expenseLabels = clampedExpenseValues.toList()..sort();
    final clampedLabels = <Widget>[
      for (final value in baselineLabels)
        _ClampBadge(
          key: Key('stats_clamped_baseline_$value'),
          text: '保底收入 ${statsMoney(value)} \u2191',
        ),
      for (final value in expenseLabels)
        _ClampBadge(
          key: Key('stats_clamped_expense_$value'),
          text: '支出 ${statsMoney(value)} \u2191',
        ),
    ];

    return Card(
      key: const Key('stats_trend_card'),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.m),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 210,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final plot = _ChartPlot(
                    width: constraints.maxWidth,
                    height: constraints.maxHeight,
                  );
                  return Stack(
                    clipBehavior: Clip.hardEdge,
                    children: [
                      Positioned.fill(
                        child: LineChart(
                          LineChartData(
                            minY: 0,
                            maxY: maxY,
                            minX: 0,
                            maxX: maxX,
                            gridData: const FlGridData(
                              show: true,
                              drawVerticalLine: false,
                            ),
                            borderData: FlBorderData(show: false),
                            titlesData: FlTitlesData(
                              leftTitles: _leftAxis(maxY, style: style),
                              topTitles: const AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                              rightTitles: const AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                              bottomTitles: _bottomAxis(
                                [for (final p in points) p.label],
                                step: range == StatsRange.daily
                                    ? 5
                                    : (range == StatsRange.monthly ? 2 : 1),
                                style: style,
                              ),
                            ),
                            lineBarsData: [
                              LineChartBarData(
                                spots: [
                                  for (var i = 0; i < points.length; i++)
                                    FlSpot(
                                      i.toDouble(),
                                      math.min(
                                        points[i].expenseCents.toDouble(),
                                        maxY,
                                      ),
                                    ),
                                ],
                                isCurved: true,
                                preventCurveOverShooting: true,
                                color: AppColors.semanticExpense,
                                barWidth: 2,
                                dotData: FlDotData(show: points.length < 14),
                              ),
                              if (showIncomeLine)
                                LineChartBarData(
                                  spots: [
                                    for (var i = 0; i < points.length; i++)
                                      FlSpot(
                                        i.toDouble(),
                                        math.min(
                                          points[i].baselineIncomeCents
                                              .toDouble(),
                                          maxY,
                                        ),
                                      ),
                                  ],
                                  isCurved: true,
                                  preventCurveOverShooting: true,
                                  color: AppColors.semanticIncome,
                                  barWidth: 2,
                                  dotData: FlDotData(show: points.length < 14),
                                ),
                            ],
                          ),
                        ),
                      ),
                      if (tempPoints.isNotEmpty)
                        Positioned.fill(
                          child: CustomPaint(
                            key: const Key('stats_trend_temp_leaders'),
                            painter: _TempIncomeLeaderPainter(
                              tempIndexes: [
                                for (final t in tempPoints) t.index,
                              ],
                              baselineValues: [
                                for (final p in points)
                                  showIncomeLine
                                      ? p.baselineIncomeCents.toDouble()
                                      : 0.0,
                              ],
                              maxY: maxY,
                              maxX: maxX,
                              plot: plot,
                            ),
                          ),
                        ),
                      for (final t in tempPoints)
                        Positioned(
                          left: plot.xForPoint(t.index.toDouble(), maxX) - 3.5,
                          top: 8.0 - 3.5,
                          child: SizedBox(
                            key: Key('stats_trend_temp_marker_${t.index}'),
                            width: 7,
                            height: 7,
                            child: const DecoratedBox(
                              decoration: BoxDecoration(
                                color: AppColors.semanticIncome,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                        ),
                      if (clampedLabels.isNotEmpty)
                        Positioned(
                          left: plot.plotLeft,
                          right: 4,
                          top: 2,
                          child: IgnorePointer(
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 2,
                              children: clampedLabels,
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
            if (!hasBudget) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                '未设本月预算；绿点/标注为临时收入',
                key: const Key('stats_no_budget_note'),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.inkSecondary,
                ),
              ),
            ],
            if (tempPoints.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.s),
              for (final t in tempPoints)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    _tempIncomeLabel(
                      range,
                      t.index,
                      points[t.index].label,
                      t.cents,
                    ),
                    style: theme.textTheme.bodySmall,
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Pixel-space geometry for the chart overlays.
///
/// It mirrors the axis reservations used by [_leftAxis] (58) and [_bottomAxis]
/// (22), then clamps every point back inside the plot. No visual size is ever
/// converted into a data unit here.
class _ChartPlot {
  _ChartPlot({required this.width, required this.height})
    : plotLeft = 58,
      plotTop = 0,
      plotWidth = math.max(0.0, width - 58),
      plotHeight = math.max(0.0, height - 22);

  final double width;
  final double height;
  final double plotLeft;
  final double plotTop;
  final double plotWidth;
  final double plotHeight;

  double xForBar(int index, int count) {
    if (count <= 0) return plotLeft;
    final groupWidth = plotWidth / count;
    return _clamp(
      plotLeft + groupWidth * (index + 0.5),
      plotLeft + 3.5,
      plotLeft + plotWidth - 3.5,
    );
  }

  double xForPoint(double index, double maxX) {
    final span = maxX <= 0 ? 1.0 : maxX;
    return _clamp(
      plotLeft + (index / span) * plotWidth,
      plotLeft + 3.5,
      plotLeft + plotWidth - 3.5,
    );
  }

  double yForValue(double value, double maxY, {double minY = 11.5}) {
    if (maxY <= 0) return plotHeight;
    final raw = plotHeight - (value / maxY) * plotHeight;
    return _clamp(raw, minY, plotHeight - 3.5);
  }

  static double _clamp(double value, double min, double max) {
    if (value < min) return min;
    if (value > max) return max;
    return value;
  }
}

/// Small top-of-chart annotation for a clamped element, for example
/// `额度 250 `.
class _ClampBadge extends StatelessWidget {
  const _ClampBadge({required this.text, super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.bodySmall
          ?.copyWith(color: AppColors.inkSecondary, fontSize: 10),
    );
  }
}

/// Draws the dashed vertical leader for chart-2 temporary income annotations.
class _TempIncomeLeaderPainter extends CustomPainter {
  _TempIncomeLeaderPainter({
    required this.tempIndexes,
    required this.baselineValues,
    required this.maxY,
    required this.maxX,
    required this.plot,
  });

  final List<int> tempIndexes;
  final List<double> baselineValues;
  final double maxY;
  final double maxX;
  final _ChartPlot plot;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.semanticIncome
      ..strokeWidth = 1;
    for (final index in tempIndexes) {
      final x = plot.xForPoint(index.toDouble(), maxX);
      final startY = plot.yForValue(baselineValues[index], maxY, minY: 8.0);
      _drawDashedVerticalLine(canvas, x, startY, 8.0, paint);
    }
  }

  void _drawDashedVerticalLine(
    Canvas canvas,
    double x,
    double fromY,
    double toY,
    Paint paint,
  ) {
    const dash = 4.0;
    const gap = 3.0;
    final total = (toY - fromY).abs();
    if (total <= 0) return;
    final direction = toY >= fromY ? 1.0 : -1.0;
    var travelled = 0.0;
    while (travelled < total) {
      final start = fromY + direction * travelled;
      final end = fromY + direction * math.min(travelled + dash, total);
      canvas.drawLine(Offset(x, start), Offset(x, end), paint);
      travelled += dash + gap;
    }
  }

  @override
  bool shouldRepaint(covariant _TempIncomeLeaderPainter oldDelegate) {
    return oldDelegate.tempIndexes != tempIndexes ||
        oldDelegate.baselineValues != baselineValues ||
        oldDelegate.maxY != maxY ||
        oldDelegate.maxX != maxX ||
        oldDelegate.plot != plot;
  }
}

/// Category pie card with legend.
class _CategoryPieCard extends ConsumerWidget {
  const _CategoryPieCard({
    required this.transactions,
    required this.categoryRepo,
  });

  final List<Transaction> transactions;
  final CategoryRepository categoryRepo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final totals = StatisticsService.expenseByCategory(transactions);
    if (totals.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.l),
          child: Center(child: Text('暂无支出数据')),
        ),
      );
    }
    final grand = totals.fold<int>(0, (sum, t) => sum + t.cents);
    // Single shared slicing function (home donut uses the same one, capped at
    // 3 named slices there); this page keeps every category.
    final slices = StatisticsService.chartSlices(
      totals,
      maxNamed: totals.length,
    );

    return FutureBuilder<List<Category>>(
      future: categoryRepo.watchAll().first,
      builder: (context, snapshot) {
        final categories = snapshot.data ?? const <Category>[];
        String name(String? id) {
          for (final c in categories) {
            if (c.id == id) return c.name;
          }
          return '未分类';
        }

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.m),
            child: Column(
              children: [
                SizedBox(
                  height: 200,
                  child: PieChart(
                    PieChartData(
                      sections: [
                        for (final slice in slices)
                          PieChartSectionData(
                            value: slice.cents.toDouble(),
                            title: '${(slice.cents * 100 ~/ grand)}%',
                            titleStyle: TextStyle(
                              fontSize: 11,
                              color: AppColors.chartSliceLabel(
                                slice.colorIndex,
                              ),
                            ),
                            color: AppColors.chartSliceColor(slice.colorIndex),
                            radius: 70,
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.m),
                Wrap(
                  spacing: AppSpacing.m,
                  runSpacing: AppSpacing.xs,
                  children: [
                    for (final slice in slices)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            color: AppColors.chartSliceColor(slice.colorIndex),
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          Text(
                            '${name(slice.categoryId)} ¥${slice.cents ~/ 100}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Month button of the statistics top bar (same visual language and sheet as
/// the analysis page, own keys so tests can tell the two apart).
class _StatsMonthButton extends StatelessWidget {
  const _StatsMonthButton({required this.month, required this.onTap});

  final DateTime month;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      height: 40,
      child: OutlinedButton(
        key: const Key('stats_month_button'),
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          backgroundColor: AppColors.elevated,
          foregroundColor: AppColors.ink,
          side: const BorderSide(color: AppColors.hairline),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.m),
          minimumSize: const Size(0, 40),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.m),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${month.year} 年 ${month.month} 月',
              style: theme.textTheme.bodyLarge?.copyWith(
                fontFamily: AppFont.uiFamily,
                fontFeatures: AppFont.tabularFigures,
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            const Icon(
              Icons.arrow_drop_down,
              size: 18,
              color: AppColors.inkSecondary,
            ),
          ],
        ),
      ),
    );
  }
}
