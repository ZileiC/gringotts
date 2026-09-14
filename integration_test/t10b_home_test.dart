import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gringotts/app/app.dart';
import 'package:gringotts/data/app_database.dart';
import 'package:gringotts/domain/models.dart';
import 'package:gringotts/domain/seed_ids.dart';
import 'package:gringotts/services/budget_engine.dart';
import 'package:gringotts/services/statistics_service.dart';
import 'package:integration_test/integration_test.dart';

/// T-10b home evidence: onboarding / budget set / overspent / empty donut,
/// plus the "fixed action bar at any scroll position" and the
/// "donut slices === stats slicing function" assertions.
///
/// Preconditions declared up front (AGENTS.md evidence clause):
/// - no live budget row for the current month (onboarding frame needs that),
/// - no leftover live confirmed expense for today (donut data is ours),
/// - every row this script seeds is tombstoned again at teardown.
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
  final file = File('evidence/t10b/.t10b_$name.png');
  await file.create(recursive: true);
  await file.writeAsBytes(bytes, flush: true);
  // ignore: avoid_print
  print('T10B_SNAP name=$name md5=${md5.convert(bytes).toString().substring(0, 12)}');
}

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

double _screenHeight(WidgetTester tester) =>
    tester.view.physicalSize.height / tester.view.devicePixelRatio;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('T-10b home: onboarding / set / overspent / empty donut',
      (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
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

    final budgetRepo = container.read(budgetRepositoryProvider);
    final txRepo = container.read(transactionRepositoryProvider);
    final now = DateTime.now();
    final monthKey = BudgetEngine.monthKey(now);

    // ---- declared preconditions ----
    expect(await budgetRepo.getByMonth(monthKey), isNull,
        reason: 'PRECONDITION: onboarding frame needs no budget row for $monthKey');
    final liveBefore = await txRepo.watchAll().first;
    final liveTodayExpenses = liveBefore
        .where((t) =>
            !t.isDraft &&
            t.type == TransactionType.expense &&
            _sameDay(t.occurredAt, now))
        .toList();
    expect(liveTodayExpenses, isEmpty,
        reason: 'PRECONDITION: no leftover live expense for today');
    // ignore: avoid_print
    print('T10B_PRECONDITION month=$monthKey live_today_expenses=0');

    // ---- frame 1: onboarding (no budget) ----
    await tester.pumpAndSettle(const Duration(seconds: 1));
    expect(find.text('先设置本月预算'), findsOneWidget);
    expect(find.text('今天还没有支出'), findsOneWidget);
    await snap(tester, '01_onboarding', [find.text('先设置本月预算')]);

    // ---- frame 2: budget set + today's spending ----
    final budget = await budgetRepo.upsert(
      yearMonth: monthKey,
      incomeCents: 560000, // ¥5,600
      savingsTargetCents: 200000, // ¥2,000 -> budget ¥3,600, 120/day
    );
    addTearDown(() => budgetRepo.softDelete(budget.id));

    final seeded = <Transaction>[];
    // Fixed time-of-day for the seeded rows (AGENTS.md evidence clause): keeps
    // the frame md5 stable across runs instead of drifting with wall-clock now.
    final seededAt = DateTime(now.year, now.month, now.day, 12, 0);
    for (final (categoryId, cents) in <(String, int)>[
      (categoryIdDining, 2260),
      (categoryIdTransport, 1500),
      (categoryIdShopping, 1000),
      (categoryIdHousing, 400),
      (categoryIdEntertainment, 200),
    ]) {
      seeded.add(await txRepo.create(
        amountCents: cents,
        type: TransactionType.expense,
        categoryId: categoryId,
        occurredAt: seededAt,
      ));
    }
    for (final t in seeded) {
      addTearDown(() => txRepo.softDelete(t.id));
    }
    await tester.pumpAndSettle(const Duration(seconds: 2));

    expect(find.text("今天还能花 · Today's Allowance"), findsOneWidget);
    // 5 categories -> 3 named + 其他, all through the shared slicing function.
    final totals = StatisticsService.expenseByCategory(seeded);
    final slices = StatisticsService.chartSlices(totals, maxNamed: 3);
    expect(slices, hasLength(4), reason: 'tail merges into 其他');
    expect(slices.last.isOther, isTrue);
    for (final slice in slices) {
      final label = slice.isOther
          ? '其他'
          : {categoryIdDining: '餐饮', categoryIdTransport: '交通', categoryIdShopping: '购物'}[slice.categoryId]!;
      expect(find.text(label), findsOneWidget,
          reason: 'legend uses StatisticsService.chartSlices');
      final yuan = slice.cents % 100 == 0
          ? (slice.cents ~/ 100).toString()
          : (slice.cents / 100).toStringAsFixed(1);
      expect(find.text('¥$yuan'), findsWidgets,
          reason: 'legend amount for $label comes from the same slices');
    }
    await snap(tester, '02_budget_set', [find.text('本月已花')]);

    // ---- fixed chrome: the analysis top-bar record key + the peer tabs stay
    // put while the analysis list scrolls (T-14b Part A moved the key out of
    // the bottom bar, so both ends are pinned now)
    final record = find.byKey(const Key('home_record_key'));
    final tab = find.byKey(const Key('tab_home'));
    final barBefore = tester.getRect(record);
    expect(find.descendant(of: find.byType(ListView), matching: record),
        findsNothing,
        reason: 'the shell bottom bar lives outside the scroll content');
    expect(barBefore.top, lessThan(120),
        reason: 'the record key belongs to the analysis top bar');
    expect(barBefore.bottom, lessThanOrEqualTo(_screenHeight(tester) + 0.5));
    await tester.drag(find.byType(ListView).first, const Offset(0, -240));
    await tester.pumpAndSettle(const Duration(seconds: 1));
    expect(tester.getRect(record), barBefore,
        reason: 'the record CTA does not move with the scroll');
    final tabRect = tester.getRect(tab);
    expect(tabRect.bottom, lessThanOrEqualTo(_screenHeight(tester) + 0.5));
    expect(tabRect.bottom, greaterThan(_screenHeight(tester) - 80),
        reason: 'the tab bar is pinned at the bottom of the screen');
    // ignore: avoid_print
    print('T10B_FIXED_CHROME record_top=${barBefore.top.toStringAsFixed(1)} '
        'record_bottom=${barBefore.bottom.toStringAsFixed(1)} '
        'tab_bottom=${tabRect.bottom.toStringAsFixed(1)} '
        'screen=${_screenHeight(tester).toStringAsFixed(1)}');

    // Month selection is a button + calendar sheet (T-12c Part D): the arrows
    // are removed, and choosing a month switches the page data.
    expect(find.byKey(const Key('home_month_prev')), findsNothing);
    expect(find.byKey(const Key('home_month_next')), findsNothing);
    await tester.tap(find.byKey(const Key('home_month_button')));
    await tester.pumpAndSettle(const Duration(seconds: 1));
    expect(find.byKey(const Key('home_month_sheet')), findsOneWidget);
    final nowMonth = DateTime.now().month;
    await tester.tap(find.byKey(Key('month_sheet_cell_$nowMonth')));
    await tester.pumpAndSettle(const Duration(seconds: 1));
    expect(find.byKey(const Key('home_month_sheet')), findsNothing);

    // ---- frame 3: overspent (spent ¥53.6 > budget ¥50) ----
    await budgetRepo.upsert(
      yearMonth: monthKey,
      incomeCents: 5000,
      savingsTargetCents: 0,
    );
    await tester.pumpAndSettle(const Duration(seconds: 2));
    expect(find.textContaining('已超支'), findsOneWidget);
    await snap(tester, '03_overspent', [find.textContaining('已超支')]);

    // ---- frame 4: empty donut (no confirmed spending today) ----
    for (final t in seeded) {
      await txRepo.softDelete(t.id);
    }
    await tester.pumpAndSettle(const Duration(seconds: 2));
    expect(find.text('今天还没有支出'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget,
        reason: 'progress survives; only the ring is empty');
    await snap(tester, '04_donut_empty', [find.text('今天还没有支出')]);
  });
}
