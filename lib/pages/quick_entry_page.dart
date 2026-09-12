import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/app.dart';
import '../data/app_database.dart';
import '../data/repositories/repositories.dart';
import '../domain/models.dart';
import '../domain/seed_ids.dart';
import '../pages/assets_page.dart';
import '../pages/review_page.dart';
import '../pages/stats_page.dart';
import '../services/budget_engine.dart';
import '../services/smart_parser.dart';
import '../services/smart_prefill.dart';
import '../ui/category_icons.dart';
import '../ui/motion.dart';
import '../ui/tokens.dart';

/// Speed-entry page (T-11, DESIGN_MAIN section 4): B+C hybrid.
///
/// Two inputs (project name + keypad amount), a 3x3 always-visible category
/// grid and a redesigned 4x3 keypad. Secondary page since T-10b: the top bar
/// carries a back action plus the review/assets/stats entries.
/// Record action never blocks on category selection (draft-first workflow).
class QuickEntryPage extends ConsumerStatefulWidget {
  const QuickEntryPage({super.key, this.now});

  /// Injectable clock (tests pin time-of-day prefill deterministically).
  final DateTime Function()? now;

  @override
  ConsumerState<QuickEntryPage> createState() => _QuickEntryPageState();
}

class _QuickEntryPageState extends ConsumerState<QuickEntryPage> {
  final TextEditingController _nameController = TextEditingController();
  String _name = '';
  String _input = '';
  String? _manualCategoryId;
  bool _lunchHintVisible = false;
  bool _isIncome = false;
  final FocusNode _focusNode = FocusNode();

  TransactionRepository get _txRepo => ref.read(transactionRepositoryProvider);

  DateTime _now() => widget.now?.call() ?? DateTime.now();

  /// Amount is parsed with the shared parser so `.5` / `15.5` behave exactly
  /// as they did in the old mixed-input line.
  int? get _amountCents {
    if (_input.isEmpty) return null;
    return SmartParser.parse(_input, history: const []).amountCents;
  }

  bool get _showClear {
    final amount = _amountCents;
    return amount != null && amount > 0;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onKey(String key) {
    setState(() {
      switch (key) {
        case 'backspace':
          if (_input.isNotEmpty) {
            _input = _input.substring(0, _input.length - 1);
          }
        case '.':
          if (!_input.contains('.')) _input += '.';
        default:
          if (_input.length < 10) _input += key;
      }
      _updateLunchHint();
    });
  }

  void _clearAmount() {
    setState(() {
      _input = '';
      _lunchHintVisible = false;
    });
  }

  void _updateLunchHint() {
    final amount = _amountCents;
    if (amount == null || _isIncome) {
      _lunchHintVisible = false;
      return;
    }
    _lunchHintVisible = LunchPattern.matches(
      now: _now(),
      amountCents: amount,
    );
  }

  /// Effective category for the current inputs (see [QuickEntryDefaults]).
  String? _effectiveCategoryId(
    List<Transaction> transactions,
    DateTime now,
  ) {
    final history = _historyEntries(transactions);
    final trimmedName = _name.trim();
    final nameSuggestion = trimmedName.isEmpty
        ? null
        : SmartParser.parse(trimmedName, history: history).categoryId;
    final ranked = HighFrequencyCategories.ranked(
      transactions.map((t) => (categoryId: t.categoryId, occurredAt: t.occurredAt)),
      now: now,
    );
    return QuickEntryDefaults.resolve(
      explicitId: _manualCategoryId,
      nameSuggestionId: nameSuggestion,
      // Income mode carries no time-of-day prefill (management addendum).
      timeDefaultId: _isIncome ? null : TimeOfDayDefaults.defaultCategoryId(now),
      topFrequencyId: ranked.isEmpty ? null : ranked.first,
    );
  }

  List<MerchantHistoryEntry> _historyEntries(List<Transaction> transactions) {
    final seen = <String>{};
    final entries = <MerchantHistoryEntry>[];
    for (final t in transactions) {
      final merchant = t.merchant;
      if (merchant == null || merchant.isEmpty) continue;
      if (seen.add(merchant)) {
        entries.add(MerchantHistoryEntry(merchant, t.categoryId));
      }
    }
    return entries;
  }

  Future<void> _confirm(String? categoryId) async {
    final amount = _amountCents;
    if (amount == null || amount <= 0) return;

    final trimmedName = _name.trim();
    await _txRepo.create(
      amountCents: amount,
      type: _isIncome ? TransactionType.income : TransactionType.expense,
      categoryId: categoryId,
      merchant: trimmedName.isEmpty ? null : trimmedName,
      occurredAt: _now(),
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
          // Floating with a bottom inset so it never covers the confirm key.
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(
            AppSpacing.m,
            0,
            AppSpacing.m,
            AppSpacing.snackBarCtaInset,
          ),
        ),
      );
    }
    setState(() {
      _input = '';
      _name = '';
      _nameController.clear();
      _manualCategoryId = null;
      _lunchHintVisible = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return KeyboardListener(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: _handleKeyEvent,
      child: Scaffold(
        body: SafeArea(
          child: StreamBuilder<List<Transaction>>(
            stream: ref.watch(transactionRepositoryProvider).watchAll(),
            builder: (context, txSnapshot) {
              final transactions = txSnapshot.data ?? const <Transaction>[];
              return StreamBuilder<BudgetMonth?>(
                stream: ref
                    .watch(budgetRepositoryProvider)
                    .watchByMonth(BudgetEngine.monthKey(_now())),
                builder: (context, budgetSnapshot) {
                  final budget = budgetSnapshot.data;
                  return StreamBuilder<List<Category>>(
                    stream: ref.watch(categoryRepositoryProvider).watchAll(),
                    builder: (context, catSnapshot) {
                      final categories = catSnapshot.data ?? const <Category>[];
                      return _buildBody(
                        context,
                        transactions,
                        budget,
                        categories,
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    List<Transaction> transactions,
    BudgetMonth? budget,
    List<Category> categories,
  ) {
    final now = _now();
    final amount = _amountCents;
    final effectiveId = _effectiveCategoryId(transactions, now);

    return Column(
      children: [
        _TopBar(
          isIncome: _isIncome,
          onModeChanged: (income) => setState(() {
            _isIncome = income;
            _updateLunchHint();
          }),
        ),
        Expanded(
          child: SingleChildScrollView(
            physics: const InertialScrollPhysics(),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.entryPagePadH,
              vertical: AppSpacing.entryPagePadV,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _NameField(
                  controller: _nameController,
                  onChanged: (value) => setState(() => _name = value),
                ),
                const SizedBox(height: AppSpacing.s),
                _AmountRow(
                  input: _input,
                  showClear: _showClear,
                  onClear: _clearAmount,
                ),
                const SizedBox(height: AppSpacing.s),
                if (budget != null)
                  _BudgetLinkRow(
                    budget: budget,
                    transactions: transactions,
                    amountCents: amount ?? 0,
                    now: now,
                  ),
                if (budget != null) const SizedBox(height: AppSpacing.s),
                _CategoryGrid(
                  categories: categories,
                  selectedId: effectiveId,
                  onSelected: (id) =>
                      setState(() => _manualCategoryId = id),
                ),
                if (_lunchHintVisible)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.s),
                    child: _LunchHint(
                      onConfirm: () => setState(
                          () => _manualCategoryId = categoryIdDining),
                    ),
                  ),
                const SizedBox(height: AppSpacing.keypadVertMargin),
                _Keypad(onKey: _onKey),
                const SizedBox(height: AppSpacing.keypadVertMargin),
              ],
            ),
          ),
        ),
        _ConfirmBar(
          enabled: amount != null && amount > 0,
          onPressed: () => _confirm(effectiveId),
        ),
      ],
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
    } else if (key == LogicalKeyboardKey.period ||
        key == LogicalKeyboardKey.numpadDecimal) {
      _onKey('.');
    } else if (key == LogicalKeyboardKey.backspace) {
      _onKey('backspace');
    } else if (key == LogicalKeyboardKey.escape) {
      _clearAmount();
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
      _confirm(_effectiveCategoryId(
        const <Transaction>[],
        _now(),
      ));
    }
  }
}

/// Top bar: back + title + expense/income switch.
class _TopBar extends StatelessWidget {
  const _TopBar({required this.isIncome, required this.onModeChanged});

  final bool isIncome;
  final ValueChanged<bool> onModeChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.s, 15, AppSpacing.m, 11,
      ),
      child: Row(
        children: [
          IconButton(
            key: const Key('quick_back'),
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.arrow_back),
            tooltip: '返回',
          ),
          Text('记一笔', style: Theme.of(context).textTheme.titleLarge),
          const Spacer(),
          // T-10b must-keep entries; compact so the row still fits a phone.
          _CompactEntry(
            buttonKey: const Key('quick_review'),
            icon: Icons.history,
            tooltip: '回顾',
            builder: (_) => const ReviewPage(),
          ),
          _CompactEntry(
            buttonKey: const Key('quick_assets'),
            icon: Icons.inventory_2,
            tooltip: '资产',
            builder: (_) => const AssetsPage(),
          ),
          _CompactEntry(
            buttonKey: const Key('quick_stats'),
            icon: Icons.bar_chart,
            tooltip: '统计',
            builder: (_) => const StatsPage(),
          ),
          const SizedBox(width: AppSpacing.xs),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: false, label: Text('支出')),
              ButtonSegment(value: true, label: Text('收入')),
            ],
            selected: {isIncome},
            onSelectionChanged: (selection) => onModeChanged(selection.first),
            style: const ButtonStyle(
              visualDensity: VisualDensity.compact,
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact icon entry to the secondary pages (top-bar real estate is tight).
class _CompactEntry extends StatelessWidget {
  const _CompactEntry({
    required this.buttonKey,
    required this.icon,
    required this.tooltip,
    required this.builder,
  });

  final Key buttonKey;
  final IconData icon;
  final String tooltip;
  final WidgetBuilder builder;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      key: buttonKey,
      onPressed: () => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: builder),
      ),
      icon: Icon(icon, size: 20),
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
    );
  }
}

/// Project-name input (the parser's new home; amount lives on the keypad).
class _NameField extends StatelessWidget {
  const _NameField({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: AppSpacing.entryNameHeight,
      child: TextField(
        key: const Key('entry_name'),
        controller: controller,
        onChanged: onChanged,
        textInputAction: TextInputAction.done,
        style: Theme.of(context).textTheme.bodyLarge,
        decoration: const InputDecoration(
          hintText: '项目名称 · 如 瑞幸咖啡',
          isDense: true,
          contentPadding: EdgeInsets.symmetric(
            horizontal: AppSpacing.m,
            vertical: AppSpacing.s,
          ),
        ),
      ),
    );
  }
}

/// Amount display (Playfair 600 / 42) + the "clear" text action.
class _AmountRow extends StatelessWidget {
  const _AmountRow({
    required this.input,
    required this.showClear,
    required this.onClear,
  });

  final String input;
  final bool showClear;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Text(
            '¥ ${input.isEmpty ? '0' : input}',
            style: const TextStyle(
              fontFamily: 'PlayfairDisplay',
              fontWeight: FontWeight.w600,
              fontSize: AppFont.amountEntry,
              color: AppColors.ink,
              fontFeatures: AppFont.tabularFigures,
            ),
          ),
        ),
        if (showClear)
          TextButton(
            key: const Key('entry_clear'),
            onPressed: onClear,
            child: Text(
              '清空',
              style: TextStyle(
                fontSize: AppFont.caption,
                color: AppColors.inkSecondary,
              ),
            ),
          ),
      ],
    );
  }
}

/// Budget link: what today's allowance becomes once this amount is recorded.
class _BudgetLinkRow extends StatelessWidget {
  const _BudgetLinkRow({
    required this.budget,
    required this.transactions,
    required this.amountCents,
    required this.now,
  });

  final BudgetMonth budget;
  final List<Transaction> transactions;
  final int amountCents;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final snapshot = BudgetEngine.compute(
      budget: budget,
      transactions: transactions,
      now: now,
    );
    final remaining = snapshot.remainingCents;
    if (remaining == null) return const SizedBox.shrink();
    final after = BudgetEngine.liveDailyCents(
      remainingCents: remaining - amountCents,
      remainingDays: snapshot.remainingDays,
    );
    return Container(
      padding: const EdgeInsets.symmetric(
        vertical: AppSpacing.linkRowPadding,
      ),
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: AppColors.hairline),
          bottom: BorderSide(color: AppColors.hairline),
        ),
      ),
      child: Text.rich(
        TextSpan(
          style: const TextStyle(
            fontSize: AppFont.caption + 1,
            color: AppColors.inkSecondary,
          ),
          children: [
            const TextSpan(text: '记这笔后，今天还能花 '),
            TextSpan(
              text: '¥${_money(after)}',
              style: const TextStyle(
                color: AppColors.goldAccent,
                fontWeight: FontWeight.w600,
                fontFeatures: AppFont.tabularFigures,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Fixed 3x3 category grid: all nine seeds visible, never horizontally scrolls.
class _CategoryGrid extends StatelessWidget {
  const _CategoryGrid({
    required this.categories,
    required this.selectedId,
    required this.onSelected,
  });

  final List<Category> categories;
  final String? selectedId;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const Key('category_grid'),
      children: [
        for (var row = 0; row < 3; row++) ...[
          if (row > 0) const SizedBox(height: AppSpacing.categoryGap),
          Row(
            children: [
              for (var col = 0; col < 3; col++) ...[
                if (col > 0) const SizedBox(width: AppSpacing.categoryGap),
                Expanded(
                  child: _CategoryCell(
                    seed: _seedCategories[row * 3 + col],
                    categories: categories,
                    selected: selectedId == _seedCategories[row * 3 + col].id,
                    onTap: () =>
                        onSelected(_seedCategories[row * 3 + col].id),
                  ),
                ),
              ],
            ],
          ),
        ],
      ],
    );
  }
}

/// One grid cell: icon + label; selected = gold border + faint gold fill.
class _CategoryCell extends StatelessWidget {
  const _CategoryCell({
    required this.seed,
    required this.categories,
    required this.selected,
    required this.onTap,
  });

  final _SeedCategory seed;
  final List<Category> categories;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final animationsDisabled = MediaQuery.disableAnimationsOf(context);
    String name = seed.name;
    String iconName = seed.icon;
    for (final c in categories) {
      if (c.id == seed.id) {
        name = c.name;
        iconName = c.icon ?? seed.icon;
        break;
      }
    }
    final color = selected ? AppColors.goldAccent : AppColors.inkSecondary;
    return TouchedScale(
      pressedScale: 0.97,
      onTap: onTap,
      child: AnimatedContainer(
        key: Key('category_cell_${seed.id}'),
        duration: animationsDisabled
            ? Duration.zero
            : const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        height: AppSpacing.categoryCellHeight,
        decoration: BoxDecoration(
          color: selected ? AppColors.goldContainer : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.m),
          border: Border.all(
            color: selected ? AppColors.goldAccent : AppColors.hairline,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              CategoryIcons.forName(iconName),
              size: AppFont.categoryIcon,
              color: color,
            ),
            const SizedBox(height: 2),
            Text(
              name,
              style: TextStyle(
                fontSize: AppFont.categoryLabel,
                color: color,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 4x3 keypad: 7 8 9 / 4 5 6 / 1 2 3 / . 0 ⌫ (no C key).
class _Keypad extends StatelessWidget {
  const _Keypad({required this.onKey});

  final ValueChanged<String> onKey;

  static const List<List<String>> _rows = <List<String>>[
    <String>['7', '8', '9'],
    <String>['4', '5', '6'],
    <String>['1', '2', '3'],
    <String>['.', '0', 'backspace'],
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var row = 0; row < _rows.length; row++) ...[
          if (row > 0) const SizedBox(height: AppSpacing.keypadGapY),
          Row(
            children: [
              for (var col = 0; col < 3; col++) ...[
                if (col > 0) const SizedBox(width: AppSpacing.keypadGapX),
                Expanded(
                  child: _KeyButton(
                    value: _rows[row][col],
                    onTap: () => onKey(_rows[row][col]),
                  ),
                ),
              ],
            ],
          ),
        ],
      ],
    );
  }
}

/// One key. Numbers are filled elevated (no border); `.` / backspace are
/// transparent with a hairline border - the material hierarchy that keeps the
/// keypad from reading as twelve equal blocks.
class _KeyButton extends StatelessWidget {
  const _KeyButton({required this.value, required this.onTap});

  final String value;
  final VoidCallback onTap;

  bool get _isDigit => value != '.' && value != 'backspace';

  @override
  Widget build(BuildContext context) {
    final label = value == 'backspace' ? '⌫' : value;
    return TouchedScale(
      pressedScale: 0.97,
      pressDuration: const Duration(milliseconds: 120),
      onPressHaptic: () => HapticFeedback.selectionClick(),
      onTap: onTap,
      child: Container(
        key: Key('key_$value'),
        height: 56,
        decoration: BoxDecoration(
          color: _isDigit ? AppColors.elevated : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.key),
          border: _isDigit
              ? null
              : Border.all(color: AppColors.hairline),
        ),
        child: Center(
          child: Text(
            label,
            style: _isDigit
                ? const TextStyle(
                    fontFamily: 'PlayfairDisplay',
                    fontWeight: FontWeight.w600,
                    fontSize: AppFont.keyNumber,
                    color: AppColors.ink,
                    fontFeatures: AppFont.tabularFigures,
                  )
                : const TextStyle(
                    fontSize: AppFont.keySymbol,
                    color: AppColors.inkSecondary,
                  ),
          ),
        ),
      ),
    );
  }
}

/// Confirm action: gold hairline + faint gold fill + gold text (no gradient).
class _ConfirmBar extends StatelessWidget {
  const _ConfirmBar({required this.enabled, required this.onPressed});

  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.entryPagePadH, 0, AppSpacing.entryPagePadH, AppSpacing.s,
      ),
      child: SizedBox(
        key: const Key('confirm_cta'),
        width: double.infinity,
        height: AppSpacing.entryConfirmHeight,
        child: TouchedScale(
          pressedScale: 0.96,
          onPressHaptic: () => HapticFeedback.mediumImpact(),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.goldContainer,
              borderRadius: BorderRadius.circular(AppRadius.l),
              border: Border.all(color: AppColors.goldDeep),
            ),
            child: TextButton(
              onPressed: enabled ? onPressed : null,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.goldAccent,
                disabledForegroundColor: AppColors.inkSecondary,
                textStyle: const TextStyle(
                  fontSize: AppFont.title,
                  fontWeight: FontWeight.w600,
                ),
              ),
              child: const Text('记一笔'),
            ),
          ),
        ),
      ),
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

/// Fixed seed order (never re-ordered by frequency - muscle memory).
class _SeedCategory {
  const _SeedCategory(this.id, this.name, this.icon);

  final String id;
  final String name;
  final String icon;
}

const List<_SeedCategory> _seedCategories = <_SeedCategory>[
  _SeedCategory(categoryIdDining, '餐饮', 'restaurant'),
  _SeedCategory(categoryIdTransport, '交通', 'commute'),
  _SeedCategory(categoryIdShopping, '购物', 'shopping_bag'),
  _SeedCategory(categoryIdHousing, '居住', 'home'),
  _SeedCategory(categoryIdEntertainment, '娱乐', 'sports_esports'),
  _SeedCategory(categoryIdStudy, '学习', 'school'),
  _SeedCategory(categoryIdMedical, '医疗', 'medical_services'),
  _SeedCategory(categoryIdGift, '人情', 'redeem'),
  _SeedCategory(categoryIdOther, '其他', 'category'),
];

/// Formats integer cents as yuan, trimming trailing zeros (70004 -> 700.04).
String _money(int cents) {
  final abs = cents.abs();
  final String text;
  if (abs % 100 == 0) {
    text = (abs ~/ 100).toString();
  } else if (abs % 10 == 0) {
    text = (abs / 100).toStringAsFixed(1);
  } else {
    text = (abs / 100).toStringAsFixed(2);
  }
  return text;
}
