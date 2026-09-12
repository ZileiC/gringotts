import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gringotts/app/app.dart';
import 'package:gringotts/pages/quick_entry_page.dart';
import 'package:gringotts/ui/tokens.dart';
import 'package:integration_test/integration_test.dart';

/// T-12c shell evidence on the real engine: the navigation shell (Part A) and
/// the month calendar sheet (Part D).
///
/// Preconditions declared up front (AGENTS.md evidence clause):
/// - nothing is seeded, so the dev database is left exactly as found; no frame
///   carries seeded data and no row is written or tombstoned,
/// - the runner must not be in January: the script switches to January as a
///   guaranteed *past* month (read-only history) and back,
/// - "does not push" is measured by the shell staying on stage: a pushed route
///   puts the shell offstage under it (asserted here with the default finder).
Future<void> snap(WidgetTester tester, String name, List<Finder> required) async {
  for (final f in required) {
    expect(f, findsWidgets, reason: 'missing before snap $name');
  }
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(const Key('app_repaint_boundary')),
  );
  final ui.Image image = await boundary.toImage(pixelRatio: 1.0);
  final ByteData? data = await image.toByteData(format: ui.ImageByteFormat.png);
  final bytes = data!.buffer.asUint8List();
  expect(bytes.sublist(0, 4), <int>[0x89, 0x50, 0x4e, 0x47],
      reason: 'frame $name must be PNG');
  final file = File('evidence/t12c/.t12c_$name.png');
  await file.create(recursive: true);
  await file.writeAsBytes(bytes, flush: true);
  // ignore: avoid_print
  print('T12C_SNAP name=$name md5=${md5.convert(bytes).toString().substring(0, 12)}');
}

/// IndexedStack is the shell's peer container (single instance in lib/).
int shellIndex(WidgetTester tester, {bool skipOffstage = false}) => tester
    .widget<IndexedStack>(find.byType(IndexedStack, skipOffstage: skipOffstage))
    .index ??
    0;

/// Text colour of a month cell (disabled = muted token, selected = gold).
Color? cellTextColor(WidgetTester tester, int month) => tester
    .widget<Text>(find.descendant(
      of: find.byKey(Key('month_sheet_cell_$month')),
      matching: find.byType(Text),
    ))
    .style
    ?.color;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('T-12c shell: peer tabs / 记一笔 push / month calendar sheet',
      (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final now = DateTime.now();
    expect(now.month, greaterThan(1),
        reason: 'PRECONDITION: the script uses January as a past month');
    // ignore: avoid_print
    print('T12C_PRECONDITION seeded=0 now=${now.year}-${now.month}');

    await tester.pumpWidget(
      RepaintBoundary(
        key: const Key('app_repaint_boundary'),
        child: UncontrolledProviderScope(
          container: container,
          child: const GringottsApp(),
        ),
      ),
    );
    await tester.pumpAndSettle(const Duration(seconds: 2));

    final cta = find.byKey(const Key('home_record_cta'));
    expect(cta, findsOneWidget);
    expect(shellIndex(tester), 0);

    // ---- 1) peer tabs: an index change, never a route push ----
    await tester.tap(find.byKey(const Key('tab_assets')));
    await tester.pumpAndSettle(const Duration(seconds: 1));
    expect(shellIndex(tester), 1);
    expect(cta, findsOneWidget,
        reason: 'the shell is still on stage: switching a tab is not a push');
    expect(find.byType(QuickEntryPage), findsNothing);
    await snap(tester, '01_tab_assets', [cta]);

    await tester.tap(find.byKey(const Key('tab_stats')));
    await tester.pumpAndSettle(const Duration(seconds: 1));
    expect(shellIndex(tester), 2);
    expect(cta, findsOneWidget);
    // ignore: avoid_print
    print('T12C_TABS assets=1 stats=2 record_cta_onstage=true');

    // ---- 2) 记一笔: one push, and back always lands on analysis ----
    await tester.tap(cta);
    await tester.pumpAndSettle(const Duration(seconds: 1));
    expect(find.byType(QuickEntryPage), findsOneWidget);
    expect(find.byKey(const Key('entry_name')), findsOneWidget);
    expect(cta, findsNothing,
        reason: 'the pushed entry route covers the shell (real push)');
    expect(shellIndex(tester), 0,
        reason: 'the shell switched to the analysis tab before pushing');
    // Type a name so the frame is this run's push (an untouched entry page is
    // byte-identical to the idle frame T-11 already recorded); nothing is
    // confirmed, so no row is written.
    await tester.enterText(find.byKey(const Key('entry_name')), '瑞幸');
    await tester.pumpAndSettle(const Duration(seconds: 1));
    await snap(tester, '02_entry_pushed', [
      find.byKey(const Key('entry_name')),
      find.byKey(const Key('confirm_cta')),
    ]);

    await tester.tap(find.byKey(const Key('quick_back')));
    await tester.pumpAndSettle(const Duration(seconds: 1));
    expect(find.byType(QuickEntryPage), findsNothing);
    expect(cta, findsOneWidget);
    expect(shellIndex(tester), 0,
        reason: 'back from a stats-tab 记一笔 lands on analysis, not stats');
    expect(find.byKey(const Key('home_month_button')), findsOneWidget);
    // ignore: avoid_print
    print('T12C_ENTRY pushed_from_stats=2 landed=0');

    // ---- 3) month calendar sheet: past selectable, future greyed out ----
    await tester.tap(find.byKey(const Key('home_month_button')));
    await tester.pumpAndSettle(const Duration(seconds: 1));
    expect(find.byKey(const Key('home_month_sheet')), findsOneWidget);
    expect(find.text('${now.year}'), findsOneWidget);
    // The removed ‹ › month arrows must leave no key behind.
    expect(find.byKey(const Key('home_month_prev')), findsNothing);
    expect(find.byKey(const Key('home_month_next')), findsNothing);
    if (now.month < 12) {
      final future = now.month + 1;
      expect(cellTextColor(tester, future),
          AppColors.inkSecondary.withValues(alpha: 0.4),
          reason: 'future month is greyed out');
      expect(cellTextColor(tester, now.month), AppColors.goldAccent,
          reason: 'the current month is the gold selection');
      await tester.tap(find.byKey(Key('month_sheet_cell_$future')));
      await tester.pumpAndSettle(const Duration(seconds: 1));
      expect(find.byKey(const Key('home_month_sheet')), findsOneWidget,
          reason: 'a future month is not tappable');
      expect(find.text('${now.year} 年 ${now.month} 月'), findsOneWidget,
          reason: 'the displayed month did not move');
      // ignore: avoid_print
      print('T12C_FUTURE_MONTH cell=$future muted=true tappable=false');
    }
    await snap(tester, '03_month_sheet', [
      find.byKey(const Key('home_month_sheet')),
      find.byKey(const Key('month_sheet_year')),
    ]);

    await tester.tap(find.byKey(const Key('month_sheet_cell_1')));
    await tester.pumpAndSettle(const Duration(seconds: 2));
    expect(find.byKey(const Key('home_month_sheet')), findsNothing);
    expect(find.text('${now.year} 年 1 月'), findsOneWidget,
        reason: 'selecting a month switches the home data');
    await snap(tester, '04_history_month', [find.text('${now.year} 年 1 月')]);

    // History is read-only: the budget gear answers with a notice instead.
    await tester.tap(find.byKey(const Key('home_budget_entry')));
    await tester.pumpAndSettle(const Duration(seconds: 1));
    expect(find.text('历史月份只读，仅可查看'), findsOneWidget);
    await tester.pumpAndSettle(const Duration(seconds: 3));

    // Leave the app on the current month again.
    await tester.tap(find.byKey(const Key('home_month_button')));
    await tester.pumpAndSettle(const Duration(seconds: 1));
    await tester.tap(find.byKey(Key('month_sheet_cell_${now.month}')));
    await tester.pumpAndSettle(const Duration(seconds: 2));
    expect(find.byKey(const Key('home_month_sheet')), findsNothing);
    expect(find.text('${now.year} 年 ${now.month} 月'), findsOneWidget);
    // ignore: avoid_print
    print('T12C_MONTH restored=${now.year}-${now.month}');
  });
}
