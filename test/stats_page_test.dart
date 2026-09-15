import 'package:drift/native.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gringotts/app/app.dart';
import 'package:gringotts/data/app_database.dart';
import 'package:gringotts/data/repositories/budget_repository.dart';
import 'package:gringotts/data/repositories/repositories.dart';
import 'package:gringotts/domain/models.dart';
import 'package:gringotts/pages/home_page.dart';
import 'package:gringotts/pages/stats_page.dart';
import 'package:gringotts/services/budget_engine.dart';
import 'package:gringotts/services/chart_scale.dart';
import 'package:gringotts/ui/tokens.dart';

/// T-14 spec alignment on the statistics page (DESIGN_T09 section 8.5):
/// - the net balance is semanticExpense when negative and warm ink at zero or
///   above;
/// - the export action is a hairline gold outline key (gold as border and
///   label, never as a large fill - DESIGN_MAIN section 7).
void main() {
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    final migrator = db.createMigrator();
    await migrator.createAll();
    await db.migration.onCreate(migrator);
  });

  tearDown(() async => db.close());

  /// drift's StreamQueryStore schedules a 0ms close timer when the last stream
  /// is cancelled; flutter_test disposes the tree after the body with a bare
  /// pump() (no elapse), which would leave it pending.
  Future<void> disposeTree(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  }

  Future<void> pumpStats(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(theme: buildAppTheme(), home: const StatsPage()),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// The stats body is a lazy ListView: the trend card sits below the fold in
  /// the test viewport, so it must be scrolled into range before inspecting it.
  Future<void> revealTrend(WidgetTester tester) async {
    await tester.scrollUntilVisible(
      find.byKey(const Key('stats_trend_card')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
  }

  Future<void> seed({int incomeCents = 0, int expenseCents = 0}) async {
    final repo = TransactionRepository(db);
    final now = DateTime.now();
    if (incomeCents > 0) {
      await repo.create(
        amountCents: incomeCents,
        type: TransactionType.income,
        occurredAt: now,
      );
    }
    if (expenseCents > 0) {
      await repo.create(
        amountCents: expenseCents,
        type: TransactionType.expense,
        occurredAt: now,
      );
    }
  }

  /// The net-balance number: colour + rendered text (after the spring lands).
  Text netValue(WidgetTester tester) => tester.widget<Text>(
    find.descendant(
      of: find.byKey(const Key('stats_net_value')),
      matching: find.byType(Text),
    ),
  );

  testWidgets(
    'net balance: negative is semanticExpense, zero and positive ink',
    (tester) async {
      // Zero: no data at all.
      await pumpStats(tester);
      expect(netValue(tester).data, '¥0');
      expect(
        netValue(tester).style?.color,
        AppColors.ink,
        reason: 'zero balance is not a loss',
      );
      await disposeTree(tester);

      // Positive: income above expense.
      await seed(incomeCents: 500000, expenseCents: 200000);
      await pumpStats(tester);
      expect(netValue(tester).data, '¥3000');
      expect(
        netValue(tester).style?.color,
        AppColors.ink,
        reason: 'a positive balance stays warm ink',
      );
      await disposeTree(tester);

      // Negative: expense above income (DESIGN_T09 section 8.5).
      await seed(expenseCents: 900000);
      await pumpStats(tester);
      expect(netValue(tester).data, '¥-6000');
      expect(
        netValue(tester).style?.color,
        AppColors.semanticExpense,
        reason: 'a negative balance is semanticExpense',
      );
      expect(netValue(tester).style?.color, isNot(AppColors.ink));
      await disposeTree(tester);
    },
  );

  testWidgets('export is a hairline gold outline key, not a filled pill', (
    tester,
  ) async {
    await pumpStats(tester);

    // The stats body is a lazy ListView: the export key sits below the trend
    // and pie cards, so scroll it into range before inspecting it.
    final exportKey = find.byKey(const Key('stats_export_button'));
    await tester.scrollUntilVisible(
      exportKey,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    final button = tester.widget<OutlinedButton>(exportKey);
    final side = button.style?.side?.resolve(<WidgetState>{});
    expect(side?.color, AppColors.goldAccent, reason: 'gold hairline border');
    expect(side?.width, 1.0, reason: 'hairline, not a heavy stroke');
    expect(
      button.style?.foregroundColor?.resolve(<WidgetState>{}),
      AppColors.goldAccent,
      reason: 'the label and icon are gold on the dark canvas',
    );
    expect(
      button.style?.backgroundColor?.resolve(<WidgetState>{}),
      isNull,
      reason: 'no large gold fill: the charter allows gold as border/text',
    );
    // The old shape was a filled tonal pill.
    expect(find.byType(FilledButton), findsNothing);
    expect(find.text('导出 CSV / JSON（带 BOM）'), findsOneWidget);

    await disposeTree(tester);
  });

  group('T-21 charts (structured, no pixels)', () {
    BarChart barChart(WidgetTester tester) => tester.widget<BarChart>(
      find.descendant(
        of: find.byKey(const Key('stats_spend_chart')),
        matching: find.byType(BarChart),
      ),
    );

    testWidgets('day view: one bar per day of the selected month, x = index, '
        'money axis on, integer bottom interval', (tester) async {
      await seed(expenseCents: 1500);
      await pumpStats(tester);
      final chart = barChart(tester);
      final now = DateTime.now();
      final days = BudgetEngine.daysInMonth(now.year, now.month);
      expect(
        chart.data.barGroups.length,
        days,
        reason: 'T-21 acceptance 1: bar count = selected month length',
      );
      for (var i = 0; i < chart.data.barGroups.length; i++) {
        expect(
          chart.data.barGroups[i].x,
          i,
          reason: 'bar x must be the integer data-point index',
        );
      }
      final left = chart.data.titlesData.leftTitles.sideTitles;
      expect(
        left.showTitles,
        isTrue,
        reason: 'T-21 acceptance 2: the left axis carries money ticks',
      );
      expect(
        left.interval,
        closeTo(chart.data.maxY / 3, 0.0001),
        reason: '4 ticks: 0 / 1/3 / 2/3 / max',
      );
      expect(
        chart.data.titlesData.bottomTitles.sideTitles.interval,
        1,
        reason: 'T-21 diagnosis 2: never length / 6',
      );
      await disposeTree(tester);
    });

    testWidgets('no budget: guidance line, no allowance line, no red segment', (
      tester,
    ) async {
      await seed(expenseCents: 1500);
      await pumpStats(tester);
      expect(find.byKey(const Key('stats_no_budget_hint')), findsOneWidget);
      expect(find.text('先设置本月预算'), findsOneWidget);
      final chart = barChart(tester);
      expect(
        chart.data.extraLinesData.horizontalLines,
        isEmpty,
        reason: 'without a budget nothing may be drawn as an allowance',
      );
      final rod = chart.data.barGroups
          .expand((g) => g.barRods)
          .firstWhere((r) => r.rodStackItems.isNotEmpty);
      expect(
        rod.rodStackItems.any((i) => i.color == AppColors.semanticExpense),
        isFalse,
        reason: 'no allowance means no over-limit segment',
      );
      await disposeTree(tester);
    });

    testWidgets(
      'budget + temp income: allowance dashed line + clamped top marker',
      (tester) async {
        final now = DateTime.now();
        final day = now.day;
        final days = BudgetEngine.daysInMonth(now.year, now.month);
        final repo = BudgetRepository(db);
        await repo.upsert(
          yearMonth: BudgetEngine.monthKey(now),
          incomeCents: 300000,
          savingsTargetCents: 0,
        );
        await seed(expenseCents: 1500);
        final txRepo = TransactionRepository(db);
        await txRepo.create(
          amountCents: 80000,
          type: TransactionType.income,
          occurredAt: now,
        );
        await pumpStats(tester);

        final chart = barChart(tester);
        final allowance = BudgetEngine.fixedDailyCents(
          budgetCents: 300000,
          daysInMonth: days,
        );
        // 10000 allowance vs 1500 expense: invariant 3 clamps the allowance.
        final chartMax = 1500 * 1.25;
        final lines = chart.data.extraLinesData.horizontalLines;
        expect(
          lines.length,
          1,
          reason: 'T-24: allowance baseline remains drawn',
        );
        expect(
          lines.first.y,
          closeTo(chartMax, 0.001),
          reason: 'clamped allowance line sits on maxY',
        );
        expect(lines.first.color, AppColors.goldAccent);
        expect(lines.first.dashArray, const <int>[4, 3]);
        expect(find.text('额度 ${statsMoney(allowance)} \u2191'), findsOneWidget);
        expect(chart.data.maxY, closeTo(chartMax, 0.001));

        // The temporary income marker is a pixel overlay, not a stack segment.
        final rod = chart.data.barGroups[day - 1].barRods.first;
        expect(
          rod.rodStackItems.any((i) => i.color == AppColors.semanticIncome),
          isFalse,
          reason: 'T-24: temp income never enters the bar data stack',
        );
        expect(find.byKey(Key('stats_temp_marker_${day - 1}')), findsOneWidget);
        expect(
          find.byKey(Key('stats_temp_income_${day - 1}')),
          findsOneWidget,
          reason: 'the numeric label stays next to the chart',
        );
        expect(find.text('$day 号 临时收入 +\u00a5800'), findsOneWidget);
        await disposeTree(tester);
      },
    );

    testWidgets('empty period shows the empty state, not an empty chart', (
      tester,
    ) async {
      await pumpStats(tester);
      expect(find.byKey(const Key('stats_spend_empty')), findsOneWidget);
      expect(find.text('这个周期还没有记录'), findsWidgets);
      await disposeTree(tester);
    });

    testWidgets(
      'chart 2: the income line carries only the amortised baseline',
      (tester) async {
        final now = DateTime.now();
        final days = BudgetEngine.daysInMonth(now.year, now.month);
        await BudgetRepository(db).upsert(
          yearMonth: BudgetEngine.monthKey(now),
          incomeCents: 300000,
          savingsTargetCents: 0,
        );
        await seed(expenseCents: 1500);
        await pumpStats(tester);
        await revealTrend(tester);

        final chart = tester.widget<LineChart>(
          find.descendant(
            of: find.byKey(const Key('stats_trend_card')),
            matching: find.byType(LineChart),
          ),
        );
        final baseline = 300000 ~/ days;
        final incomeLine = chart.data.lineBarsData.firstWhere(
          (b) => b.color == AppColors.semanticIncome,
        );
        // 10000 baseline vs 1500 expense: invariant 3 clamps the baseline line.
        final chartMax = 1500 * 1.25;
        expect(chart.data.maxY, closeTo(chartMax, 0.001));
        expect(
          incomeLine.spots.every((s) => s.y == chartMax),
          isTrue,
          reason: 'the amortised baseline is clamped to the plot top',
        );
        expect(
          find.text('保底收入 ${statsMoney(baseline)} \u2191'),
          findsOneWidget,
        );
        await disposeTree(tester);
      },
    );

    testWidgets('chart 2: temp income is a pixel annotation, not scaled in', (
      tester,
    ) async {
      final now = DateTime.now();
      final day = now.day;
      await BudgetRepository(db).upsert(
        yearMonth: BudgetEngine.monthKey(now),
        incomeCents: 300000,
        savingsTargetCents: 0,
      );
      await seed(expenseCents: 1500);
      await TransactionRepository(db).create(
        amountCents: 80000,
        type: TransactionType.income,
        occurredAt: now,
      );
      await pumpStats(tester);
      await revealTrend(tester);

      final chart = tester.widget<LineChart>(
        find.descendant(
          of: find.byKey(const Key('stats_trend_card')),
          matching: find.byType(LineChart),
        ),
      );
      final chartMax = 1500 * 1.25;
      expect(
        chart.data.maxY,
        closeTo(chartMax, 0.001),
        reason: 'the 80000 spike must not enter the y scale',
      );
      final incomeLine = chart.data.lineBarsData.firstWhere(
        (b) => b.color == AppColors.semanticIncome,
      );
      expect(
        incomeLine.spots[day - 1].y,
        chartMax,
        reason: 'income line is baseline only and clamped',
      );
      expect(
        chart.data.lineBarsData.any((b) => b.dashArray != null),
        isFalse,
        reason: 'leaders are drawn in the pixel overlay, not as line data',
      );
      expect(find.byKey(const Key('stats_trend_temp_leaders')), findsOneWidget);
      expect(
        find.byKey(Key('stats_trend_temp_marker_${day - 1}')),
        findsOneWidget,
        reason: 'the 3.5px endpoint dot is a positioned overlay',
      );
      expect(find.text('$day 号 临时收入 +\u00a5800'), findsWidgets);
      await disposeTree(tester);
    });

    testWidgets('chart 2: no budget -> explanatory note under the chart', (
      tester,
    ) async {
      await seed(expenseCents: 1500);
      await pumpStats(tester);
      await revealTrend(tester);
      expect(find.byKey(const Key('stats_no_budget_note')), findsOneWidget);
      expect(find.text('未设本月预算；绿点/标注为临时收入'), findsOneWidget);
      final chart = tester.widget<LineChart>(
        find.descendant(
          of: find.byKey(const Key('stats_trend_card')),
          matching: find.byType(LineChart),
        ),
      );
      expect(
        chart.data.lineBarsData.any((b) => b.color == AppColors.semanticIncome),
        isFalse,
        reason: 'DESIGN_MAIN 11.3: no budget -> no income line',
      );
      await disposeTree(tester);
    });

    testWidgets('yearly view with a single year renders both charts', (
      tester,
    ) async {
      await seed(expenseCents: 1500);
      await pumpStats(tester);
      await tester.tap(find.text('年'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('stats_spend_chart')), findsOneWidget);
      await revealTrend(tester);
      expect(find.byKey(const Key('stats_trend_card')), findsOneWidget);
      await disposeTree(tester);
    });

    testWidgets(
      'month button drives the shared month (analysis / ledger / stats)',
      (tester) async {
        final now = DateTime.now();
        final prev = DateTime(now.year, now.month - 1, 1);
        await TransactionRepository(db).create(
          amountCents: 6000,
          type: TransactionType.expense,
          occurredAt: DateTime(prev.year, prev.month, 12),
        );
        final container = ProviderContainer(
          overrides: [databaseProvider.overrideWithValue(db)],
        );
        addTearDown(container.dispose);
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(theme: buildAppTheme(), home: const StatsPage()),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          container.read(selectedMonthProvider),
          DateTime(now.year, now.month, 1),
        );

        await tester.tap(find.byKey(const Key('stats_month_button')));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('stats_month_sheet')),
          findsOneWidget,
          reason: 'the stats page reuses the home calendar sheet component',
        );
        if (prev.year != now.year) {
          await tester.tap(find.byKey(const Key('month_sheet_year_prev')));
          await tester.pumpAndSettle();
        }
        await tester.tap(find.byKey(Key('month_sheet_cell_${prev.month}')));
        await tester.pumpAndSettle();

        expect(
          container.read(selectedMonthProvider),
          DateTime(prev.year, prev.month, 1),
          reason: 'T-21 acceptance 4: one shared selected month',
        );
        // The chart now buckets the previous month, not the current one.
        final chart = barChart(tester);
        expect(
          chart.data.barGroups.length,
          BudgetEngine.daysInMonth(prev.year, prev.month),
        );

        // The analysis page reads the same state.
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(theme: buildAppTheme(), home: const HomePage()),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.text('${prev.year} 年 ${prev.month} 月'),
          findsWidgets,
          reason: 'the analysis month button follows the shared state',
        );
        await disposeTree(tester);
      },
    );
  });

  group('T-24 chart scale and clamp invariants', () {
    BarChart barChart(WidgetTester tester) => tester.widget<BarChart>(
      find.descendant(
        of: find.byKey(const Key('stats_spend_chart')),
        matching: find.byType(BarChart),
      ),
    );

    testWidgets(
      'user scenario: allowance/baseline clamp, temp is annotation only',
      (tester) async {
        const incomeCents = 750000;
        const expenseCents = 6750;
        const tempIncomeCents = 10000;
        final september = DateTime(2026, 9, 1);
        await BudgetRepository(db).upsert(
          yearMonth: '2026-09',
          incomeCents: incomeCents,
          savingsTargetCents: 0,
        );
        await TransactionRepository(db).create(
          amountCents: expenseCents,
          type: TransactionType.expense,
          occurredAt: DateTime(2026, 9, 15),
        );
        await TransactionRepository(db).create(
          amountCents: tempIncomeCents,
          type: TransactionType.income,
          occurredAt: DateTime(2026, 9, 15),
        );

        final container = ProviderContainer(
          overrides: [databaseProvider.overrideWithValue(db)],
        );
        addTearDown(container.dispose);
        container.read(selectedMonthProvider.notifier).select(september);
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(theme: buildAppTheme(), home: const StatsPage()),
          ),
        );
        await tester.pumpAndSettle();

        final days = BudgetEngine.daysInMonth(2026, 9);
        final allowance = BudgetEngine.fixedDailyCents(
          budgetCents: incomeCents,
          daysInMonth: days,
        );
        expect(allowance, 25000);
        final chartMax = expenseCents * 1.25;

        final spendChart = barChart(tester);
        expect(spendChart.data.maxY, closeTo(chartMax, 0.001));
        expect(
          spendChart.data.extraLinesData.horizontalLines.single.y,
          closeTo(chartMax, 0.001),
        );
        expect(find.text('额度 ${statsMoney(allowance)} \u2191'), findsOneWidget);
        expect(find.byKey(const Key('stats_temp_marker_14')), findsOneWidget);
        expect(find.byKey(const Key('stats_temp_income_14')), findsOneWidget);
        expect(find.text('15 号 临时收入 +\u00a5100'), findsWidgets);
        expect(
          spendChart.data.barGroups
              .expand((g) => g.barRods)
              .expand((r) => r.rodStackItems)
              .any((i) => i.color == AppColors.semanticIncome),
          isFalse,
          reason: 'temp income never enters the bar stack',
        );
        for (final group in spendChart.data.barGroups) {
          for (final rod in group.barRods) {
            expect(rod.toY, lessThanOrEqualTo(chartMax + 1e-9));
            for (final item in rod.rodStackItems) {
              expect(item.toY, lessThanOrEqualTo(chartMax + 1e-9));
            }
          }
        }
        for (final line in spendChart.data.extraLinesData.horizontalLines) {
          expect(line.y, lessThanOrEqualTo(chartMax + 1e-9));
        }

        // Direct pure-function probe for the chart-1 values: allowance is v1,
        // expense is v2, so the allowance index is in the clamp set.
        final scale = ChartScale.resolve(<num>[expenseCents, allowance]);
        expect(scale.maxY, closeTo(chartMax, 0.001));
        expect(scale.clampedIndexes, <int>{1});

        await tester.scrollUntilVisible(
          find.byKey(const Key('stats_trend_card')),
          300,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        final trendChart = tester.widget<LineChart>(
          find.descendant(
            of: find.byKey(const Key('stats_trend_card')),
            matching: find.byType(LineChart),
          ),
        );
        final baseline = incomeCents ~/ days;
        expect(trendChart.data.maxY, closeTo(chartMax, 0.001));
        final incomeLine = trendChart.data.lineBarsData.firstWhere(
          (b) => b.color == AppColors.semanticIncome,
        );
        expect(
          incomeLine.spots.every((s) => s.y == chartMax),
          isTrue,
          reason: 'baseline 25000 > maxY, so every income spot is clamped',
        );
        for (final bar in trendChart.data.lineBarsData) {
          for (final spot in bar.spots) {
            expect(spot.y, lessThanOrEqualTo(chartMax + 1e-9));
          }
        }
        expect(
          find.text('保底收入 ${statsMoney(baseline)} \u2191'),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('stats_trend_temp_marker_14')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('stats_trend_temp_leaders')),
          findsOneWidget,
        );
        expect(find.text('15 号 临时收入 +\u00a5100'), findsWidgets);

        await disposeTree(tester);
      },
    );
  });
  group('T-23 net balance card', () {
    testWidgets('label and number share the DESIGN_MAIN 11.7 definition', (
      tester,
    ) async {
      final now = DateTime.now();
      await BudgetRepository(db).upsert(
        yearMonth: BudgetEngine.monthKey(now),
        incomeCents: 600000,
        savingsTargetCents: 0,
      );
      await seed(incomeCents: 80000, expenseCents: 314500);
      await pumpStats(tester);

      expect(find.byKey(const Key('stats_net_label')), findsOneWidget);
      expect(find.text('净结余（保底 + 临时 \u2212 支出）'), findsOneWidget);
      // 6000 + 800 - 3145 = 3655 (the number frozen by T-23).
      expect(netValue(tester).data, '\u00a53655');
      expect(
        netValue(tester).style?.color,
        AppColors.ink,
        reason: 'a positive balance stays warm ink',
      );
      expect(find.textContaining('保底收入 \u00a56000'), findsOneWidget);
      expect(find.textContaining('临时收入 \u00a5800'), findsOneWidget);
      expect(find.textContaining('支出 \u00a53145'), findsOneWidget);
      expect(
        find.textContaining('可花预算 \u00a56000'),
        findsOneWidget,
        reason: '可花预算 = 保底 - 计划存款 = 6000 (nothing planned)',
      );
      await disposeTree(tester);
    });

    testWidgets('negative balance stays semanticExpense under the new scope', (
      tester,
    ) async {
      final now = DateTime.now();
      await BudgetRepository(db).upsert(
        yearMonth: BudgetEngine.monthKey(now),
        incomeCents: 600000,
        savingsTargetCents: 0,
      );
      // 6000 - 9000 = -3000
      await seed(expenseCents: 900000);
      await pumpStats(tester);
      expect(find.byKey(const Key('stats_net_label')), findsOneWidget);
      expect(netValue(tester).data, '\u00a5-3000');
      expect(netValue(tester).style?.color, AppColors.semanticExpense);
      await disposeTree(tester);
    });

    testWidgets('day view: \u4fdd\u5e95\u6536\u5165 on a 31-day month equals the budget income exactly '
        '(the card no longer contradicts itself)', (tester) async {
      // 2026-10 has 31 days and 600000 is not divisible by 31. Stamping the
      // floored 19354 per day summed to 599974, so the card read \u4fdd\u5e95\u6536\u5165
      // \u00a55,999.74 next to \u53ef\u82b1\u9884\u7b97 \u00a56,000. The distributed per-day baselines
      // must sum back to the budget income.
      final october = DateTime(2026, 10, 1);
      await BudgetRepository(db).upsert(
        yearMonth: '2026-10',
        incomeCents: 600000,
        savingsTargetCents: 0,
      );
      final repo = TransactionRepository(db);
      await repo.create(
        amountCents: 80000,
        type: TransactionType.income,
        occurredAt: DateTime(2026, 10, 12),
      );
      await repo.create(
        amountCents: 314500,
        type: TransactionType.expense,
        occurredAt: DateTime(2026, 10, 3),
      );
      final container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(db)],
      );
      addTearDown(container.dispose);
      container.read(selectedMonthProvider.notifier).select(october);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(theme: buildAppTheme(), home: const StatsPage()),
        ),
      );
      await tester.pumpAndSettle();

      // \u4fdd\u5e95\u6536\u5165 = the budget income exactly; before the fix this was 5999.74.
      expect(
        find.textContaining('\u4fdd\u5e95\u6536\u5165 \u00a56000'),
        findsOneWidget,
      );
      // \u53ef\u82b1\u9884\u7b97 = \u4fdd\u5e95\u6536\u5165 - \u8ba1\u5212\u5b58\u6b3e = the same 600000: the two rows agree.
      expect(
        find.textContaining('\u53ef\u82b1\u9884\u7b97 \u00a56000'),
        findsOneWidget,
        reason: '\u53ef\u82b1\u9884\u7b97 basis equals the \u4fdd\u5e95\u6536\u5165 row',
      );
      // 6000 + 800 - 3145 = 3655 (the frozen T-23 number).
      expect(netValue(tester).data, '\u00a53655');
      await disposeTree(tester);
    });
  });
}
