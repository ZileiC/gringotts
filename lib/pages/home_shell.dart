import 'package:flutter/material.dart';

import '../ui/tokens.dart';
import 'assets_page.dart';
import 'home_page.dart';
import 'quick_entry_page.dart';
import 'stats_page.dart';

/// Root shell (T-12c / T-14b Part A): three peer tabs only.
///
/// IA ruling (2026-09-14): the 记一笔 action belongs to the analysis page and
/// lives in its top bar; the bottom bar carries nothing but the three peer
/// tabs. The speed-entry page is the analysis page's child, so returning from
/// it always lands on analysis.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  void _openQuickEntry() {
    // The entry only exists on the analysis page, so _index is already 0; the
    // reset stays as a double insurance that back lands on analysis.
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
        children: [
          HomePage(onRecord: _openQuickEntry),
          const AssetsPage(),
          const StatsPage(),
        ],
      ),
      bottomNavigationBar: _BottomTabs(
        index: _index,
        onSelect: (i) => setState(() => _index = i),
      ),
    );
  }
}

/// Bottom bar: exactly the three peer tabs (T-14b Part A). A fixed [height]
/// keeps the total bar height identical on every tab; the 记一笔 action is not
/// part of this bar anymore.
class _BottomTabs extends StatelessWidget {
  const _BottomTabs({required this.index, required this.onSelect});

  final int index;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    // DecoratedBox (not Container) so the 1px top hairline paints *inside* the
    // fixed 56dp row instead of adding a layout pixel.
    return DecoratedBox(
      key: const Key('home_bottom_tabs'),
      decoration: const BoxDecoration(
        color: AppColors.canvas,
        border: Border(top: BorderSide(color: AppColors.hairline)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: AppSpacing.navTabHeight,
          child: Row(
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
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
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
    );
  }
}
