import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gringotts/app/app.dart';
import 'package:gringotts/data/app_database.dart';
import 'package:gringotts/data/repositories/repositories.dart';
import 'package:gringotts/domain/models.dart';
import 'package:gringotts/pages/stats_page.dart';
import 'package:gringotts/ui/tokens.dart';

/// T-14 spec alignment on the statistics page (DESIGN_T09 section 8.5):
/// - the net balance is semanticExpense when negative and warm ink at zero or
///   above;
/// - the export action is a hairline gold outline key (gold as border and
///   label, never as a large fill - DESIGN_MAIN section 7).
void main() {
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    final migrator = db.createMigrator();
    await migrator.createAll();
    await db.migration.onCreate(migrator);
  });

  tearDown(() async => db.close());

  /// drift's StreamQueryStore schedules a 0ms close timer when the last stream
  /// is cancelled; flutter_test disposes the tree after the body with a bare
  /// pump() (no elapse), which would leave it pending.
  Future<void> disposeTree(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  }

  Future<void> pumpStats(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(theme: buildAppTheme(), home: const StatsPage()),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> seed({int incomeCents = 0, int expenseCents = 0}) async {
    final repo = TransactionRepository(db);
    final now = DateTime.now();
    if (incomeCents > 0) {
      await repo.create(
        amountCents: incomeCents,
        type: TransactionType.income,
        occurredAt: now,
      );
    }
    if (expenseCents > 0) {
      await repo.create(
        amountCents: expenseCents,
        type: TransactionType.expense,
        occurredAt: now,
      );
    }
  }

  /// The net-balance number: colour + rendered text (after the spring lands).
  Text netValue(WidgetTester tester) => tester.widget<Text>(find.descendant(
        of: find.byKey(const Key('stats_net_value')),
        matching: find.byType(Text),
      ));

  testWidgets('net balance: negative is semanticExpense, zero and positive ink',
      (tester) async {
    // Zero: no data at all.
    await pumpStats(tester);
    expect(netValue(tester).data, '¥0');
    expect(netValue(tester).style?.color, AppColors.ink,
        reason: 'zero balance is not a loss');
    await disposeTree(tester);

    // Positive: income above expense.
    await seed(incomeCents: 500000, expenseCents: 200000);
    await pumpStats(tester);
    expect(netValue(tester).data, '¥3000');
    expect(netValue(tester).style?.color, AppColors.ink,
        reason: 'a positive balance stays warm ink');
    await disposeTree(tester);

    // Negative: expense above income (DESIGN_T09 section 8.5).
    await seed(expenseCents: 900000);
    await pumpStats(tester);
    expect(netValue(tester).data, '¥-6000');
    expect(netValue(tester).style?.color, AppColors.semanticExpense,
        reason: 'a negative balance is semanticExpense');
    expect(netValue(tester).style?.color, isNot(AppColors.ink));
    await disposeTree(tester);
  });

  testWidgets('export is a hairline gold outline key, not a filled pill',
      (tester) async {
    await pumpStats(tester);

    // The stats body is a lazy ListView: the export key sits below the trend
    // and pie cards, so scroll it into range before inspecting it.
    final exportKey = find.byKey(const Key('stats_export_button'));
    await tester.scrollUntilVisible(exportKey, 300,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();

    final button = tester.widget<OutlinedButton>(exportKey);
    final side = button.style?.side?.resolve(<WidgetState>{});
    expect(side?.color, AppColors.goldAccent, reason: 'gold hairline border');
    expect(side?.width, 1.0, reason: 'hairline, not a heavy stroke');
    expect(button.style?.foregroundColor?.resolve(<WidgetState>{}),
        AppColors.goldAccent,
        reason: 'the label and icon are gold on the dark canvas');
    expect(button.style?.backgroundColor?.resolve(<WidgetState>{}), isNull,
        reason: 'no large gold fill: the charter allows gold as border/text');
    // The old shape was a filled tonal pill.
    expect(find.byType(FilledButton), findsNothing);
    expect(find.text('导出 CSV / JSON（带 BOM）'), findsOneWidget);

    await disposeTree(tester);
  });
}
