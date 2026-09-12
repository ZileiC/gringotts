import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/app.dart';
import '../data/app_database.dart';
import '../data/repositories/repositories.dart';
import '../domain/models.dart';
import '../ui/category_icons.dart';
import '../ui/motion.dart';
import '../ui/tokens.dart';

/// Type filter for the ledger. Filtering only removes rows - it never
/// changes the grouping dimension (time) or the group order.
enum LedgerFilter { all, expense, income }

/// One day's entries, newest first.
class LedgerDayGroup {
  const LedgerDayGroup({required this.day, required this.transactions});

  final DateTime day;
  final List<Transaction> transactions;

  /// Net of the displayed rows: income adds, expense subtracts.
  int get netCents => transactions.fold<int>(0, (sum, t) {
        if (t.type == TransactionType.income) return sum + t.amountCents;
        if (t.type == TransactionType.expense) return sum - t.amountCents;
        return sum;
      });
}

/// Time-first grouping for the ledger (DESIGN_MAIN section 5, user ruling 3):
/// the only default hierarchy is `month -> day -> entry`. Pure functions so
/// the invariants are unit-testable without a widget tree.
abstract final class LedgerGrouping {
  /// Live transactions whose [Transaction.occurredAt] falls in [month].
  static List<Transaction> inMonth(
    List<Transaction> all,
    DateTime month,
  ) {
    return all
        .where((t) =>
            t.deletedAt == null &&
            t.occurredAt.year == month.year &&
            t.occurredAt.month == month.month)
        .toList();
  }

  /// Applies the type filter. Rows are only removed, never reordered.
  static List<Transaction> applyFilter(
    List<Transaction> transactions,
    LedgerFilter filter,
  ) {
    switch (filter) {
      case LedgerFilter.all:
        return List<Transaction>.of(transactions);
      case LedgerFilter.expense:
        return transactions
            .where((t) => t.type == TransactionType.expense)
            .toList();
      case LedgerFilter.income:
        return transactions
            .where((t) => t.type == TransactionType.income)
            .toList();
    }
  }

  /// Groups by calendar day in time-descending order (newest day first, and
  /// newest entry first inside each day).
  ///
  /// Filtering before grouping is safe: the sort key is the timestamp, so a
  /// subset keeps the exact same day sequence and dimension.
  static List<LedgerDayGroup> groupByDay(List<Transaction> transactions) {
    final sorted = List<Transaction>.of(transactions)
      ..sort((a, b) {
        final byTime = b.occurredAt.compareTo(a.occurredAt);
        // Stable, deterministic tie-break for equal timestamps.
        return byTime != 0 ? byTime : b.id.compareTo(a.id);
      });
    final groups = <LedgerDayGroup>[];
    DateTime? currentDay;
    var bucket = <Transaction>[];
    for (final t in sorted) {
      final day =
          DateTime(t.occurredAt.year, t.occurredAt.month, t.occurredAt.day);
      if (currentDay == null || day != currentDay) {
        if (currentDay != null) {
          groups.add(LedgerDayGroup(day: currentDay, transactions: bucket));
        }
        currentDay = day;
        bucket = <Transaction>[];
      }
      bucket.add(t);
    }
    if (currentDay != null) {
      groups.add(LedgerDayGroup(day: currentDay, transactions: bucket));
    }
    return groups;
  }

  /// Month switcher key (`YYYY-MM`).
  static String monthLabel(DateTime month) =>
      '${month.year.toString().padLeft(4, '0')}-'
      '${month.month.toString().padLeft(2, '0')}';

  /// Eyebrow label: `今天 · 9月11日` / `昨天 · 9月10日` / `9月9日`.
  static String dayLabel(DateTime day, DateTime now) {
    final target = DateTime(day.year, day.month, day.day);
    final today = DateTime(now.year, now.month, now.day);
    final body = '${day.month}月${day.day}日';
    if (target == today) return '今天 · $body';
    if (target == today.subtract(const Duration(days: 1))) return '昨天 · $body';
    return body;
  }
}

/// Ledger: all income/expense records for a month, grouped by day, with a
/// full-field edit sheet per entry (DESIGN_MAIN section 5).
class LedgerPage extends ConsumerStatefulWidget {
  const LedgerPage({super.key, this.now});

  /// Injectable clock (tests pin "今天/昨天" and the default month).
  final DateTime Function()? now;

  @override
  ConsumerState<LedgerPage> createState() => _LedgerPageState();
}

class _LedgerPageState extends ConsumerState<LedgerPage> {
  late DateTime _month;
  LedgerFilter _filter = LedgerFilter.all;

  DateTime _now() => widget.now?.call() ?? DateTime.now();

  @override
  void initState() {
    super.initState();
    final now = _now();
    _month = DateTime(now.year, now.month, 1);
  }

  bool get _isCurrentMonth {
    final now = _now();
    return _month.year == now.year && _month.month == now.month;
  }

  void _shiftMonth(int delta) {
    setState(() => _month = DateTime(_month.year, _month.month + delta, 1));
  }

  Future<void> _openEdit(Transaction transaction, List<Category> categories) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _LedgerEditSheet(
        transaction: transaction,
        categories: categories,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final txRepo = ref.watch(transactionRepositoryProvider);
    final categoryRepo = ref.watch(categoryRepositoryProvider);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          key: const Key('ledger_back'),
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back),
          tooltip: '返回',
        ),
        title: const Text('明细'),
      ),
      body: StreamBuilder<List<Transaction>>(
        stream: txRepo.watchAll(),
        builder: (context, txSnapshot) {
          final all = txSnapshot.data ?? const <Transaction>[];
          return StreamBuilder<List<Category>>(
            stream: categoryRepo.watchAll(),
            builder: (context, catSnapshot) {
              final categories = catSnapshot.data ?? const <Category>[];
              final monthRows = LedgerGrouping.inMonth(all, _month);
              final visible =
                  LedgerGrouping.applyFilter(monthRows, _filter);
              final groups = LedgerGrouping.groupByDay(visible);
              return Column(
                children: [
                  _MonthFilterBar(
                    monthLabel: LedgerGrouping.monthLabel(_month),
                    canGoForward: !_isCurrentMonth,
                    filter: _filter,
                    count: visible.length,
                    onPrev: () => _shiftMonth(-1),
                    onNext: () => _shiftMonth(1),
                    onFilter: (f) => setState(() => _filter = f),
                  ),
                  Expanded(
                    child: groups.isEmpty
                        ? const Center(child: Text('这个月还没有记录'))
                        : ListView(
                            key: const Key('ledger_list'),
                            physics: const InertialScrollPhysics(),
                            padding: const EdgeInsets.only(
                              bottom: AppSpacing.xl,
                            ),
                            children: [
                              for (final group in groups) ...[
                                _DayHeader(
                                  day: group.day,
                                  netCents: group.netCents,
                                  now: _now(),
                                ),
                                for (final t in group.transactions)
                                  _LedgerRow(
                                    transaction: t,
                                    categories: categories,
                                    onTap: () =>
                                        _openEdit(t, categories),
                                  ),
                              ],
                            ],
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
}

/// Month switcher (`‹ 2026-09 ›`) with the type-filter chips on its right.
class _MonthFilterBar extends StatelessWidget {
  const _MonthFilterBar({
    required this.monthLabel,
    required this.canGoForward,
    required this.filter,
    required this.count,
    required this.onPrev,
    required this.onNext,
    required this.onFilter,
  });

  final String monthLabel;
  final bool canGoForward;
  final LedgerFilter filter;
  final int count;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final ValueChanged<LedgerFilter> onFilter;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.s, 0, AppSpacing.m, 0),
      child: Row(
        children: [
          IconButton(
            key: const Key('ledger_month_prev'),
            onPressed: onPrev,
            icon: const Icon(Icons.chevron_left),
            tooltip: '上一个月',
          ),
          Text(
            monthLabel,
            key: const Key('ledger_month_label'),
            style: theme.textTheme.titleMedium?.copyWith(
              fontFeatures: AppFont.tabularFigures,
            ),
          ),
          IconButton(
            key: const Key('ledger_month_next'),
            onPressed: canGoForward ? onNext : null,
            icon: const Icon(Icons.chevron_right),
            tooltip: '下一个月',
          ),
          const Spacer(),
          MotionChip(
            key: const Key('ledger_filter_all'),
            label: '全部',
            selected: filter == LedgerFilter.all,
            onTap: () => onFilter(LedgerFilter.all),
          ),
          const SizedBox(width: AppSpacing.xs),
          MotionChip(
            key: const Key('ledger_filter_expense'),
            label: '支出',
            selected: filter == LedgerFilter.expense,
            onTap: () => onFilter(LedgerFilter.expense),
          ),
          const SizedBox(width: AppSpacing.xs),
          MotionChip(
            key: const Key('ledger_filter_income'),
            label: '收入',
            selected: filter == LedgerFilter.income,
            onTap: () => onFilter(LedgerFilter.income),
          ),
          const SizedBox(width: AppSpacing.s),
          Text(
            '$count 笔',
            key: const Key('ledger_count'),
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

/// One day section header: eyebrow label + the day's net total.
class _DayHeader extends StatelessWidget {
  const _DayHeader({
    required this.day,
    required this.netCents,
    required this.now,
  });

  final DateTime day;
  final int netCents;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sign = netCents > 0 ? '+' : (netCents < 0 ? '-' : '');
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.m,
        AppSpacing.l,
        AppSpacing.m,
        AppSpacing.s,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              LedgerGrouping.dayLabel(day, now),
              key: Key('ledger_day_${_key(day)}'),
              style: theme.textTheme.bodySmall?.copyWith(
                fontSize: AppFont.bodySm,
                color: AppColors.inkSecondary,
                letterSpacing: 1.4,
              ),
            ),
          ),
          Text(
            '$sign¥${_money(netCents)}',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.ink,
              fontFeatures: AppFont.tabularFigures,
            ),
          ),
        ],
      ),
    );
  }

  static String _key(DateTime day) =>
      '${day.year.toString().padLeft(4, '0')}-'
      '${day.month.toString().padLeft(2, '0')}-'
      '${day.day.toString().padLeft(2, '0')}';
}

/// One entry row: category icon, merchant/note (category name as fallback)
/// and the amount coloured by type.
class _LedgerRow extends StatelessWidget {
  const _LedgerRow({
    required this.transaction,
    required this.categories,
    required this.onTap,
  });

  final Transaction transaction;
  final List<Category> categories;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Category? category;
    for (final c in categories) {
      if (c.id == transaction.categoryId) {
        category = c;
        break;
      }
    }
    final merchant = transaction.merchant?.trim() ?? '';
    final note = transaction.note?.trim() ?? '';
    final title = merchant.isNotEmpty
        ? merchant
        : (note.isNotEmpty ? note : (category?.name ?? '未分类'));
    final at = transaction.occurredAt;
    final time = '${at.hour.toString().padLeft(2, '0')}:'
        '${at.minute.toString().padLeft(2, '0')}';
    final subtitle = (merchant.isNotEmpty && note.isNotEmpty)
        ? '$time · $note'
        : time;
    final isIncome = transaction.type == TransactionType.income;

    return InkWell(
      key: Key('ledger_row_${transaction.id}'),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.m,
          vertical: AppSpacing.s,
        ),
        child: Row(
          children: [
            Icon(
              CategoryIcons.forName(category?.icon),
              size: AppFont.categoryIcon,
              color: AppColors.inkSecondary,
            ),
            const SizedBox(width: AppSpacing.m),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.bodyLarge,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(subtitle, style: theme.textTheme.bodySmall),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.s),
            Text(
              '¥${_money(transaction.amountCents)}',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: isIncome ? AppColors.semanticIncome : AppColors.ink,
                fontFeatures: AppFont.tabularFigures,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bottom sheet for full-field editing plus tombstone deletion.
///
/// Every editable column is written explicitly. `is_draft` / `source` are
/// deliberately untouched by [TransactionRepository.updateTransaction] (the
/// draft pipeline is abolished, but legacy rows keep their flag).
class _LedgerEditSheet extends ConsumerStatefulWidget {
  const _LedgerEditSheet({
    required this.transaction,
    required this.categories,
  });

  final Transaction transaction;
  final List<Category> categories;

  @override
  ConsumerState<_LedgerEditSheet> createState() => _LedgerEditSheetState();
}

class _LedgerEditSheetState extends ConsumerState<_LedgerEditSheet> {
  late final TextEditingController _amount;
  late final TextEditingController _merchant;
  late final TextEditingController _note;
  late TransactionType _type;
  late String? _categoryId;
  late DateTime _occurredAt;
  bool _busy = false;

  TransactionRepository get _repo => ref.read(transactionRepositoryProvider);

  @override
  void initState() {
    super.initState();
    _amount = TextEditingController(text: _yuan(widget.transaction.amountCents));
    _merchant = TextEditingController(text: widget.transaction.merchant ?? '');
    _note = TextEditingController(text: widget.transaction.note ?? '');
    _type = widget.transaction.type;
    _categoryId = widget.transaction.categoryId;
    _occurredAt = widget.transaction.occurredAt;
  }

  @override
  void dispose() {
    _amount.dispose();
    _merchant.dispose();
    _note.dispose();
    super.dispose();
  }

  static String _yuan(int cents) =>
      cents % 100 == 0 ? (cents ~/ 100).toString() : (cents / 100).toStringAsFixed(2);

  static String _date(DateTime d) => '${d.year}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _occurredAt,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null && mounted) {
      setState(() => _occurredAt = DateTime(
            picked.year,
            picked.month,
            picked.day,
            _occurredAt.hour,
            _occurredAt.minute,
          ));
    }
  }

  Future<void> _save() async {
    if (_busy) return;
    final yuan = double.tryParse(_amount.text.trim());
    if (yuan == null || yuan <= 0) return;
    setState(() => _busy = true);
    final merchant = _merchant.text.trim();
    final note = _note.text.trim();
    // Full-field write; is_draft is intentionally preserved by the repository.
    await _repo.updateTransaction(
      id: widget.transaction.id,
      amountCents: (yuan * 100).round(),
      type: _type,
      categoryId: _categoryId,
      merchant: merchant.isEmpty ? null : merchant,
      note: note.isEmpty ? null : note,
      occurredAt: _occurredAt,
    );
    if (!mounted) return;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已更新'), duration: Duration(seconds: 1)),
    );
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('删除这笔记录？'),
        content: const Text('删除后不再出现在明细与统计中（数据库保留墓碑行）。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            key: const Key('ledger_delete_confirm'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _repo.softDelete(widget.transaction.id);
    if (!mounted) return;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已删除'), duration: Duration(seconds: 1)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
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
          Text('编辑记录', style: theme.textTheme.titleLarge),
          const SizedBox(height: AppSpacing.m),
          TextField(
            key: const Key('ledger_edit_amount'),
            controller: _amount,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: '金额（元）'),
          ),
          const SizedBox(height: AppSpacing.m),
          Row(
            children: [
              ChoiceChip(
                key: const Key('ledger_edit_type_expense'),
                label: const Text('支出'),
                selected: _type == TransactionType.expense,
                onSelected: (_) =>
                    setState(() => _type = TransactionType.expense),
              ),
              const SizedBox(width: AppSpacing.s),
              ChoiceChip(
                key: const Key('ledger_edit_type_income'),
                label: const Text('收入'),
                selected: _type == TransactionType.income,
                onSelected: (_) =>
                    setState(() => _type = TransactionType.income),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.m),
          Align(
            alignment: Alignment.centerLeft,
            child: Text('类别', style: theme.textTheme.bodySmall),
          ),
          const SizedBox(height: AppSpacing.s),
          Wrap(
            spacing: AppSpacing.s,
            runSpacing: AppSpacing.s,
            children: [
              ChoiceChip(
                key: const Key('ledger_edit_cat_none'),
                label: const Text('未分类'),
                selected: _categoryId == null,
                onSelected: (_) => setState(() => _categoryId = null),
              ),
              for (final c in widget.categories)
                ChoiceChip(
                  key: Key('ledger_edit_cat_${c.id}'),
                  label: Text(c.name),
                  selected: _categoryId == c.id,
                  onSelected: (_) => setState(() => _categoryId = c.id),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.m),
          TextField(
            key: const Key('ledger_edit_merchant'),
            controller: _merchant,
            decoration: const InputDecoration(labelText: '商户'),
          ),
          const SizedBox(height: AppSpacing.m),
          TextField(
            key: const Key('ledger_edit_note'),
            controller: _note,
            decoration: const InputDecoration(labelText: '备注'),
          ),
          const SizedBox(height: AppSpacing.m),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              key: const Key('ledger_edit_date'),
              onPressed: _pickDate,
              icon: const Icon(Icons.event, size: 18),
              label: Text('日期 ${_date(_occurredAt)}'),
            ),
          ),
          const SizedBox(height: AppSpacing.m),
          Row(
            children: [
              TextButton(
                key: const Key('ledger_edit_delete'),
                onPressed: _busy ? null : _confirmDelete,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.semanticExpense,
                ),
                child: const Text('删除'),
              ),
              const Spacer(),
              FilledButton(
                key: const Key('ledger_edit_save'),
                onPressed: _busy ? null : _save,
                child: const Text('保存'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Formats integer cents as yuan, trimming trailing zeros (70004 -> 700.04).
String _money(int cents) {
  final abs = cents.abs();
  if (abs % 100 == 0) return (abs ~/ 100).toString();
  if (abs % 10 == 0) return (abs / 100).toStringAsFixed(1);
  return (abs / 100).toStringAsFixed(2);
}
