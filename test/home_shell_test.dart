import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gringotts/app/app.dart';
import 'package:gringotts/data/app_database.dart';
import 'package:gringotts/pages/assets_page.dart';
import 'package:gringotts/pages/home_page.dart';
import 'package:gringotts/pages/home_shell.dart';
import 'package:gringotts/pages/quick_entry_page.dart';
import 'package:gringotts/pages/stats_page.dart';
import 'package:gringotts/ui/tokens.dart';

/// T-12c Part A + T-14b Part A acceptance: three peer tabs switch without
/// pushing; the 记一笔 entry lives on the analysis page only (never on assets
/// or stats); it pushes the speed-entry child, so back always lands on
/// analysis; the bottom bar keeps one constant height on every tab. A real
/// in-memory database keeps the providers honest.
void main() {
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    final migrator = db.createMigrator();
    await migrator.createAll();
    await db.migration.onCreate(migrator);
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> pumpShell(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(theme: buildAppTheme(), home: const HomeShell()),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Unmounts the tree inside the test body and settles.
  ///
  /// Drift's StreamQueryStore schedules a zero-duration close timer when the
  /// last subscriber of a query stream is cancelled. The framework unmounts
  /// the tree *after* the body and only does a bare `pump()` (no elapse), so
  /// that timer stays pending and aborts the run. Disposing the tree here, in
  /// a pump we control, flushes it deterministically.
  Future<void> disposeShell(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  }

  /// IndexedStack keeps the inactive peers offstage, so callers that assert on
  /// a hidden peer (or on the shell under a pushed route) pass
  /// [skipOffstage] = false.
  int stackIndex(WidgetTester tester, {bool skipOffstage = true}) =>
      tester
          .widget<IndexedStack>(
              find.byType(IndexedStack, skipOffstage: skipOffstage))
          .index ??
      0;

  /// The record key with the offstage peers included - the structural finder
  /// used to prove the key is not even mounted inside assets/stats.
  Finder recordKeyAnywhere() =>
      find.byKey(const Key('home_record_key'), skipOffstage: false);

  testWidgets('three peer tabs are siblings; switching does not push',
      (tester) async {
    await pumpShell(tester);

    // IndexedStack builds all three peers; the inactive ones are offstage.
    expect(stackIndex(tester), 0);
    expect(find.byType(HomePage), findsOneWidget);
    expect(find.byType(AssetsPage, skipOffstage: false), findsOneWidget);
    expect(find.byType(StatsPage, skipOffstage: false), findsOneWidget);

    await tester.tap(find.byKey(const Key('tab_assets')));
    await tester.pumpAndSettle();
    expect(stackIndex(tester), 1);
    expect(find.byType(AssetsPage), findsOneWidget,
        reason: 'the selected peer is on stage');
    expect(find.byType(HomePage), findsNothing,
        reason: 'switching is an index change, not a stack of routes');
    expect(find.byKey(const Key('tab_assets')), findsOneWidget);

    await tester.tap(find.byKey(const Key('tab_stats')));
    await tester.pumpAndSettle();
    expect(stackIndex(tester), 2);

    await tester.tap(find.byKey(const Key('tab_home')));
    await tester.pumpAndSettle();
    expect(stackIndex(tester), 0);

    await disposeShell(tester);
  });

  testWidgets('record entry is on the analysis tab only', (tester) async {
    await pumpShell(tester);

    // Analysis: the key is on stage and lives inside HomePage.
    expect(find.byKey(const Key('home_record_key')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(HomePage),
        matching: find.byKey(const Key('home_record_key')),
      ),
      findsOneWidget,
    );

    // Assets: nothing on stage, and the key is not mounted under AssetsPage.
    await tester.tap(find.byKey(const Key('tab_assets')));
    await tester.pumpAndSettle();
    expect(stackIndex(tester), 1);
    expect(find.byKey(const Key('home_record_key')), findsNothing,
        reason: 'the assets tab has no record entry');
    expect(
      find.descendant(
        of: find.byType(AssetsPage, skipOffstage: false),
        matching: recordKeyAnywhere(),
      ),
      findsNothing,
      reason: 'no record key is mounted inside the assets page subtree',
    );

    // Statistics: same existence assertion.
    await tester.tap(find.byKey(const Key('tab_stats')));
    await tester.pumpAndSettle();
    expect(stackIndex(tester), 2);
    expect(find.byKey(const Key('home_record_key')), findsNothing,
        reason: 'the stats tab has no record entry');
    expect(
      find.descendant(
        of: find.byType(StatsPage, skipOffstage: false),
        matching: recordKeyAnywhere(),
      ),
      findsNothing,
      reason: 'no record key is mounted inside the stats page subtree',
    );
    expect(find.byType(QuickEntryPage), findsNothing);

    // Back on analysis the key is available again.
    await tester.tap(find.byKey(const Key('tab_home')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('home_record_key')), findsOneWidget);

    await disposeShell(tester);
  });

  testWidgets('bottom bar height is identical on all three tabs',
      (tester) async {
    await pumpShell(tester);

    double barHeight() =>
        tester.getSize(find.byKey(const Key('home_bottom_tabs'))).height;

    final analysisHeight = barHeight();
    expect(analysisHeight, AppSpacing.navTabHeight,
        reason: 'tab row is a fixed 56dp, plus the safe-area inset');

    await tester.tap(find.byKey(const Key('tab_assets')));
    await tester.pumpAndSettle();
    expect(barHeight(), analysisHeight);

    await tester.tap(find.byKey(const Key('tab_stats')));
    await tester.pumpAndSettle();
    expect(barHeight(), analysisHeight);

    await tester.tap(find.byKey(const Key('tab_home')));
    await tester.pumpAndSettle();
    expect(barHeight(), analysisHeight);

    await disposeShell(tester);
  });

  testWidgets('记一笔 pushes the speed-entry child and back returns to analysis',
      (tester) async {
    await pumpShell(tester);

    await tester.tap(find.byKey(const Key('home_record_key')));
    await tester.pumpAndSettle();
    expect(find.byType(QuickEntryPage), findsOneWidget);
    expect(find.byKey(const Key('entry_name')), findsOneWidget);
    // The push really is a route: while it is up the shell is offstage under
    // it. This is the baseline that "switching a peer tab does not push" is
    // measured against in the integration script.
    expect(find.byKey(const Key('home_record_key')), findsNothing);

    await tester.tap(find.byKey(const Key('quick_back')));
    await tester.pumpAndSettle();
    expect(find.byType(QuickEntryPage), findsNothing);
    expect(stackIndex(tester), 0, reason: 'returns to the analysis tab');
    expect(find.byKey(const Key('home_record_key')), findsOneWidget);

    await disposeShell(tester);
  });

  testWidgets('stats page reaches the ledger child', (tester) async {
    await pumpShell(tester);

    await tester.tap(find.byKey(const Key('tab_stats')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('stats_ledger_entry')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('ledger_back')), findsOneWidget);
    expect(find.byKey(const Key('ledger_month_label')), findsOneWidget);

    await disposeShell(tester);
  });

  testWidgets('speed-entry confirm writes a formal record that shows at once',
      (tester) async {
    await pumpShell(tester);

    await tester.tap(find.byKey(const Key('home_record_key')));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('entry_name')), '瑞幸');
    await tester.pumpAndSettle();
    for (final key in <String>['1', '5']) {
      final finder = find.byKey(Key('key_$key'));
      await tester.ensureVisible(finder);
      await tester.pumpAndSettle();
      await tester.tap(finder);
      await tester.pump();
    }
    await tester.tap(find.byKey(const Key('confirm_cta')));
    await tester.pumpAndSettle();

    final live = await db.select(db.transactions).get();
    final written = live.where((t) => t.merchant == '瑞幸').toList();
    expect(written, hasLength(1));
    expect(written.single.isDraft, isFalse,
        reason: '快记即正式: is_draft = false');
    expect(written.single.amountCents, 1500);

    await tester.tap(find.byKey(const Key('quick_back')));
    await tester.pumpAndSettle();
    // The new record is visible on the analysis home without any confirmation.
    expect(find.text('¥15 · 1 笔'), findsOneWidget);

    await disposeShell(tester);
  });
}
