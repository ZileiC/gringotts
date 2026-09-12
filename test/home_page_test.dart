import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gringotts/app/app.dart';
import 'package:gringotts/data/app_database.dart';
import 'package:gringotts/data/repositories/budget_repository.dart';
import 'package:gringotts/data/repositories/repositories.dart';
import 'package:gringotts/domain/models.dart';
import 'package:gringotts/domain/seed_ids.dart';
import 'package:gringotts/pages/home_page.dart';
import 'package:gringotts/services/budget_engine.dart';
import 'package:gringotts/ui/tokens.dart';

class _FakeBudgetRepository implements BudgetRepository {
  _FakeBudgetRepository(this.row);

  final BudgetMonth? row;

  @override
  Stream<BudgetMonth?> watchByMonth(String yearMonth) => Stream.value(row);

  @override
  Future<BudgetMonth?> getByMonth(String yearMonth) async => row;

  @override
  Future<List<BudgetMonth>> listMonths() async =>
      row == null ? const [] : [row!];

  @override
  Stream<List<BudgetMonth>> watchMonths() =>
      Stream.value(row == null ? const [] : [row!]);

  @override
  Future<BudgetMonth> upsert({
    required String yearMonth,
    required int incomeCents,
    required int savingsTargetCents,
  }) =>
      throw UnimplementedError();

  @override
  Future<int> softDelete(String id) => throw UnimplementedError();
}

class _FakeCategoryRepository implements CategoryRepository {
  _FakeCategoryRepository(this.categories);

  final List<Category> categories;

  @override
  Stream<List<Category>> watchAll() => Stream.value(categories);

  @override
  Future<Category> createCustom({
    required String name,
    String? icon,
    required int sort,
  }) =>
      throw UnimplementedError();

  @override
  List<String> get seedIds => const <String>[];
}

class _FakeTransactionRepository implements TransactionRepository {
  _FakeTransactionRepository(this.transactions);

  final List<Transaction> transactions;

  @override
  Stream<List<Transaction>> watchAll() => Stream.value(transactions);

  @override
  Stream<List<Transaction>> watchRecent({int windowDays = 14}) =>
      Stream.value(transactions);

  @override
  Future<List<String>> distinctMerchants({int limit = 50}) async => const [];

  @override
  Future<String?> merchantCategory(String merchant) async => null;

  @override
  Future<Transaction> create({
    required int amountCents,
    required TransactionType type,
    String? categoryId,
    String? merchant,
    String? note,
    required DateTime occurredAt,
    bool isDraft = false,
    TransactionSource source = TransactionSource.manual,
  }) =>
      throw UnimplementedError();

  @override
  Future<int> updateTransaction({
    required String id,
    required int amountCents,
    required TransactionType type,
    required String? categoryId,
    required String? merchant,
    required String? note,
    required DateTime occurredAt,
  }) =>
      throw UnimplementedError();

  @override
  Future<int> confirmedExpenseCentsInRange(DateTime start, DateTime end) async => 0;

  @override
  Future<int> softDelete(String id) => throw UnimplementedError();

  @override
  Future<int> restore(String id) => throw UnimplementedError();
}

Category _cat(String id, String name) => Category(
      id: id,
      name: name,
      icon: null,
      sort: 0,
      isCustom: false,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

Transaction _tx({
  required int amountCents,
  String? categoryId,
  bool isDraft = false,
  DateTime? occurredAt,
}) {
  final at = occurredAt ?? DateTime.now();
  return Transaction(
    id: 'tx-$amountCents-${categoryId ?? 'none'}-${at.microsecondsSinceEpoch}',
    amountCents: amountCents,
    type: TransactionType.expense,
    categoryId: categoryId,
    merchant: null,
    note: null,
    occurredAt: at,
    isDraft: isDraft,
    source: TransactionSource.manual,
    createdAt: at,
    updatedAt: at,
    deletedAt: null,
  );
}

BudgetMonth _budget({required int incomeCents, required int savingsTargetCents}) {
  final now = DateTime.now();
  return BudgetMonth(
    id: 'b',
    yearMonth: BudgetEngine.monthKey(now),
    incomeCents: incomeCents,
    savingsTargetCents: savingsTargetCents,
    createdAt: now,
    updatedAt: now,
    deletedAt: null,
  );
}

Widget harness({
  BudgetMonth? budget,
  List<Transaction> transactions = const [],
  List<Category> categories = const [],
}) =>
    ProviderScope(
      overrides: [
        budgetRepositoryProvider.overrideWithValue(_FakeBudgetRepository(budget)),
        transactionRepositoryProvider.overrideWithValue(
            _FakeTransactionRepository(transactions)),
        categoryRepositoryProvider
            .overrideWithValue(_FakeCategoryRepository(categories)),
      ],
      child: MaterialApp(
        theme: buildAppTheme(),
        home: const HomePage(),
      ),
    );

void main() {
  final categories = [
    _cat(categoryIdDining, '餐饮'),
    _cat(categoryIdTransport, '交通'),
    _cat(categoryIdShopping, '购物'),
    _cat(categoryIdHousing, '居住'),
    _cat(categoryIdEntertainment, '娱乐'),
    _cat(categoryIdStudy, '学习'),
  ];

  testWidgets('no budget -> onboarding card + empty donut, month button present',
      (tester) async {
    await tester.pumpWidget(harness(categories: categories));
    await tester.pumpAndSettle();

    expect(find.text('先设置本月预算'), findsOneWidget);
    expect(find.text('今天还没有支出'), findsOneWidget,
        reason: 'empty donut shows one line, not an empty ring');
    // T-12c Part D: the month title is a button; the ‹ › arrows are gone.
    expect(find.byKey(const Key('home_month_button')), findsOneWidget);
    expect(find.byKey(const Key('home_budget_entry')), findsOneWidget);
    expect(find.byKey(const Key('home_month_prev')), findsNothing);
    expect(find.byKey(const Key('home_month_next')), findsNothing);
  });

  testWidgets('budget set -> hero shows derived live quota', (tester) async {
    final budget = _budget(incomeCents: 500000, savingsTargetCents: 200000);
    await tester.pumpWidget(harness(budget: budget, categories: categories));
    await tester.pumpAndSettle();

    final now = DateTime.now();
    final snapshot = BudgetEngine.compute(
      budget: budget,
      transactions: const [],
      now: now,
    );
    expect(find.textContaining("今天还能花"), findsOneWidget);
    expect(find.textContaining('基准 ¥${_money(snapshot.fixedDailyCents!)}/天'),
        findsOneWidget);
    expect(find.text('先设置本月预算'), findsNothing);
  });

  testWidgets('overspend -> red state with readable over-budget copy',
      (tester) async {
    final budget = _budget(incomeCents: 100000, savingsTargetCents: 0);
    await tester.pumpWidget(harness(
      budget: budget,
      transactions: [_tx(amountCents: 200000, categoryId: categoryIdDining)],
      categories: categories,
    ));
    await tester.pumpAndSettle();

    expect(find.text('已超支 ¥1000'), findsOneWidget);
    // The donut legend shows the category and its amount.
    expect(find.text('餐饮'), findsOneWidget);
    expect(find.text('¥2000'), findsWidgets);
  });

  testWidgets('budget <= 0 -> 本月预算已不可行 (not 已超支 ¥0)',
      (tester) async {
    // Savings exceed income: the plan itself is infeasible, even with zero
    // spending (T-10a management note, carried into T-11 as P3).
    final budget = _budget(incomeCents: 50000, savingsTargetCents: 80000);
    await tester.pumpWidget(harness(budget: budget, categories: categories));
    await tester.pumpAndSettle();

    expect(find.textContaining('本月预算已不可行'), findsOneWidget);
    expect(find.textContaining('已超支'), findsNothing);
    expect(find.textContaining('基准 ¥'), findsOneWidget,
        reason: 'the hero still renders (derived figures exist, just negative)');
  });

  testWidgets('month button opens the calendar sheet and switching a month works',
      (tester) async {
    await tester.pumpWidget(harness(categories: categories));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('home_month_button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('home_month_sheet')), findsOneWidget);

    final now = DateTime.now();
    expect(find.byKey(const Key('month_sheet_year')), findsOneWidget);
    expect(find.text('${now.year}'), findsOneWidget);

    // The next year is disabled: tapping does not advance the year label.
    await tester.tap(find.byKey(const Key('month_sheet_year_next')));
    await tester.pumpAndSettle();
    expect(find.text('${now.year}'), findsOneWidget,
        reason: 'future year is disabled');

    // A future month in the current year is disabled (sheet stays open).
    if (now.month < 12) {
      await tester.tap(find.byKey(Key('month_sheet_cell_${now.month + 1}')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('home_month_sheet')), findsOneWidget,
          reason: 'future month must not be selectable');
    }

    // A guaranteed past month closes the sheet and switches the home data.
    final target = now.month == 1 ? 12 : 1;
    final targetYear = now.month == 1 ? now.year - 1 : now.year;
    if (now.month == 1) {
      await tester.tap(find.byKey(const Key('month_sheet_year_prev')));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.byKey(Key('month_sheet_cell_$target')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('home_month_sheet')), findsNothing);
    expect(find.text('$targetYear 年 $target 月'), findsOneWidget);
  });

  testWidgets('donut merges beyond 3 categories into 其他', (tester) async {
    final budget = _budget(incomeCents: 500000, savingsTargetCents: 200000);
    await tester.pumpWidget(harness(
      budget: budget,
      transactions: [
        _tx(amountCents: 5000, categoryId: categoryIdDining),
        _tx(amountCents: 4000, categoryId: categoryIdTransport),
        _tx(amountCents: 3000, categoryId: categoryIdShopping),
        _tx(amountCents: 2000, categoryId: categoryIdHousing),
        _tx(amountCents: 1000, categoryId: categoryIdEntertainment),
      ],
      categories: categories,
    ));
    await tester.pumpAndSettle();

    expect(find.text('餐饮'), findsOneWidget);
    expect(find.text('交通'), findsOneWidget);
    expect(find.text('购物'), findsOneWidget);
    expect(find.text('居住'), findsNothing, reason: '4th category is merged');
    expect(find.text('其他'), findsOneWidget);
    // Merged remainder = housing 2000 + entertainment 1000 = ¥30; shopping
    // (kept as a named slice) is also ¥30, so the amount appears twice.
    expect(find.text('¥30'), findsNWidgets(2));
  });
}

/// Mirrors the page's cents→yuan display for assertions.
String _money(int cents) {
  final abs = cents.abs();
  if (abs % 100 == 0) return (abs ~/ 100).toString();
  if (abs % 10 == 0) return (abs / 100).toStringAsFixed(1);
  return (abs / 100).toStringAsFixed(2);
}
