import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/app.dart';
import '../data/app_database.dart';
import '../data/repositories/budget_repository.dart';
import '../domain/models.dart';
import '../services/budget_engine.dart';
import '../services/savings_plan.dart';
import '../services/statistics_service.dart';
import '../ui/motion.dart';
import '../ui/month_sheet.dart';
import '../ui/record_key.dart';
import '../ui/tokens.dart';

/// Home = analysis / guidance page (M2.0 pre-wave, DESIGN_MAIN §3).
///
/// One of the three peer tabs hosted by [HomeShell]. It answers "how much can
/// I still spend today" from the monthly budget and the confirmed expense
/// records, and hosts the AI slot (placeholder until M2.0). The month title is
/// a button that opens the calendar sheet (T-12c Part D).
class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key, this.onRecord});

  /// Pushes the speed-entry page (the analysis page's child). Owned by
  /// HomeShell so the shell can pin the analysis tab before the push; the key
  /// still renders when the page is mounted stand-alone in a test.
  final VoidCallback? onRecord;

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  /// First day of the displayed month (shared by analysis / ledger / stats).
  DateTime get _month => ref.watch(selectedMonthProvider);
  final ScrollController _scroll = ScrollController();

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

  /// Opens the shared month calendar sheet; the selection updates the shared
  /// selected month, so ledger and stats follow.
  Future<void> _openMonthSheet() {
    return showMonthSheet(
      context,
      selected: _month,
      onSelected: (month) =>
          ref.read(selectedMonthProvider.notifier).select(month),
    );
  }

  /// Confirms the month's plan: one savings asset, then the budget row stops
  /// prompting (the card disappears with the refreshed stream).
  Future<void> _confirmSavings(BudgetMonth budget) async {
    final service = SavingsPlanService(
      budgetRepo: ref.read(budgetRepositoryProvider),
      assetRepo: ref.read(assetRepositoryProvider),
    );
    final asset = await service.confirm(budget);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('已生成资产 \u00a5${_money(asset.valueCents)}'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// 这个月没攒够: only the timestamp is written.
  Future<void> _skipSavings(BudgetMonth budget) =>
      ref.read(budgetRepositoryProvider).markSavingsSkipped(budget.id);

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
              onRecord: widget.onRecord,
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
                        month: _month,
                        budget: budget,
                        snapshot: snapshot,
                        transactions: transactions,
                        onSetBudget: () => _openBudgetSheet(budget),
                        onSavingsConfirm: () => _confirmSavings(budget!),
                        onSavingsSkip: () => _skipSavings(budget!),
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

/// Top bar (T-14b / DESIGN_MAIN section 8.2): month button (left, opens the
/// calendar sheet) + [RecordKey] + budget gear (right). Frozen size budget:
/// 56 total (8 top padding + 48 content row), month button stays 40 and is
/// vertically centred, the record key is 36 optic inside a 48x48 hit target
/// with a 4dp gap to the 48x48 gear. The old ‹ › arrows were removed by
/// user ruling (DESIGN_MAIN §3.1) and the record entry lives on the analysis
/// page only, so it can never be reached from the assets or stats tab.
class _MonthBar extends StatelessWidget {
  const _MonthBar({
    required this.month,
    required this.onMonthTap,
    required this.onBudget,
    required this.onRecord,
  });

  final DateTime month;
  final VoidCallback onMonthTap;
  final VoidCallback onBudget;

  /// Null when HomePage is mounted without a shell (tests); the key always
  /// renders because it belongs to this page.
  final VoidCallback? onRecord;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Width budget on a 320dp viewport: 16 (left) + month button (~130) +
    // flexible gap (>=12) + 48 (record key) + 4 (gap) + 48 (gear) + 8 (right)
    // = 266, so the gap absorbs the slack and nothing is squeezed.
    return SizedBox(
      key: const Key('home_top_bar'),
      height: AppSpacing.topBarHeight,
      child: Padding(
        padding:
            const EdgeInsets.fromLTRB(AppSpacing.m, AppSpacing.s, AppSpacing.s, 0),
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
                      // T-14b: the month button switches to MiSans together
                      // with the bottom tabs; amounts stay tabular.
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
            ),
            const Spacer(),
            RecordKey(
              key: const Key('home_record_key'),
              onPressed: onRecord,
            ),
            const SizedBox(width: AppSpacing.xs),
            IconButton(
              key: const Key('home_budget_entry'),
              onPressed: onBudget,
              icon: const Icon(Icons.tune),
              tooltip: '预算设置',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(
                width: AppSpacing.recordKeyHit,
                height: AppSpacing.recordKeyHit,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Scrollable body: hero / progress / today / donut / AI slot.
class _HomeContent extends StatelessWidget {
  const _HomeContent({
    required this.controller,
    required this.month,
    required this.budget,
    required this.snapshot,
    required this.transactions,
    required this.onSetBudget,
    required this.onSavingsConfirm,
    required this.onSavingsSkip,
  });

  final ScrollController controller;
  final DateTime month;
  final BudgetMonth? budget;
  final BudgetSnapshot snapshot;
  final List<Transaction> transactions;
  final VoidCallback onSetBudget;
  final VoidCallback onSavingsConfirm;
  final VoidCallback onSavingsSkip;

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
        if (SavingsPlan.shouldPrompt(budget)) ...[
          const SizedBox(height: AppSpacing.m),
          _SavingsCard(
            budget: budget!,
            month: month,
            monthEnd: SavingsPlan.isMonthEnd(DateTime.now(), month),
            onConfirm: onSavingsConfirm,
            onSkip: onSavingsSkip,
          ),
        ],
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
              shaderCallback: (bounds) =>
                  AppGradient.goldText.createShader(bounds),
              child: Text(
                '¥${_money(live)}',
                style: const TextStyle(
                  fontFamily: 'PlayfairDisplay',
                  fontWeight: FontWeight.w600,
                  fontSize: AppFont.brandNumber,
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

/// T-21 / DESIGN_MAIN 11.5: month-end planned-savings -> asset card.
///
/// Two actions only: 存进资产 (creates one savings asset) and 这个月没攒够
/// (writes the skip timestamp, zero assets). The card disappears as soon as
/// either timestamp is set, because the budget stream refreshes.
class _SavingsCard extends StatelessWidget {
  const _SavingsCard({
    required this.budget,
    required this.month,
    required this.monthEnd,
    required this.onConfirm,
    required this.onSkip,
  });

  final BudgetMonth budget;
  final DateTime month;
  final bool monthEnd;
  final VoidCallback onConfirm;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      key: const Key('home_savings_card'),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.l),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('本月计划存款', style: theme.textTheme.titleLarge),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '计划把 \u00a5${_money(budget.savingsTargetCents)} 存成资产'
              '（${SavingsPlan.assetName(month)}）',
              style: theme.textTheme.bodySmall,
            ),
            if (monthEnd) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                '这个月快结束了',
                key: const Key('home_savings_month_end'),
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: AppColors.goldAccent),
              ),
            ],
            const SizedBox(height: AppSpacing.m),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    key: const Key('savings_confirm'),
                    onPressed: onConfirm,
                    child: const Text('存进资产'),
                  ),
                ),
                const SizedBox(width: AppSpacing.s),
                Expanded(
                  child: OutlinedButton(
                    key: const Key('savings_skip'),
                    onPressed: onSkip,
                    child: const Text('这个月没攒够'),
                  ),
                ),
              ],
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
