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

/// T-12c Part A acceptance: three peer tabs switch without pushing; 记一笔
/// pushes the speed-entry page (analysis child); the stats page reaches the
/// ledger. A real in-memory database keeps the providers honest.
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

  int stackIndex(WidgetTester tester) =>
      tester.widget<IndexedStack>(find.byType(IndexedStack)).index ?? 0;

  testWidgets('three peer tabs are siblings; switching does not push',
      (tester) async {
    await pumpShell(tester);

    expect(stackIndex(tester), 0);
    expect(find.byType(HomePage), findsOneWidget);
    expect(find.byType(AssetsPage), findsOneWidget);
    expect(find.byType(StatsPage), findsOneWidget);

    await tester.tap(find.byKey(const Key('tab_assets')));
    await tester.pumpAndSettle();
    expect(stackIndex(tester), 1);
    expect(find.byKey(const Key('tab_assets')), findsOneWidget);

    await tester.tap(find.byKey(const Key('tab_stats')));
    await tester.pumpAndSettle();
    expect(stackIndex(tester), 2);

    await tester.tap(find.byKey(const Key('tab_home')));
    await tester.pumpAndSettle();
    expect(stackIndex(tester), 0);
  });

  testWidgets('记一笔 pushes the speed-entry child and back returns to analysis',
      (tester) async {
    await pumpShell(tester);

    await tester.tap(find.byKey(const Key('home_record_cta')));
    await tester.pumpAndSettle();
    expect(find.byType(QuickEntryPage), findsOneWidget);
    expect(find.byKey(const Key('entry_name')), findsOneWidget);

    await tester.tap(find.byKey(const Key('quick_back')));
    await tester.pumpAndSettle();
    expect(find.byType(QuickEntryPage), findsNothing);
    expect(stackIndex(tester), 0, reason: 'returns to the analysis tab');
  });

  testWidgets('stats page reaches the ledger child', (tester) async {
    await pumpShell(tester);

    await tester.tap(find.byKey(const Key('tab_stats')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('stats_ledger_entry')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('ledger_back')), findsOneWidget);
    expect(find.byKey(const Key('ledger_month_label')), findsOneWidget);
  });

  testWidgets('speed-entry confirm writes a formal record that shows at once',
      (tester) async {
    await pumpShell(tester);

    await tester.tap(find.byKey(const Key('home_record_cta')));
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
  });
}
