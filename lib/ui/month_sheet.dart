/// Shared month calendar sheet (DESIGN_MAIN 3.1 / T-21 part 4).
///
/// One component shared by the analysis page and the statistics page: reuse
/// the home calendar sheet, do not build a second one. The selected month lives
/// in the shared selectedMonthProvider, so the ledger page syncs as well.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'motion.dart';
import 'tokens.dart';
/// Opens the shared month calendar sheet; the selection updates the shared
/// selectedMonthProvider so analysis / ledger / stats stay in sync.
Future<void> showMonthSheet(
  BuildContext context, {
  required DateTime selected,
  required ValueChanged<DateTime> onSelected,
  Key sheetKey = const Key('home_month_sheet'),
  DateTime? today,
}) async {
  final now = today ?? DateTime.now();
  final reduceMotion = MediaQuery.disableAnimationsOf(context);

  if (!reduceMotion) {
    await showModalBottomSheet<void>(
      context: context,
      // ~342dp of fixed content: let the sheet size to content instead of the
      // default 9/16 cap (T-13a part 4).
      isScrollControlled: true,
      builder: (_) => MonthSheet(
        sheetKey: sheetKey,
        selected: selected,
        today: now,
        onSelected: onSelected,
      ),
    );
    return;
  }
  // reduce-motion: a fade replaces the vertical displacement.
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
        child: MonthSheet(
          sheetKey: sheetKey,
          selected: selected,
          today: now,
          onSelected: onSelected,
        ),
      ),
    ),
    transitionBuilder: (_, animation, _, child) =>
        FadeTransition(opacity: animation, child: child),
  );
}
/// Month calendar sheet (DESIGN_MAIN §3.1): year row + a 3x4 month grid.
///
/// No gradient, no shadow - flat overlay surface with hairline borders, in the
/// same visual language as the category grid. Future months are disabled.
class MonthSheet extends StatefulWidget {
  const MonthSheet({
    super.key,
    required this.selected,
    required this.today,
    required this.onSelected,
    this.sheetKey = const Key('home_month_sheet'),
  });

  /// The month currently displayed on the home page (highlighted in the grid).
  final DateTime selected;

  /// Real "now" (future months and the next year are disabled against it).
  final DateTime today;

  final ValueChanged<DateTime> onSelected;

  final Key sheetKey;

  @override
  State<MonthSheet> createState() => MonthSheetState();
}

class MonthSheetState extends State<MonthSheet> {
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
    final mq = MediaQuery.of(context);
    final bottomInset = mq.viewPadding.bottom;
    // Fixed content: handle (4) + gap + year row (48) + gap + 4 rows of 52dp
    // cells = 310dp (342dp with the sheet's own padding). A landscape phone, a
    // short desktop window or a split view can be shorter than that, so the
    // content scrolls inside the sheet instead of overflowing (T-13a part 4,
    // the boundary inherited from T-12c). The cell height stays 52 - above the
    // 48dp touch minimum - and every month stays reachable.
    final contentMaxHeight = math.max(
      0.0,
      mq.size.height -
          mq.viewPadding.top -
          AppSpacing.s -
          AppSpacing.l -
          bottomInset,
    );
    return Container(
      key: widget.sheetKey,
      decoration: const BoxDecoration(
        color: AppColors.overlay,
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      padding: EdgeInsets.fromLTRB(
        AppSpacing.m, AppSpacing.s, AppSpacing.m, AppSpacing.l + bottomInset,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: contentMaxHeight),
        child: SingleChildScrollView(
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
                      if (col > 0)
                        const SizedBox(width: AppSpacing.categoryGap),
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
        ),
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

