import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/app.dart';
import '../data/app_database.dart';
import '../data/repositories/repositories.dart';
import '../ui/tokens.dart';

/// Day-grouped draft review page: backfill category/merchant/note, then
/// confirm drafts into formal records. Drafts older than 7 days render grey.
///
/// Never deletes drafts (tombstone-only rule).
class ReviewPage extends ConsumerStatefulWidget {
  const ReviewPage({super.key});

  @override
  ConsumerState<ReviewPage> createState() => _ReviewPageState();
}

class _ReviewPageState extends ConsumerState<ReviewPage> {
  final Set<String> _selected = <String>{};
  String? _bulkCategoryId;

  TransactionRepository get _txRepo => ref.read(transactionRepositoryProvider);
  CategoryRepository get _categoryRepo =>
      ref.read(categoryRepositoryProvider);

  bool _isStale(DateTime occurredAt) =>
      DateTime.now().difference(occurredAt).inDays > 7;

  Map<DateTime, List<Transaction>> _groupByDay(List<Transaction> drafts) {
    final map = <DateTime, List<Transaction>>{};
    for (final d in drafts) {
      final day =
          DateTime(d.occurredAt.year, d.occurredAt.month, d.occurredAt.day);
      map.putIfAbsent(day, () => []).add(d);
    }
    final keys = map.keys.toList()..sort((a, b) => b.compareTo(a));
    return {for (final k in keys) k: map[k]!};
  }

  Future<void> _applyBulkAndConfirm() async {
    if (_selected.isEmpty) return;
    final count = _selected.length;
    for (final id in _selected) {
      await _txRepo.updateFields(id, categoryId: _bulkCategoryId);
      await _txRepo.confirmDraft(id);
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '已确认 $count 笔${_bulkCategoryId == null ? '' : '（含类别）'}',
        ),
      ),
    );
    setState(() {
      _selected.clear();
      _bulkCategoryId = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('待完善回顾')),
      body: StreamBuilder<List<Transaction>>(
        stream: _txRepo.watchDrafts(),
        builder: (context, snapshot) {
          final drafts = snapshot.data ?? const <Transaction>[];
          if (drafts.isEmpty) {
            return const Center(child: Text('没有待完善的记录'));
          }
          final grouped = _groupByDay(drafts);
          return Column(
            children: [
              _BulkBar(
                selectedCount: _selected.length,
                categoriesStream: _categoryRepo.watchAll(),
                bulkCategoryId: _bulkCategoryId,
                onCategoryChanged: (id) => setState(() => _bulkCategoryId = id),
                onApply: _applyBulkAndConfirm,
              ),
              Expanded(
                child: ListView(
                  children: [
                    for (final entry in grouped.entries) ...[
                      _DayHeader(day: entry.key, count: entry.value.length),
                      for (final draft in entry.value)
                        _DraftTile(
                          draft: draft,
                          stale: _isStale(draft.occurredAt),
                          selected: _selected.contains(draft.id),
                          onToggle: () => setState(() {
                            if (_selected.contains(draft.id)) {
                              _selected.remove(draft.id);
                            } else {
                              _selected.add(draft.id);
                            }
                          }),
                        ),
                    ],
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Bulk action bar: pick one category, apply to all selected, confirm.
class _BulkBar extends StatelessWidget {
  const _BulkBar({
    required this.selectedCount,
    required this.categoriesStream,
    required this.bulkCategoryId,
    required this.onCategoryChanged,
    required this.onApply,
  });

  final int selectedCount;
  final Stream<List<Category>> categoriesStream;
  final String? bulkCategoryId;
  final ValueChanged<String?> onCategoryChanged;
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.m,
        vertical: AppSpacing.s,
      ),
      color: AppColors.surfaceDark,
      child: Row(
        children: [
          Expanded(
            child: StreamBuilder<List<Category>>(
              stream: categoriesStream,
              builder: (context, snapshot) {
                final categories = snapshot.data ?? const <Category>[];
                return DropdownButtonFormField<String>(
                  initialValue: bulkCategoryId,
                  decoration: const InputDecoration(
                    labelText: '批量补类别',
                    isDense: true,
                  ),
                  items: categories
                      .map((c) => DropdownMenuItem(
                            value: c.id,
                            child: Text(c.name),
                          ))
                      .toList(),
                  onChanged: onCategoryChanged,
                );
              },
            ),
          ),
          const SizedBox(width: AppSpacing.m),
          FilledButton(
            onPressed: selectedCount == 0 ? null : onApply,
            child: Text('确认 $selectedCount 笔'),
          ),
        ],
      ),
    );
  }
}

/// One date section header.
class _DayHeader extends StatelessWidget {
  const _DayHeader({required this.day, required this.count});

  final DateTime day;
  final int count;

  static const _weekdays = <String>['周一', '周二', '周三', '周四', '周五', '周六', '周日'];

  @override
  Widget build(BuildContext context) {
    // Manual formatting: intl zh_CN data is not initialized on all platforms.
    final label = '${day.month}月${day.day}日 ${_weekdays[day.weekday - 1]}';
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.m,
        AppSpacing.l,
        AppSpacing.m,
        AppSpacing.s,
      ),
      child: Row(
        children: [
          Text(label, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(width: AppSpacing.s),
          Text('$count 笔', style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

/// One draft row; grey style when older than 7 days (never deleted).
class _DraftTile extends StatelessWidget {
  const _DraftTile({
    required this.draft,
    required this.stale,
    required this.selected,
    required this.onToggle,
  });

  final Transaction draft;
  final bool stale;
  final bool selected;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final display = draft.amountCents % 100 == 0
        ? (draft.amountCents ~/ 100).toString()
        : (draft.amountCents / 100).toStringAsFixed(2);
    final occurred = draft.occurredAt;
    final time =
        '${occurred.hour.toString().padLeft(2, '0')}:${occurred.minute.toString().padLeft(2, '0')}';

    return Opacity(
      opacity: stale ? 0.45 : 1,
      child: ListTile(
        leading: Checkbox(value: selected, onChanged: (_) => onToggle()),
        title: Text(
          '¥$display',
          style: theme.textTheme.titleLarge?.copyWith(
            color: stale ? AppColors.textSecondary : AppColors.textPrimary,
          ),
        ),
        subtitle: Text(
          '$time · ${draft.merchant ?? '未补商户'}',
          style: theme.textTheme.bodySmall,
        ),
        trailing: stale
            ? const Text('超 7 天',
                style: TextStyle(color: AppColors.textSecondary))
            : const Icon(Icons.chevron_right),
        onTap: onToggle,
      ),
    );
  }
}
