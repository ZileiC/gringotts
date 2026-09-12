import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gringotts/app/app.dart';
import 'package:gringotts/data/app_database.dart';
import 'package:gringotts/data/repositories/budget_repository.dart';
import 'package:gringotts/data/repositories/repositories.dart';
import 'package:gringotts/domain/models.dart';
import 'package:gringotts/pages/quick_entry_page.dart';
import 'package:gringotts/ui/tokens.dart';

/// No budget in this harness: the link row stays hidden (unit scope).
class _FakeBudgetRepository implements BudgetRepository {
  @override
  Stream<BudgetMonth?> watchByMonth(String yearMonth) => Stream.value(null);

  @override
  Future<BudgetMonth?> getByMonth(String yearMonth) async => null;

  @override
  Future<List<BudgetMonth>> listMonths() async => const [];

  @override
  Stream<List<BudgetMonth>> watchMonths() => Stream.value(const []);

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

/// Fake category repository so the widget test never touches a real database
/// (drift stream stores leave pending timers in the fake-async test zone).
class _FakeCategoryRepository implements CategoryRepository {
  @override
  Stream<List<Category>> watchAll() => Stream.value(const <Category>[]);

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

/// Fake transaction repository for the speed-entry page.
class _FakeTransactionRepository implements TransactionRepository {
  @override
  Stream<List<Transaction>> watchAll() => Stream.value(const <Transaction>[]);

  @override
  Stream<List<Transaction>> watchRecent({int windowDays = 14}) =>
      Stream.value(const <Transaction>[]);

  @override
  Future<List<String>> distinctMerchants({int limit = 50}) async =>
      const <String>[];

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
  Stream<List<Transaction>> watchDrafts() => Stream.value(const <Transaction>[]);

  @override
  Stream<int> watchTodayDraftCount() => Stream.value(0);

  @override
  Future<int> updateFields(
    String id, {
    String? categoryId,
    String? merchant,
    String? note,
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
  Future<int> confirmedExpenseCentsInRange(
          DateTime start, DateTime end) async =>
      0;

  @override
  Future<int> softDelete(String id) => throw UnimplementedError();

  @override
  Future<int> restore(String id) => throw UnimplementedError();

  @override
  Future<int> confirmDraft(String id) => throw UnimplementedError();
}

Widget _speedEntryHarness() => ProviderScope(
      overrides: [
        categoryRepositoryProvider.overrideWithValue(_FakeCategoryRepository()),
        transactionRepositoryProvider
            .overrideWithValue(_FakeTransactionRepository()),
        budgetRepositoryProvider.overrideWithValue(_FakeBudgetRepository()),
      ],
      // T-10b: the keypad is a secondary page, so it is pumped directly here.
      child: MaterialApp(
        theme: buildAppTheme(),
        home: const QuickEntryPage(),
      ),
    );

void main() {
  testWidgets('quick entry page renders amount display and keypad',
      (WidgetTester tester) async {
    await tester.pumpWidget(_speedEntryHarness());
    await tester.pumpAndSettle();

    // Amount display with zero placeholder.
    expect(find.text('¥ 0'), findsOneWidget);
    // Confirm button (the title text is also "记一笔", so target the key).
    expect(find.byKey(const Key('confirm_cta')), findsOneWidget);
    // Numeric keypad keys exist.
    expect(find.byKey(const Key('key_1')), findsOneWidget);
    expect(find.byKey(const Key('key_9')), findsOneWidget);
    // Secondary page: explicit back affordance to the analysis home.
    expect(find.byKey(const Key('quick_back')), findsOneWidget);
  });

  testWidgets('keypad input updates the amount display',
      (WidgetTester tester) async {
    await tester.pumpWidget(_speedEntryHarness());
    await tester.pumpAndSettle();

    // The page scrolls on short surfaces; bring keys into view first.
    await tester.ensureVisible(find.byKey(const Key('key_1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('key_1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('key_5')));
    await tester.pumpAndSettle();

    expect(find.text('¥ 15'), findsOneWidget);
  });
}
