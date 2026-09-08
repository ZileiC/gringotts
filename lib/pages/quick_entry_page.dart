import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/app_database.dart';
import '../app/app.dart';
import '../data/repositories/repositories.dart';
import '../domain/models.dart';
import '../domain/seed_ids.dart';
import '../services/smart_prefill.dart';

/// Speed-entry home page: numeric keypad, amount-only, no navigation layer.
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

  TransactionRepository get _txRepo => ref.read(transactionRepositoryProvider);

  int? get _amountCents {
    if (_input.isEmpty) return null;
    final value = int.tryParse(_input);
    if (value == null) return null;
    return value * 100;
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
          if (_input.length < 9) _input += key;
      }
      _updateLunchHint();
    });
  }

  void _updateLunchHint() {
    final amount = _amountCents;
    if (amount == null) {
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

    final categoryId = _selectedCategoryId ?? _timeDefaultCategoryId;
    await _txRepo.create(
      amountCents: amount,
      type: TransactionType.expense,
      categoryId: categoryId,
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
          content: Text('已记 ¥$display'),
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
    final theme = Theme.of(context);
    final amount = _amountCents;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Amount display + prefill category chip.
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '¥ ${_input.isEmpty ? '0' : _input}',
                    style: theme.textTheme.displayLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: -1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _CategoryPrefillRow(
                    selectedCategoryId: _selectedCategoryId,
                    timeDefaultCategoryId: _timeDefaultCategoryId,
                    onCategorySelected: (id) =>
                        setState(() => _selectedCategoryId = id),
                  ),
                ],
              ),
            ),
            // Inline lunch hint (never a dialog).
            if (_lunchHintVisible)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: _LunchHint(
                  onConfirm: () =>
                      setState(() => _selectedCategoryId = categoryIdDining),
                ),
              ),
            // High frequency category chips (recent 14 days).
            _HighFrequencyChipBar(
              selectedCategoryId: _selectedCategoryId,
              onSelected: (id) => setState(() => _selectedCategoryId = id),
            ),
            // Numeric keypad.
            Expanded(child: _Keypad(onKey: _onKey)),
            // Big confirm button.
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: FilledButton(
                  onPressed: amount == null || amount <= 0 ? null : _confirm,
                  style: FilledButton.styleFrom(
                    textStyle: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  child: const Text('记一笔'),
                ),
              ),
            ),
          ],
        ),
      ),
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
          spacing: 8,
          runSpacing: 4,
          children: [
            if (effective != null)
              InputChip(
                label: Text(effective.name),
                selected: true,
                onSelected: (_) => onCategorySelected(null),
              )
            else
              const InputChip(
                label: Text('未选类别'),
                selected: false,
                onSelected: null,
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Row(
          children: [
            Expanded(
              child: Text(
                '这是午餐吗？',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            TextButton(onPressed: onConfirm, child: const Text('是')),
            TextButton(
              onPressed: () {},
              child: const Text('否'),
            ),
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
                padding: const EdgeInsets.symmetric(horizontal: 24),
                itemCount: rankedIds.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
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
                  return FilterChip(
                    label: Text(cat.name),
                    selected: selectedCategoryId == id,
                    onSelected: (_) => onSelected(id),
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
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          for (var row = 0; row < 4; row++)
            Expanded(
              child: Row(
                children: [
                  for (var col = 0; col < 3; col++)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(4),
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
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Center(
          child: Text(
            label,
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
      ),
    );
  }
}
