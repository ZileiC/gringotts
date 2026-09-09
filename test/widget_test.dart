import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gringotts/app/app.dart';
import 'package:gringotts/data/app_database.dart';
import 'package:gringotts/data/repositories/repositories.dart';
import 'package:gringotts/domain/models.dart';

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

void main() {
  testWidgets('quick entry page renders amount display and keypad',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          categoryRepositoryProvider
              .overrideWithValue(_FakeCategoryRepository()),
          transactionRepositoryProvider
              .overrideWithValue(_FakeTransactionRepository()),
        ],
        child: const GringottsApp(),
      ),
    );
    await tester.pumpAndSettle();

    // Amount display with zero placeholder.
    expect(find.text('¥ 0'), findsOneWidget);
    // Big confirm button.
    expect(find.text('记一笔'), findsOneWidget);
    // Numeric keypad keys exist.
    expect(find.text('1'), findsOneWidget);
    expect(find.text('9'), findsOneWidget);
  });

  testWidgets('keypad input updates the amount display',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          categoryRepositoryProvider
              .overrideWithValue(_FakeCategoryRepository()),
          transactionRepositoryProvider
              .overrideWithValue(_FakeTransactionRepository()),
        ],
        child: const GringottsApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('1'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('5'));
    await tester.pumpAndSettle();

    expect(find.text('¥ 15'), findsOneWidget);
  });
}
