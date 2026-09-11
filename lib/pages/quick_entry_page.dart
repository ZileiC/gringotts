import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/app.dart';
import '../data/app_database.dart';
import '../data/repositories/repositories.dart';
import '../domain/models.dart';
import '../domain/seed_ids.dart';
import '../pages/assets_page.dart';
import '../pages/stats_page.dart';
import '../pages/review_page.dart';
import '../services/smart_parser.dart';
import '../services/smart_prefill.dart';
import '../ui/motion.dart';
import '../ui/tokens.dart';

/// Speed-entry home page: numeric keypad + mixed input, no navigation layer.
///
/// Record action never blocks on category selection (draft-first workflow).
class QuickEntryPage extends ConsumerStatefulWidget {
  const QuickEntryPage({super.key});

  @override
  ConsumerState<QuickEntryPage> createState() => _QuickEntryPageState();
}

class _QuickEntryPageState extends ConsumerState<QuickEntryPage> {
  String _input = '';
  String? _selectedCategoryId;
  String? _timeDefaultCategoryId;
  bool _lunchHintVisible = false;
  bool _isIncome = false;
  /// Bumped on every confirm so the CTA sheen sweeps exactly once per record.
  int _sheenTick = 0;
  final FocusNode _focusNode = FocusNode();

  TransactionRepository get _txRepo => ref.read(transactionRepositoryProvider);
  int? get _amountCents {
    if (_input.isEmpty) return null;
    // Mixed-input form: run the local parser so `.5`, `瑞幸 15` etc. work.
    final parsed = SmartParser.parse(_input, history: const []);
    return parsed.amountCents;
  }

  SmartParseResult get _mixedParse =>
      SmartParser.parse(_input, history: const []);

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _timeDefaultCategoryId =
        TimeOfDayDefaults.defaultCategoryId(DateTime.now());
    _updateLunchHint();
  }

  void _onKey(String key) {
    setState(() {
      switch (key) {
        case 'backspace':
          if (_input.isNotEmpty) {
            _input = _input.substring(0, _input.length - 1);
          }
        case 'C':
          _input = '';
          _selectedCategoryId = null;
          _lunchHintVisible = false;
        default:
          if (_input.length < 30) _input += key;
      }
      _updateLunchHint();
    });
  }

  void _updateLunchHint() {
    final amount = _amountCents;
    if (amount == null || _isIncome) {
      _lunchHintVisible = false;
      return;
    }
    _lunchHintVisible = LunchPattern.matches(
      now: DateTime.now(),
      amountCents: amount,
    );
  }

  Future<void> _confirm() async {
    final amount = _amountCents;
    if (amount == null || amount <= 0) return;

    // One-shot sheen sweep on the confirm CTA (DESIGN_T09 section 4).
    setState(() => _sheenTick++);

    final parse = _mixedParse;
    // Income mode: no time-of-day prefill, no lunch pattern (management
    // addendum). Category may still be picked via chips.
    final categoryId =
        _isIncome ? _selectedCategoryId : (_selectedCategoryId ?? _timeDefaultCategoryId);

    await _txRepo.create(
      amountCents: amount,
      type: _isIncome ? TransactionType.income : TransactionType.expense,
      categoryId: categoryId,
      merchant: parse.merchant,
      occurredAt: DateTime.now(),
      isDraft: true,
      source: TransactionSource.manual,
    );

    if (mounted) {
      final display = amount % 100 == 0
          ? (amount ~/ 100).toString()
          : (amount / 100).toStringAsFixed(2);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${_isIncome ? '已入账' : '已记'} ¥$display'),
          duration: const Duration(seconds: 1),
        ),
      );
    }
    setState(() {
      _input = '';
      _selectedCategoryId = null;
      _lunchHintVisible = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return KeyboardListener(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: _handleKeyEvent,
      child: _buildScaffold(context),
    );
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return;
    final key = event.logicalKey;
    final digitKeys = <LogicalKeyboardKey, String>{
      LogicalKeyboardKey.digit0: '0',
      LogicalKeyboardKey.digit1: '1',
      LogicalKeyboardKey.digit2: '2',
      LogicalKeyboardKey.digit3: '3',
      LogicalKeyboardKey.digit4: '4',
      LogicalKeyboardKey.digit5: '5',
      LogicalKeyboardKey.digit6: '6',
      LogicalKeyboardKey.digit7: '7',
      LogicalKeyboardKey.digit8: '8',
      LogicalKeyboardKey.digit9: '9',
      LogicalKeyboardKey.numpad0: '0',
      LogicalKeyboardKey.numpad1: '1',
      LogicalKeyboardKey.numpad2: '2',
      LogicalKeyboardKey.numpad3: '3',
      LogicalKeyboardKey.numpad4: '4',
      LogicalKeyboardKey.numpad5: '5',
      LogicalKeyboardKey.numpad6: '6',
      LogicalKeyboardKey.numpad7: '7',
      LogicalKeyboardKey.numpad8: '8',
      LogicalKeyboardKey.numpad9: '9',
    };
    if (digitKeys.containsKey(key)) {
      _onKey(digitKeys[key]!);
    } else if (key == LogicalKeyboardKey.backspace) {
      _onKey('backspace');
    } else if (key == LogicalKeyboardKey.escape) {
      _onKey('C');
    } else if (key == LogicalKeyboardKey.f3) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const StatsPage()),
      );
    } else if (key == LogicalKeyboardKey.f2) {
      // Debug navigation shortcut (Windows preview only).
      Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const AssetsPage()),
      );
    } else if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter) {
      _confirm();
    }
  }

  Widget _buildScaffold(BuildContext context) {
    final theme = Theme.of(context);
    final amount = _amountCents;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Top row: badge + review entry.
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.m, AppSpacing.s, AppSpacing.m, 0,
              ),
              child: Row(
                children: [
                  const _TodayDraftBadge(),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const ReviewPage(),
                      ),
                    ),
                    icon: const Icon(Icons.history),
                    label: const Text('回顾'),
                  ),
                  TextButton.icon(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const AssetsPage(),
                      ),
                    ),
                    icon: const Icon(Icons.inventory_2),
                    label: const Text('资产'),
                  ),
                  TextButton.icon(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const StatsPage(),
                      ),
                    ),
                    icon: const Icon(Icons.bar_chart),
                    label: const Text('统计'),
                  ),
                ],
              ),
            ),
            // Amount display + mixed input field + mode toggle.
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.m, AppSpacing.m, AppSpacing.m, AppSpacing.s,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Brand wordmark: the only serif moment on this page.
                  ShaderMask(
                    shaderCallback: (bounds) => const LinearGradient(
                      colors: [AppColors.goldAccent, AppColors.goldDeep],
                    ).createShader(bounds),
                    child: const Text(
                      'GRINGOTTS',
                      style: TextStyle(
                        fontFamily: 'PlayfairDisplay',
                        fontWeight: FontWeight.w600,
                        fontSize: AppFont.caption + 2,
                        letterSpacing: 1.6,
                        color: AppColors.goldAccent,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '¥ ${_input.isEmpty ? '0' : _input}',
                        style: theme.textTheme.displayLarge,
                      ),
                      const Spacer(),
                      SegmentedButton<bool>(
                        segments: const [
                          ButtonSegment(value: false, label: Text('支出')),
                          ButtonSegment(value: true, label: Text('收入')),
                        ],
                        selected: {_isIncome},
                        onSelectionChanged: (selection) => setState(() {
                          _isIncome = selection.first;
                          _updateLunchHint();
                        }),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.m),
                  TextField(
                    decoration: const InputDecoration(
                      hintText: '混合输入：瑞幸 15 / 15.5 午餐 / .5',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: (value) => setState(() {
                      _input = value;
                      _updateLunchHint();
                    }),
                  ),
                  const SizedBox(height: AppSpacing.s),
                  _CategoryPrefillRow(
                    selectedCategoryId: _selectedCategoryId,
                    timeDefaultCategoryId:
                        _isIncome ? null : _timeDefaultCategoryId,
                    onCategorySelected: (id) =>
                        setState(() => _selectedCategoryId = id),
                  ),
                ],
              ),
            ),
            if (_lunchHintVisible)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.m),
                child: _LunchHint(
                  onConfirm: () =>
                      setState(() => _selectedCategoryId = categoryIdDining),
                ),
              ),
            _HighFrequencyChipBar(
              selectedCategoryId: _selectedCategoryId,
              onSelected: (id) => setState(() => _selectedCategoryId = id),
            ),
            Expanded(child: _Keypad(onKey: _onKey)),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.m),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: TouchedScale(
                  pressedScale: 0.96,
                  onPressHaptic: () => HapticFeedback.mediumImpact(),
                  child: SheenSweep(
                    trigger: _sheenTick,
                    child: DecoratedBox(
                  decoration: const BoxDecoration(
                    borderRadius: BorderRadius.all(Radius.circular(AppRadius.m)),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [AppColors.goldAccent, AppColors.goldDeep],
                    ),
                  ),
                  child: TextButton(
                    onPressed: amount == null || amount <= 0 ? null : _confirm,
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.onGold,
                      textStyle: TextStyle(
                        fontSize: AppFont.title,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    child: const Text('记一笔'),
                  ),
                ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Home badge: "今日 N 笔待完善" - zero drafts renders nothing.
class _TodayDraftBadge extends ConsumerWidget {
  const _TodayDraftBadge();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final txRepo = ref.watch(transactionRepositoryProvider);
    return StreamBuilder<int>(
      stream: txRepo.watchTodayDraftCount(),
      builder: (context, snapshot) {
        final count = snapshot.data ?? 0;
        if (count == 0) return const SizedBox.shrink();
        return Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.m,
            vertical: AppSpacing.xs,
          ),
          decoration: BoxDecoration(
            color: AppColors.goldContainer,
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          child: Text(
            '今日 $count 笔待完善',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        );
      },
    );
  }
}

/// Row showing the time-of-day default category as a selectable chip.
class _CategoryPrefillRow extends ConsumerWidget {
  const _CategoryPrefillRow({
    required this.selectedCategoryId,
    required this.timeDefaultCategoryId,
    required this.onCategorySelected,
  });

  final String? selectedCategoryId;
  final String? timeDefaultCategoryId;
  final ValueChanged<String?> onCategorySelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoryRepo = ref.watch(categoryRepositoryProvider);
    return StreamBuilder<List<Category>>(
      stream: categoryRepo.watchAll(),
      builder: (context, snapshot) {
        final categories = snapshot.data ?? const <Category>[];
        final effectiveId = selectedCategoryId ?? timeDefaultCategoryId;
        Category? effective;
        for (final c in categories) {
          if (c.id == effectiveId) {
            effective = c;
            break;
          }
        }

        return Wrap(
          spacing: AppSpacing.s,
          runSpacing: AppSpacing.xs,
          children: [
            if (effective != null)
              MotionChip(
                label: effective.name,
                selected: true,
                onTap: () => onCategorySelected(null),
              )
            else
              MotionChip(
                label: '未选类别',
                selected: false,
              ),
          ],
        );
      },
    );
  }
}

/// Inline lunch pattern hint with one-tap confirm.
class _LunchHint extends StatelessWidget {
  const _LunchHint({required this.onConfirm});

  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.m, vertical: AppSpacing.xs,
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                '这是午餐吗？',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            TextButton(onPressed: onConfirm, child: const Text('是')),
            TextButton(onPressed: () {}, child: const Text('否')),
          ],
        ),
      ),
    );
  }
}

/// Horizontal scrollable list of the most frequent recent categories.
class _HighFrequencyChipBar extends ConsumerWidget {
  const _HighFrequencyChipBar({
    required this.selectedCategoryId,
    required this.onSelected,
  });

  final String? selectedCategoryId;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final txRepo = ref.watch(transactionRepositoryProvider);
    final categoryRepo = ref.watch(categoryRepositoryProvider);

    return StreamBuilder<List<Transaction>>(
      stream: txRepo.watchRecent(windowDays: 14),
      builder: (context, txSnapshot) {
        return StreamBuilder<List<Category>>(
          stream: categoryRepo.watchAll(),
          builder: (context, catSnapshot) {
            final transactions = txSnapshot.data ?? const <Transaction>[];
            final categories = catSnapshot.data ?? const <Category>[];
            final rankedIds = HighFrequencyCategories.ranked(transactions
                .map((t) => (
                      categoryId: t.categoryId,
                      occurredAt: t.occurredAt,
                    ))
                .toList());

            if (rankedIds.isEmpty) return const SizedBox.shrink();

            return SizedBox(
              height: 48,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.m),
                itemCount: rankedIds.length,
                separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.s),
                itemBuilder: (context, index) {
                  final id = rankedIds[index];
                  Category? cat;
                  for (final c in categories) {
                    if (c.id == id) {
                      cat = c;
                      break;
                    }
                  }
                  if (cat == null) return const SizedBox.shrink();
                  return MotionChip(
                    label: cat.name,
                    selected: selectedCategoryId == id,
                    onTap: () => onSelected(id),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}

/// Numeric keypad grid (0-9, backspace, clear).
class _Keypad extends StatelessWidget {
  const _Keypad({required this.onKey});

  final ValueChanged<String> onKey;

  static const _keys = <String>[
    '1', '2', '3',
    '4', '5', '6',
    '7', '8', '9',
    'C', '0', 'backspace',
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.m),
      child: Column(
        children: [
          for (var row = 0; row < 4; row++)
            Expanded(
              child: Row(
                children: [
                  for (var col = 0; col < 3; col++)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.xs),
                        child: _KeyCap(
                          label: switch (_keys[row * 3 + col]) {
                            'backspace' => '⌫',
                            'C' => 'C',
                            final k => k,
                          },
                          onTap: () => onKey(_keys[row * 3 + col]),
                        ),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// One key on the keypad.
class _KeyCap extends StatelessWidget {
  const _KeyCap({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TouchedScale(
      onTap: onTap,
      pressedScale: 0.97,
      pressDuration: const Duration(milliseconds: 120),
      onPressHaptic: () => HapticFeedback.selectionClick(),
      child: Material(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(AppRadius.m),
        child: Center(
          child: Text(
            label,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontSize: AppFont.keypad,
            ),
          ),
        ),
      ),
    );
  }
}
