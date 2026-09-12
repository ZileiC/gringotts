import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/app.dart';
import '../data/app_database.dart';
import '../data/repositories/budget_repository.dart';
import '../domain/models.dart';
import '../services/budget_engine.dart';
import '../services/statistics_service.dart';
import '../ui/motion.dart';
import '../ui/tokens.dart';

/// Home = analysis / guidance page (M2.0 pre-wave, DESIGN_MAIN §3).
///
/// One of the three peer tabs hosted by [HomeShell]. It answers "how much can
/// I still spend today" from the monthly budget and the confirmed expense
/// records, and hosts the AI slot (placeholder until M2.0). The month title is
/// a button that opens the calendar sheet (T-12c Part D).
class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  late DateTime _month; // First day of the displayed month.
  final ScrollController _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month, 1);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  bool get _isCurrentMonth {
    final now = DateTime.now();
    return _month.year == now.year && _month.month == now.month;
  }

  Future<void> _openBudgetSheet(BudgetMonth? current) async {
    if (!_isCurrentMonth) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('历史月份只读，仅可查看'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _BudgetSheet(month: _month, current: current),
    );
  }

  /// Opens the month calendar sheet; selecting a month switches the page data.
  Future<void> _openMonthSheet() async {
    final today = DateTime.now();
    void select(DateTime month) => setState(() => _month = month);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    if (!reduceMotion) {
      await showModalBottomSheet<void>(
        context: context,
        builder: (_) => _MonthSheet(
          selected: _month,
          today: today,
          onSelected: select,
        ),
      );
      return;
    }
    // reduce-motion: a fade replaces the sheet's vertical displacement
    // (DESIGN_MAIN §3.1).
    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: '月份选择',
      barrierColor: AppColors.canvas.withValues(alpha: 0.6),
      transitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (_, _, _) => Align(
        alignment: Alignment.bottomCenter,
        child: Material(
          color: Colors.transparent,
          child: _MonthSheet(
            selected: _month,
            today: today,
            onSelected: select,
          ),
        ),
      ),
      transitionBuilder: (_, animation, _, child) =>
          FadeTransition(opacity: animation, child: child),
    );
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final days = BudgetEngine.daysInMonth(_month.year, _month.month);
    // Current month: live figures as of now. History: a read-only month-end
    // summary (remainingDays = 1, so the live quota equals the month's left-over).
    final asOf = _isCurrentMonth ? now : DateTime(_month.year, _month.month, days);
    final monthKey = BudgetEngine.monthKey(_month);

    final budgetRepo = ref.watch(budgetRepositoryProvider);
    final txRepo = ref.watch(transactionRepositoryProvider);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _MonthBar(
              month: _month,
              onMonthTap: _openMonthSheet,
              onBudget: () => _openBudgetSheet(null),
            ),
            Expanded(
              child: StreamBuilder<List<Transaction>>(
                stream: txRepo.watchAll(),
                builder: (context, txSnapshot) {
                  final transactions =
                      txSnapshot.data ?? const <Transaction>[];
                  return StreamBuilder<BudgetMonth?>(
                    stream: budgetRepo.watchByMonth(monthKey),
                    builder: (context, budgetSnapshot) {
                      final budget = budgetSnapshot.data;
                      final snapshot = BudgetEngine.compute(
                        budget: budget,
                        transactions: transactions,
                        now: asOf,
                      );
                      return _HomeContent(
                        controller: _scroll,
                        budget: budget,
                        snapshot: snapshot,
                        transactions: transactions,
                        onSetBudget: () => _openBudgetSheet(budget),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Top bar: month button (left, opens the calendar sheet) + budget gear
/// (right). The old ‹ › arrows were removed by user ruling (DESIGN_MAIN §3.1).
class _MonthBar extends StatelessWidget {
  const _MonthBar({
    required this.month,
    required this.onMonthTap,
    required this.onBudget,
  });

  final DateTime month;
  final VoidCallback onMonthTap;
  final VoidCallback onBudget;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.m, AppSpacing.s, AppSpacing.s, 0),
      child: Row(
        children: [
          SizedBox(
            height: 40,
            child: OutlinedButton(
              key: const Key('home_month_button'),
              onPressed: onMonthTap,
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
                    style: theme.textTheme.bodyLarge,
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
          ),
          const Spacer(),
          IconButton(
            key: const Key('home_budget_entry'),
            onPressed: onBudget,
            icon: const Icon(Icons.tune),
            tooltip: '预算设置',
          ),
        ],
      ),
    );
  }
}

/// Month calendar sheet (DESIGN_MAIN §3.1): year row + a 3x4 month grid.
///
/// No gradient, no shadow - flat overlay surface with hairline borders, in the
/// same visual language as the category grid. Future months are disabled.
class _MonthSheet extends StatefulWidget {
  const _MonthSheet({
    required this.selected,
    required this.today,
    required this.onSelected,
  });

  /// The month currently displayed on the home page (highlighted in the grid).
  final DateTime selected;

  /// Real "now" (future months and the next year are disabled against it).
  final DateTime today;

  final ValueChanged<DateTime> onSelected;

  @override
  State<_MonthSheet> createState() => _MonthSheetState();
}

class _MonthSheetState extends State<_MonthSheet> {
  late int _year;

  @override
  void initState() {
    super.initState();
    _year = widget.selected.year;
  }

  bool get _yearCanAdvance => _year < widget.today.year;

  bool _isFutureMonth(int month) =>
      _year > widget.today.year ||
      (_year == widget.today.year && month > widget.today.month);

  void _select(int month) {
    widget.onSelected(DateTime(_year, month, 1));
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.of(context).viewPadding.bottom;
    return Container(
      key: const Key('home_month_sheet'),
      decoration: const BoxDecoration(
        color: AppColors.overlay,
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      padding: EdgeInsets.fromLTRB(
        AppSpacing.m, AppSpacing.s, AppSpacing.m, AppSpacing.l + bottomInset,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle.
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.hairline,
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
          ),
          const SizedBox(height: AppSpacing.m),
          // Year row: ‹ 2026 › (the next year is disabled against "now").
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _CircleIconButton(
                key: const Key('month_sheet_year_prev'),
                icon: Icons.chevron_left,
                onTap: () => setState(() => _year--),
              ),
              SizedBox(
                width: 96,
                child: Text(
                  '$_year',
                  key: const Key('month_sheet_year'),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleLarge,
                ),
              ),
              _CircleIconButton(
                key: const Key('month_sheet_year_next'),
                icon: Icons.chevron_right,
                onTap: _yearCanAdvance
                    ? () => setState(() => _year++)
                    : null,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.m),
          for (var row = 0; row < 4; row++) ...[
            if (row > 0) const SizedBox(height: AppSpacing.categoryGap),
            Row(
              children: [
                for (var col = 0; col < 3; col++) ...[
                  if (col > 0) const SizedBox(width: AppSpacing.categoryGap),
                  Expanded(
                    child: _MonthCell(
                      month: row * 3 + col + 1,
                      selected: _year == widget.selected.year &&
                          row * 3 + col + 1 == widget.selected.month,
                      disabled: _isFutureMonth(row * 3 + col + 1),
                      onTap: () => _select(row * 3 + col + 1),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Circular hairline button for the year row.
class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({
    super.key,
    required this.icon,
    required this.onTap,
  });

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return SizedBox(
      width: 48,
      height: 48,
      child: TouchedScale(
        pressedScale: 0.94,
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.hairline),
          ),
          child: Icon(
            icon,
            color: enabled
                ? AppColors.ink
                : AppColors.inkSecondary.withValues(alpha: 0.4),
          ),
        ),
      ),
    );
  }
}

/// One month cell: hairline border; selected = gold border + faint gold fill +
/// gold text; future = muted and disabled.
class _MonthCell extends StatelessWidget {
  const _MonthCell({
    required this.month,
    required this.selected,
    required this.disabled,
    required this.onTap,
  });

  final int month;
  final bool selected;
  final bool disabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color textColor;
    if (disabled) {
      textColor = AppColors.inkSecondary.withValues(alpha: 0.4);
    } else if (selected) {
      textColor = AppColors.goldAccent;
    } else {
      textColor = AppColors.ink;
    }
    return TouchedScale(
      pressedScale: 0.97,
      onTap: disabled ? null : onTap,
      child: Container(
        key: Key('month_sheet_cell_$month'),
        height: 52,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.goldContainer : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.m),
          border: Border.all(
            color: selected ? AppColors.goldAccent : AppColors.hairline,
          ),
        ),
        child: Text(
          '$month月',
          style: TextStyle(
            fontSize: AppFont.body,
            color: textColor,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

/// Scrollable body: hero / progress / today / donut / AI slot.
class _HomeContent extends StatelessWidget {
  const _HomeContent({
    required this.controller,
    required this.budget,
    required this.snapshot,
    required this.transactions,
    required this.onSetBudget,
  });

  final ScrollController controller;
  final BudgetMonth? budget;
  final BudgetSnapshot snapshot;
  final List<Transaction> transactions;
  final VoidCallback onSetBudget;

  @override
  Widget build(BuildContext context) {
    return ListView(
      controller: controller,
      physics: const InertialScrollPhysics(),
      padding: const EdgeInsets.all(AppSpacing.m),
      children: [
        if (budget == null)
          _OnboardingCard(onSetBudget: onSetBudget)
        else
          _HeroCard(snapshot: snapshot),
        const SizedBox(height: AppSpacing.m),
        _ProgressCard(budget: budget, snapshot: snapshot),
        const SizedBox(height: AppSpacing.m),
        _TodayRow(transactions: transactions),
        const SizedBox(height: AppSpacing.m),
        _TodayDonutCard(transactions: transactions),
        const SizedBox(height: AppSpacing.m),
        const _AiCard(),
      ],
    );
  }
}

/// Hero: live daily allowance (brand serif + gold gradient).
class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.snapshot});

  final BudgetSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final live = snapshot.liveDailyCents ?? 0;
    final fixed = snapshot.fixedDailyCents ?? 0;
    final remaining = snapshot.remainingCents ?? 0;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.l),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('今天还能花 · Today\'s Allowance',
                style: theme.textTheme.bodySmall),
            const SizedBox(height: AppSpacing.s),
            ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                colors: [AppColors.goldAccent, AppColors.goldDeep],
              ).createShader(bounds),
              child: Text(
                '¥${_money(live)}',
                style: const TextStyle(
                  fontFamily: 'PlayfairDisplay',
                  fontWeight: FontWeight.w600,
                  fontSize: 48,
                  color: AppColors.goldAccent,
                  fontFeatures: AppFont.tabularFigures,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.s),
            Text(
              '基准 ¥${_money(fixed)}/天 · 剩余 ¥${_money(remaining)} · '
              '剩 ${snapshot.remainingDays} 天',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

/// Onboarding state: no budget row for the displayed month.
class _OnboardingCard extends StatelessWidget {
  const _OnboardingCard({required this.onSetBudget});

  final VoidCallback onSetBudget;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.l),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('先设置本月预算', style: theme.textTheme.titleLarge),
            const SizedBox(height: AppSpacing.xs),
            Text('填入本月收入与计划存款，主页会算出每天还能花多少',
                style: theme.textTheme.bodySmall),
            const SizedBox(height: AppSpacing.m),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                key: const Key('home_set_budget'),
                onPressed: onSetBudget,
                child: const Text('设置预算'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Month progress against the spendable budget.
class _ProgressCard extends StatelessWidget {
  const _ProgressCard({required this.budget, required this.snapshot});

  final BudgetMonth? budget;
  final BudgetSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (budget == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.m),
          child: Text('设置预算后显示本月进度', style: theme.textTheme.bodySmall),
        ),
      );
    }
    final monthly = snapshot.budgetCents ?? 0;
    final spent = snapshot.spentCents;
    final impossible = monthly <= 0;
    final overspent = snapshot.isOverspent && !impossible;
    final barColor = (impossible || overspent)
        ? AppColors.semanticExpense
        : AppColors.goldAccent;
    final barValue = impossible ? 1.0 : snapshot.spentRatio;
    final ratioText = impossible
        ? '预算不可行'
        : '${(snapshot.spentRatio * 100).round()}%';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.m),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('本月已花', style: theme.textTheme.bodySmall),
                const Spacer(),
                Text(
                  '¥${_money(spent)} / ¥${_money(monthly)}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.ink,
                    fontFeatures: AppFont.tabularFigures,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.s),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.pill),
              child: LinearProgressIndicator(
                value: barValue,
                minHeight: 8,
                color: barColor,
                backgroundColor: AppColors.elevated,
              ),
            ),
            const SizedBox(height: AppSpacing.s),
            Row(
              children: [
                Text(
                  '收入 ¥${_money(budget!.incomeCents)} − '
                  '计划存款 ¥${_money(budget!.savingsTargetCents)}',
                  style: theme.textTheme.bodySmall,
                ),
                const Spacer(),
                Text(ratioText, style: theme.textTheme.bodySmall),
              ],
            ),
            if (impossible) ...[
              const SizedBox(height: AppSpacing.xs),
              Text('本月预算已不可行：计划存款不低于收入',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: AppColors.semanticExpense)),
            ] else if (overspent) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                '已超支 ¥${_money(-(snapshot.remainingCents ?? 0))}',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: AppColors.semanticExpense),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Today's confirmed spending: amount + count.
class _TodayRow extends StatelessWidget {
  const _TodayRow({required this.transactions});

  final List<Transaction> transactions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final today = BudgetEngine.todaySpending(transactions, day: DateTime.now());
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
      child: Row(
        children: [
          Text('今日已花', style: theme.textTheme.bodySmall),
          const Spacer(),
          Text(
            '¥${_money(today.cents)} · ${today.count} 笔',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.ink,
              fontFeatures: AppFont.tabularFigures,
            ),
          ),
        ],
      ),
    );
  }
}

/// Today's expense composition donut (gold scale, shared with the stats pie).
class _TodayDonutCard extends ConsumerWidget {
  const _TodayDonutCard({required this.transactions});

  final List<Transaction> transactions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final categoryRepo = ref.watch(categoryRepositoryProvider);
    final now = DateTime.now();
    final todayExpenses = transactions.where((t) {
      if (t.isDraft || t.deletedAt != null) return false;
      if (t.type != TransactionType.expense) return false;
      final at = t.occurredAt;
      return at.year == now.year && at.month == now.month && at.day == now.day;
    }).toList();

    // Same slicing function + palette as the statistics pie (DESIGN_MAIN §3.5).
    final totals = StatisticsService.expenseByCategory(todayExpenses);
    final slices = StatisticsService.chartSlices(totals, maxNamed: 3);
    final total = slices.fold<int>(0, (sum, s) => sum + s.cents);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.m),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('今日支出构成', style: theme.textTheme.titleMedium),
                const Spacer(),
                if (total > 0)
                  Text('${todayExpenses.length} 笔 · ¥${_money(total)}',
                      style: theme.textTheme.bodySmall),
              ],
            ),
            const SizedBox(height: AppSpacing.m),
            if (slices.isEmpty)
              // Empty state: a single line, never an empty ring.
              Text('今天还没有支出', style: theme.textTheme.bodySmall)
            else
              StreamBuilder<List<Category>>(
                stream: categoryRepo.watchAll(),
                builder: (context, catSnapshot) {
                  final categories = catSnapshot.data ?? const <Category>[];
                  String name(CategorySlice slice) {
                    if (slice.isOther) return '其他';
                    for (final c in categories) {
                      if (c.id == slice.categoryId) return c.name;
                    }
                    return '未分类';
                  }

                  return Row(
                    children: [
                      _Donut(total: total, slices: slices),
                      const SizedBox(width: AppSpacing.l),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (final slice in slices)
                              _LegendRow(
                                label: name(slice),
                                cents: slice.cents,
                                color: AppColors.chartSliceColor(
                                  slice.colorIndex,
                                  neutral: slice.isOther,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

/// Donut ring (outer Ø104, ring width 14) with the total in the hole.
class _Donut extends StatelessWidget {
  const _Donut({required this.total, required this.slices});

  final int total;
  final List<CategorySlice> slices;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 104,
      height: 104,
      child: Stack(
        alignment: Alignment.center,
        children: [
          PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 38, // 52 - 14 ring = Ø104 outer.
              sections: [
                for (final slice in slices)
                  PieChartSectionData(
                    value: slice.cents.toDouble(),
                    color: AppColors.chartSliceColor(
                      slice.colorIndex,
                      neutral: slice.isOther,
                    ),
                    radius: 14,
                    showTitle: false,
                  ),
              ],
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('合计', style: theme.textTheme.bodySmall),
              Text(
                '¥${_money(total)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontSize: AppFont.bodySm,
                  color: AppColors.ink,
                  fontFeatures: AppFont.tabularFigures,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// One legend row: colour dot + name + right-aligned tabular amount.
class _LegendRow extends StatelessWidget {
  const _LegendRow({
    required this.label,
    required this.cents,
    required this.color,
  });

  final String label;
  final int cents;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          Container(width: 6, height: 6, color: color),
          const SizedBox(width: AppSpacing.s),
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(color: AppColors.ink),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            '¥${_money(cents)}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.ink,
              fontFeatures: AppFont.tabularFigures,
            ),
          ),
        ],
      ),
    );
  }
}

/// AI slot: layout reserved for M2.0, deliberately without fake content.
class _AiCard extends StatelessWidget {
  const _AiCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.m),
        child: Row(
          children: [
            const Icon(Icons.auto_awesome, color: AppColors.inkSecondary, size: 18),
            const SizedBox(width: AppSpacing.s),
            Expanded(
              child: Text('AI 分析与建议', style: theme.textTheme.titleMedium),
            ),
            Text('M2.0 上线', style: theme.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

/// Monthly budget entry sheet: income + planned savings, with "reuse last month".
class _BudgetSheet extends ConsumerStatefulWidget {
  const _BudgetSheet({required this.month, required this.current});

  final DateTime month;
  final BudgetMonth? current;

  @override
  ConsumerState<_BudgetSheet> createState() => _BudgetSheetState();
}

class _BudgetSheetState extends ConsumerState<_BudgetSheet> {
  late final TextEditingController _income;
  late final TextEditingController _savings;
  BudgetMonth? _previous;
  bool _loadingPrevious = true;

  BudgetRepository get _repo => ref.read(budgetRepositoryProvider);

  @override
  void initState() {
    super.initState();
    _income = TextEditingController(text: _yuanText(widget.current?.incomeCents));
    _savings =
        TextEditingController(text: _yuanText(widget.current?.savingsTargetCents));
    _loadPrevious();
  }

  static String _yuanText(int? cents) =>
      cents == null ? '' : (cents / 100).toStringAsFixed(cents % 100 == 0 ? 0 : 2);

  Future<void> _loadPrevious() async {
    final prev = DateTime(widget.month.year, widget.month.month - 1, 1);
    final row = await _repo.getByMonth(BudgetEngine.monthKey(prev));
    if (mounted) {
      setState(() {
        _previous = row;
        _loadingPrevious = false;
      });
    }
  }

  void _reusePrevious() {
    final row = _previous;
    if (row == null) return;
    setState(() {
      _income.text = _yuanText(row.incomeCents);
      _savings.text = _yuanText(row.savingsTargetCents);
    });
  }

  Future<void> _save() async {
    final incomeYuan = double.tryParse(_income.text.trim());
    final savingsYuan = double.tryParse(_savings.text.trim());
    if (incomeYuan == null || savingsYuan == null) return;
    await _repo.upsert(
      yearMonth: BudgetEngine.monthKey(widget.month),
      incomeCents: (incomeYuan * 100).round(),
      savingsTargetCents: (savingsYuan * 100).round(),
    );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _income.dispose();
    _savings.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.l,
        right: AppSpacing.l,
        top: AppSpacing.l,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.l,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('${widget.month.year} 年 ${widget.month.month} 月预算',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppSpacing.m),
          TextField(
            key: const Key('budget_income'),
            controller: _income,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: '本月收入（元）'),
          ),
          const SizedBox(height: AppSpacing.m),
          TextField(
            key: const Key('budget_savings'),
            controller: _savings,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: '计划存款（元）'),
          ),
          const SizedBox(height: AppSpacing.m),
          Row(
            children: [
              TextButton(
                key: const Key('budget_reuse_previous'),
                onPressed:
                    (!_loadingPrevious && _previous != null) ? _reusePrevious : null,
                child: const Text('沿用上月数值'),
              ),
              const Spacer(),
              FilledButton(
                key: const Key('budget_save'),
                onPressed: _save,
                child: const Text('保存'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Formats integer cents as yuan, trimming trailing zeros (8640 -> 86.4).
String _money(int cents) {
  final negative = cents < 0;
  final abs = cents.abs();
  final String text;
  if (abs % 100 == 0) {
    text = (abs ~/ 100).toString();
  } else if (abs % 10 == 0) {
    text = (abs / 100).toStringAsFixed(1);
  } else {
    text = (abs / 100).toStringAsFixed(2);
  }
  return negative ? '-$text' : text;
}
