import 'package:flutter/material.dart';

import '../ui/line_icons.dart';
import '../ui/tokens.dart';
import 'ai_page.dart';
import 'assets_page.dart';
import 'home_page.dart';
import 'quick_entry_page.dart';
import 'stats_page.dart';

/// Root shell (T-12c / T-14b, M2.0 IA): four peer tabs only.
///
/// IA ruling (2026-09-14): the 记一笔 action belongs to the analysis page and
/// lives in its top bar; the bottom bar carries nothing but the peer tabs
/// (分析 / AI / 资产 / 统计). The speed-entry page is the analysis page's child, so returning from
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
          const AiPage(),
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

/// Bottom bar (T-14b / DESIGN_MAIN section 8.3 + DESIGN_AI.md section 1):
/// the four peer tabs, nothing else. A fixed [AppSpacing.navTabHeight] row keeps the bar height
/// identical on every tab. Each tab is a hand-drawn 1.25px line icon plus a
/// MiSans label; the selected tab is gold with a 16x1.5 gold line sliding
/// under it (180ms; reduce-motion switches without displacement).
class _BottomTabs extends StatelessWidget {
  const _BottomTabs({required this.index, required this.onSelect});

  final int index;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final animationsDisabled = MediaQuery.disableAnimationsOf(context);
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
          child: Stack(
            children: [
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
              // T1 gold line: one tab-cell-wide child sliding between the
              // cells, so alignment -1 / 0 / 1 lands exactly on the tab
              // centres (a bare 16pt child would be off by the slack/2) and
              // the 180ms move is a position transition, not a rebuild blink.
              AnimatedAlign(
                key: const Key('tab_selected_indicator_slide'),
                alignment: Alignment(
                  _tabs.length > 1 ? index * 2 / (_tabs.length - 1) - 1 : 0,
                  1,
                ),
                duration:
                    animationsDisabled ? Duration.zero : AppMotion.tabIndicator,
                curve: Curves.easeOutCubic,
                child: FractionallySizedBox(
                  widthFactor: 1 / _tabs.length,
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: Container(
                      key: const Key('tab_selected_indicator'),
                      width: AppSpacing.tabIndicatorWidth,
                      height: AppSpacing.tabIndicatorHeight,
                      color: AppColors.goldAccent,
                    ),
                  ),
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
  const _TabSpec(this.key, this.label, this.icon, this.iconKey);

  final Key key;
  final String label;
  final LineTabIcon icon;
  final Key iconKey;
}

const List<_TabSpec> _tabs = <_TabSpec>[
  _TabSpec(Key('tab_home'), '分析', LineTabIcon.analysis, Key('tab_icon_home')),
  _TabSpec(Key('tab_ai'), 'AI', LineTabIcon.ai, Key('tab_icon_ai')),
  _TabSpec(Key('tab_assets'), '资产', LineTabIcon.assets, Key('tab_icon_assets')),
  _TabSpec(Key('tab_stats'), '统计', LineTabIcon.stats, Key('tab_icon_stats')),
];

/// One peer tab: hand-drawn icon + MiSans label (12 / w500 idle, w600 active,
/// +0.08em tracking), gold when active.
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
          LineTabIconView(
            key: tab.iconKey,
            icon: tab.icon,
            color: color,
          ),
          const SizedBox(height: AppSpacing.xs),
          SizedBox(
            height: AppFont.tabLabelHeight,
            child: Center(
              child: Text(
                tab.label,
                style: TextStyle(
                  fontFamily: AppFont.uiFamily,
                  fontSize: AppFont.tabLabel,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  letterSpacing: AppFont.tabLetterSpacing,
                  color: color,
                  height: 1,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
