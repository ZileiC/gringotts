import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../ui/motion.dart';
import '../ui/tokens.dart';
import 'assets_page.dart';
import 'home_page.dart';
import 'quick_entry_page.dart';
import 'stats_page.dart';

/// Root shell (T-12c): three peer tabs plus the primary 记一笔 action.
///
/// IA ruling (2026-09-12): analysis / assets / stats are siblings at the top
/// level, switched through the bottom tab bar without pushing routes. The gold
/// 记一笔 button sits above the tab row and pushes the speed-entry page, which
/// is the analysis page's child (back returns to analysis).
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  void _openQuickEntry() {
    // Ruling (2026-09-13): the speed-entry page is the analysis page's child,
    // so returning from it must land on analysis even when 记一笔 was tapped
    // from the assets or statistics tab.
    setState(() => _index = 0);
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const QuickEntryPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // IndexedStack keeps each peer tab's scroll position and state alive;
      // switching is a plain index change, never a navigation push.
      body: IndexedStack(
        index: _index,
        children: const [HomePage(), AssetsPage(), StatsPage()],
      ),
      bottomNavigationBar: _BottomTabs(
        index: _index,
        onSelect: (i) => setState(() => _index = i),
        onRecord: _openQuickEntry,
      ),
    );
  }
}

/// Bottom bar: the centered gold 记一笔 button stacked above the three tabs.
class _BottomTabs extends StatelessWidget {
  const _BottomTabs({
    required this.index,
    required this.onSelect,
    required this.onRecord,
  });

  final int index;
  final ValueChanged<int> onSelect;
  final VoidCallback onRecord;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.canvas,
        border: Border(top: BorderSide(color: AppColors.hairline)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Primary action rides above the tab row (T-12c Part A).
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.m, AppSpacing.s, AppSpacing.m, AppSpacing.s,
              ),
              child: SizedBox(
                key: const Key('home_record_cta'),
                height: 52,
                child: TouchedScale(
                  pressedScale: 0.96,
                  onPressHaptic: () => HapticFeedback.mediumImpact(),
                  child: DecoratedBox(
                    decoration: const BoxDecoration(
                      borderRadius:
                          BorderRadius.all(Radius.circular(AppRadius.m)),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [AppColors.goldAccent, AppColors.goldDeep],
                      ),
                    ),
                    child: TextButton(
                      onPressed: onRecord,
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.onGold,
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
            ),
            Row(
              children: [
                for (var i = 0; i < _tabs.length; i++)
                  Expanded(
                    child: _TabButton(
                      tab: _tabs[i],
                      selected: index == i,
                      onTap: () => onSelect(i),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
          ],
        ),
      ),
    );
  }
}

class _TabSpec {
  const _TabSpec(this.key, this.label, this.icon);

  final Key key;
  final String label;
  final IconData icon;
}

const List<_TabSpec> _tabs = <_TabSpec>[
  _TabSpec(Key('tab_home'), '分析', Icons.insights),
  _TabSpec(Key('tab_assets'), '资产', Icons.inventory_2),
  _TabSpec(Key('tab_stats'), '统计', Icons.bar_chart),
];

/// One peer tab: icon + label, gold when active, muted otherwise.
class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.tab,
    required this.selected,
    required this.onTap,
  });

  final _TabSpec tab;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.goldAccent : AppColors.inkSecondary;
    return InkWell(
      key: tab.key,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.s),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(tab.icon, size: 22, color: color),
            const SizedBox(height: 2),
            Text(
              tab.label,
              style: TextStyle(
                fontSize: AppFont.caption,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
