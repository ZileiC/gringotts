import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gringotts/app/app.dart';
import 'package:gringotts/domain/models.dart';
import 'package:gringotts/domain/seed_ids.dart';
import 'package:gringotts/services/budget_engine.dart';
import 'package:gringotts/services/statistics_service.dart';
import 'package:integration_test/integration_test.dart';

/// T-12 ledger evidence: month->day->entry hierarchy, type filters that keep
/// the grouping, full-field edit (draft stays a draft), tombstone deletion,
/// and the edit -> stats/allowance linkage.
///
/// Preconditions declared up front (AGENTS.md evidence clause): the live row
/// count is read back before seeding, every seeded row is tombstoned at
/// teardown, and the script requires at least three days in the current month
/// so today / yesterday / the day before are all distinct groups.
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
  final file = File('evidence/t12/.t12_$name.png');
  await file.create(recursive: true);
  await file.writeAsBytes(bytes, flush: true);
  // ignore: avoid_print
  print('T12_SNAP name=$name md5=${md5.convert(bytes).toString().substring(0, 12)}');
}

/// Day-header labels in tree order (newest first).
List<String> dayLabels(WidgetTester tester) => tester
    .widgetList<Text>(find.byWidgetPredicate((w) =>
        w is Text &&
        w.key is ValueKey<String> &&
        (w.key as ValueKey<String>).value.startsWith('ledger_day_')))
    .map((t) => t.data)
    .whereType<String>()
    .toList();

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('T-12 ledger: hierarchy + filters + full-field edit + tombstone',
      (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final txRepo = container.read(transactionRepositoryProvider);
    final db = container.read(databaseProvider);

    final now = DateTime.now();
    // Three distinct days inside the current month are required for the
    // today / yesterday / day-before groups.
    expect(now.day, greaterThanOrEqualTo(3),
        reason: 'T-12 script seeds today, yesterday and the day before '
            'inside the current month; run on day >= 3');
    final liveBefore = await txRepo.watchAll().first;
    // ignore: avoid_print
    print('T12_PRECONDITION live_tx=${liveBefore.length}');

    final today = DateTime(now.year, now.month, now.day, 9, 30);
    final yesterday = DateTime(now.year, now.month, now.day - 1, 20, 15);
    final dayBefore = DateTime(now.year, now.month, now.day - 2, 8, 5);
    final e1 = await txRepo.create(
      amountCents: 1550,
      type: TransactionType.expense,
      categoryId: categoryIdDining,
      merchant: '瑞幸',
      occurredAt: today,
    );
    final i1 = await txRepo.create(
      amountCents: 500000,
      type: TransactionType.income,
      categoryId: categoryIdTransport,
      occurredAt: today,
    );
    final d1 = await txRepo.create(
      amountCents: 2500,
      type: TransactionType.expense,
      categoryId: categoryIdShopping,
      occurredAt: yesterday,
      isDraft: true,
    );
    final e2 = await txRepo.create(
      amountCents: 800,
      type: TransactionType.expense,
      categoryId: categoryIdDining,
      note: '早餐',
      occurredAt: dayBefore,
    );
    addTearDown(() async {
      for (final id in <String>[e1.id, i1.id, d1.id, e2.id]) {
        await txRepo.softDelete(id);
      }
    });

    // Baseline for the edit -> stats/allowance linkage, read back from the
    // same live stream the pages consume (existing dev rows cancel out).
    final seededState = await txRepo.watchAll().first;
    final spentBefore =
        BudgetEngine.compute(budget: null, transactions: seededState, now: now)
            .spentCents;
    final expensesBefore = StatisticsService.totals(seededState).expenseCents;
    // ignore: avoid_print
    print('T12_PRECONDITION seeded=${seededState.length} '
        'spent_this_month=$spentBefore');

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

    // T-12 entry: the home 明细 button now opens the real ledger page.
    await tester.tap(find.byKey(const Key('home_ledger_cta')));
    await tester.pumpAndSettle(const Duration(seconds: 2));
    expect(find.byKey(const Key('ledger_back')), findsOneWidget);

    final monthLabel = '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}';
    expect(find.text(monthLabel), findsOneWidget);

    // ---- hierarchy: month -> day -> entry, newest day first ----
    final allDays = dayLabels(tester);
    expect(allDays, [
      '今天 · ${now.month}月${now.day}日',
      '昨天 · ${now.month}月${now.day - 1}日',
      '${now.month}月${now.day - 2}日',
    ]);
    for (final id in <String>[e1.id, i1.id, d1.id, e2.id]) {
      expect(find.byKey(Key('ledger_row_$id')), findsOneWidget);
    }
    expect(find.byKey(Key('ledger_draft_${d1.id}')), findsOneWidget);
    await snap(tester, '01_list', [
      find.byKey(const Key('ledger_list')),
      find.byKey(Key('ledger_row_${e1.id}')),
    ]);

    // ---- type filter: rows removed, day dimension + order unchanged ----
    await tester.tap(find.byKey(const Key('ledger_filter_expense')));
    await tester.pumpAndSettle();
    expect(dayLabels(tester), allDays,
        reason: 'every day still has an expense row');
    expect(find.byKey(Key('ledger_row_${i1.id}')), findsNothing);

    await tester.tap(find.byKey(const Key('ledger_filter_income')));
    await tester.pumpAndSettle();
    final incomeDays = dayLabels(tester);
    expect(incomeDays, allDays.where(incomeDays.contains).toList(),
        reason: 'filtering is a subsequence: same dimension, same order');
    expect(find.byKey(Key('ledger_row_${i1.id}')), findsOneWidget);
    expect(find.byKey(Key('ledger_row_${e1.id}')), findsNothing);
    await snap(tester, '02_filter_income', [
      find.byKey(Key('ledger_row_${i1.id}')),
    ]);

    await tester.tap(find.byKey(const Key('ledger_filter_all')));
    await tester.pumpAndSettle();

    // ---- full-field edit: amount / category / merchant / note / type ----
    await tester.tap(find.byKey(Key('ledger_row_${e1.id}')));
    await tester.pumpAndSettle();
    expect(find.text('编辑记录'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('ledger_edit_amount')));
    await tester.pumpAndSettle();
    await snap(tester, '03_edit_sheet', [
      find.text('编辑记录'),
      find.byKey(const Key('ledger_edit_amount')),
    ]);

    await tester.enterText(find.byKey(const Key('ledger_edit_amount')), '20');
    await tester.pumpAndSettle();
    await tester.ensureVisible(
        find.byKey(Key('ledger_edit_cat_$categoryIdTransport')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(Key('ledger_edit_cat_$categoryIdTransport')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('ledger_edit_merchant')), '滴滴');
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('ledger_edit_note')), '打车');
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('ledger_edit_save')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('ledger_edit_save')));
    await tester.pumpAndSettle(const Duration(seconds: 1));

    final edited = await (db.select(db.transactions)
          ..where((t) => t.id.equals(e1.id)))
        .getSingle();
    expect(edited.amountCents, 2000);
    expect(edited.categoryId, categoryIdTransport);
    expect(edited.merchant, '滴滴');
    expect(edited.note, '打车');
    expect(edited.type, TransactionType.expense);
    expect(edited.isDraft, isFalse);
    // ignore: avoid_print
    print('T12_EDIT id=${edited.id} amount=${edited.amountCents} '
        'cat=${edited.categoryId} merchant=${edited.merchant} '
        'note=${edited.note}');

    // ---- linkage: the edit lands in the shared stats/allowance math ----
    final afterEdit = await txRepo.watchAll().first;
    final spentAfter =
        BudgetEngine.compute(budget: null, transactions: afterEdit, now: now)
            .spentCents;
    expect(spentAfter, spentBefore + 450,
        reason: '1550 -> 2000 expense feeds the home allowance source');
    expect(StatisticsService.totals(afterEdit).expenseCents,
        expensesBefore + 450,
        reason: 'statistics consumes the same edited rows');

    // ---- draft edit keeps the draft state ----
    await tester.tap(find.byKey(Key('ledger_row_${d1.id}')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('ledger_edit_draft_notice')), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('ledger_edit_amount')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('ledger_edit_amount')), '30');
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('ledger_edit_save')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('ledger_edit_save')));
    await tester.pumpAndSettle(const Duration(seconds: 1));
    final keptDraft = await (db.select(db.transactions)
          ..where((t) => t.id.equals(d1.id)))
        .getSingle();
    expect(keptDraft.amountCents, 3000);
    expect(keptDraft.isDraft, isTrue,
        reason: 'editing a draft never promotes it (promotion stays in review)');

    // ---- tombstone deletion: raw row remains, live list drops it ----
    await tester.tap(find.byKey(Key('ledger_row_${e2.id}')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('ledger_edit_delete')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('ledger_edit_delete')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('ledger_delete_confirm')));
    await tester.pumpAndSettle(const Duration(seconds: 1));

    final tombstoned = await (db.select(db.transactions)
          ..where((t) => t.id.equals(e2.id)))
        .getSingle();
    expect(tombstoned.deletedAt, isNotNull,
        reason: 'deletion is a tombstone, the raw row stays for sync');
    expect(find.byKey(Key('ledger_row_${e2.id}')), findsNothing);
  });
}
