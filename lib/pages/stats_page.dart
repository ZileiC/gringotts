import 'dart:io';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/app.dart';
import '../data/app_database.dart';
import '../data/repositories/repositories.dart';
import '../services/export_service.dart';
import '../services/statistics_service.dart';
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

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }
  CategoryRepository get _categoryRepo =>
      ref.read(categoryRepositoryProvider);

  List<PeriodPoint> _trend(List<Transaction> transactions) {
    switch (_range) {
      case StatsRange.daily:
        return StatisticsService.dailyTrend(transactions);
      case StatsRange.monthly:
        return StatisticsService.monthlyTrend(transactions);
      case StatsRange.yearly:
        return StatisticsService.yearlyTrend(transactions);
    }
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
    final home = Platform.environment['USERPROFILE'] ?? Platform.environment['HOME'] ?? '.';
    return '$home${Platform.pathSeparator}Documents';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('统计')),
      body: StreamBuilder<List<Transaction>>(
        stream: _txRepo.watchAll(),
        builder: (context, snapshot) {
          final transactions = snapshot.data ?? const <Transaction>[];
          final trend = _trend(transactions);
          final totals = StatisticsService.totals(transactions);

          return ListView(
            controller: _scroll,
            physics: const InertialScrollPhysics(),
            padding: const EdgeInsets.all(AppSpacing.m),
            children: [
              // Range switch.
              SegmentedButton<StatsRange>(
                segments: const [
                  ButtonSegment(value: StatsRange.daily, label: Text('日')),
                  ButtonSegment(value: StatsRange.monthly, label: Text('月')),
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
                      Text('净结余（收入 − 支出）',
                          style: Theme.of(context).textTheme.bodySmall),
                      const SizedBox(height: AppSpacing.xs),
                      CountUpNumber(
                        valueCents: totals.netCents,
                        builder: (context, cents) => Text(
                          _yuan(cents),
                          style: Theme.of(context)
                              .textTheme
                              .displayLarge
                              ?.copyWith(fontSize: AppFont.display - 12),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.s),
                      Text(
                        '收入 ${_yuan(totals.incomeCents)} · 支出 ${_yuan(totals.expenseCents)}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
              ),
              const SizedBox(height: AppSpacing.l),
              // Trend dual-line chart.
              Text('趋势（支出/收入双线）',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: AppSpacing.s),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.m),
                  child: SizedBox(
                    height: 220,
                    child: _TrendChart(points: trend),
                  ),
                ),
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
              FilledButton.tonalIcon(
                onPressed: _export,
                icon: const Icon(Icons.file_download),
                label: const Text('导出 CSV / JSON（带 BOM）'),
              ),
            ],
          );
        },
      ),
    );
  }

  static String _yuan(int cents) {
    final display = cents % 100 == 0
        ? (cents ~/ 100).toString()
        : (cents / 100).toStringAsFixed(2);
    return '¥$display';
  }
}

/// Dual-line chart: expense + income per period.
class _TrendChart extends StatelessWidget {
  const _TrendChart({required this.points});

  final List<PeriodPoint> points;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return const Center(child: Text('暂无数据'));
    }
    final maxY = points
        .expand((p) => [p.expenseCents, p.incomeCents])
        .reduce((a, b) => a > b ? a : b);
    final chartMax = maxY <= 0 ? 100.0 : maxY.toDouble();

    return LineChart(
      LineChartData(
        minY: 0,
        maxY: chartMax * 1.1,
        gridData: const FlGridData(show: true),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: (points.length / 6).clamp(1, double.infinity).toDouble(),
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= points.length) {
                  return const SizedBox.shrink();
                }
                return Text(
                  points[index].label,
                  style: Theme.of(context).textTheme.bodySmall,
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: [
              for (var i = 0; i < points.length; i++)
                FlSpot(i.toDouble(), points[i].expenseCents.toDouble()),
            ],
            isCurved: true,
            color: AppColors.semanticExpense,
            barWidth: 2,
            dotData: const FlDotData(show: false),
          ),
          LineChartBarData(
            spots: [
              for (var i = 0; i < points.length; i++)
                FlSpot(i.toDouble(), points[i].incomeCents.toDouble()),
            ],
            isCurved: true,
            color: AppColors.semanticIncome,
            barWidth: 2,
            dotData: const FlDotData(show: false),
          ),
        ],
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (spots) => spots
                .map((s) => LineTooltipItem(
                      '${points[s.x.toInt()].label}\n'
                      '${s.barIndex == 0 ? '支出' : '收入'} ¥${(s.y ~/ 100)}',
                      Theme.of(context).textTheme.bodySmall!,
                    ))
                .toList(),
          ),
        ),
      ),
    );
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
    final slices = StatisticsService.chartSlices(totals, maxNamed: totals.length);

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
                              color: AppColors.chartSliceLabel(slice.colorIndex),
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
