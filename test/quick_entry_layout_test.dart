import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gringotts/app/app.dart';
import 'package:gringotts/data/app_database.dart';
import 'package:gringotts/data/repositories/budget_repository.dart';
import 'package:gringotts/data/repositories/repositories.dart';
import 'package:gringotts/domain/models.dart';
import 'package:gringotts/domain/seed_ids.dart';
import 'package:gringotts/pages/quick_entry_page.dart';
import 'package:gringotts/ui/motion.dart';
import 'package:gringotts/ui/tokens.dart';

class _CatRepo implements CategoryRepository {
  _CatRepo(this.categories);
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

class _TxRepo implements TransactionRepository {
  _TxRepo(this.transactions);
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
  Stream<List<Transaction>> watchDrafts() => Stream.value(const []);

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
  Future<int> confirmedExpenseCentsInRange(DateTime start, DateTime end) async => 0;

  @override
  Future<int> softDelete(String id) => throw UnimplementedError();

  @override
  Future<int> restore(String id) => throw UnimplementedError();

  @override
  Future<int> confirmDraft(String id) => throw UnimplementedError();
}

class _BudgetRepo implements BudgetRepository {
  _BudgetRepo(this.row);
  final BudgetMonth? row;

  @override
  Stream<BudgetMonth?> watchByMonth(String yearMonth) => Stream.value(row);

  @override
  Future<BudgetMonth?> getByMonth(String yearMonth) async => row;

  @override
  Future<List<BudgetMonth>> listMonths() async => row == null ? const [] : [row!];

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

Category _cat(String id, String name, String icon) => Category(
      id: id,
      name: name,
      icon: icon,
      sort: 0,
      isCustom: false,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

final _seedCategories = <Category>[
  _cat(categoryIdDining, '餐饮', 'restaurant'),
  _cat(categoryIdTransport, '交通', 'commute'),
  _cat(categoryIdShopping, '购物', 'shopping_bag'),
  _cat(categoryIdHousing, '居住', 'home'),
  _cat(categoryIdEntertainment, '娱乐', 'sports_esports'),
  _cat(categoryIdStudy, '学习', 'school'),
  _cat(categoryIdMedical, '医疗', 'medical_services'),
  _cat(categoryIdGift, '人情', 'redeem'),
  _cat(categoryIdOther, '其他', 'category'),
];

Transaction _spend(String categoryId, DateTime at) => Transaction(
      id: 'tx-$categoryId-${at.microsecondsSinceEpoch}',
      amountCents: 1000,
      type: TransactionType.expense,
      categoryId: categoryId,
      merchant: null,
      note: null,
      occurredAt: at,
      isDraft: false,
      source: TransactionSource.manual,
      createdAt: at,
      updatedAt: at,
      deletedAt: null,
    );

Widget harness({
  required DateTime now,
  List<Transaction> transactions = const [],
  BudgetMonth? budget,
}) =>
    ProviderScope(
      overrides: [
        categoryRepositoryProvider.overrideWithValue(_CatRepo(_seedCategories)),
        transactionRepositoryProvider.overrideWithValue(_TxRepo(transactions)),
        budgetRepositoryProvider.overrideWithValue(_BudgetRepo(budget)),
      ],
      child: MaterialApp(
        theme: buildAppTheme(),
        home: QuickEntryPage(now: () => now),
      ),
    );

Future<void> tapKey(WidgetTester tester, String value) async {
  final finder = find.byKey(Key('key_$value'));
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

BoxDecoration cellDecoration(WidgetTester tester, String id) =>
    tester
        .widget<AnimatedContainer>(find.byKey(Key('category_cell_$id')))
        .decoration as BoxDecoration;

Color? cellBorder(WidgetTester tester, String id) =>
    (cellDecoration(tester, id).border as Border?)?.top.color;

TextStyle keyStyle(WidgetTester tester, String value) => tester
    .widget<Text>(find.descendant(
      of: find.byKey(Key('key_$value')),
      matching: find.byType(Text),
    ))
    .style!;

void main() {
  final midday = DateTime(2026, 9, 12, 12, 0); // lunch window -> dining
  // Mid-afternoon: no time-of-day rule (03:00 would be the late-night rule).
  final noRule = DateTime(2026, 9, 12, 15, 0);

  testWidgets('keypad: 4x3 with decimal and backspace, no C key',
      (tester) async {
    await tester.pumpWidget(harness(now: midday));
    await tester.pumpAndSettle();

    for (final key in <String>[
      '7', '8', '9', '4', '5', '6', '1', '2', '3', '.', '0', 'backspace',
    ]) {
      expect(find.byKey(Key('key_$key')), findsOneWidget, reason: 'key $key');
    }
    expect(find.byKey(const Key('key_C')), findsNothing,
        reason: 'the C key moved out of the keypad');
    expect(find.text('C'), findsNothing);
    expect(find.text('⌫'), findsOneWidget);
    expect(find.text('.'), findsOneWidget);
  });

  testWidgets('decimal input and clear text action', (tester) async {
    await tester.pumpWidget(harness(now: midday));
    await tester.pumpAndSettle();

    expect(find.text('¥ 0'), findsOneWidget);
    expect(find.byKey(const Key('entry_clear')), findsNothing,
        reason: 'clear hides while the amount is zero');

    await tapKey(tester, '1');
    await tapKey(tester, '.');
    await tapKey(tester, '5');
    expect(find.text('¥ 1.5'), findsOneWidget);

    expect(find.byKey(const Key('entry_clear')), findsOneWidget);
    // Keying scrolled the amount row out of the viewport: bring it back before
    // tapping (evidence clause: confirm visibility before the tap).
    await tester.ensureVisible(find.byKey(const Key('entry_clear')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('entry_clear')));
    await tester.pumpAndSettle();
    expect(find.text('¥ 0'), findsOneWidget);
    expect(find.byKey(const Key('entry_clear')), findsNothing);
  });

  testWidgets('project name feeds the parser: 瑞幸 selects 餐饮', (tester) async {
    await tester.pumpWidget(harness(now: noRule));
    await tester.pumpAndSettle();

    // No clock rule and no history: nothing is pre-selected.
    expect(cellBorder(tester, categoryIdDining), AppColors.hairline);

    await tester.enterText(find.byKey(const Key('entry_name')), '瑞幸');
    await tester.pumpAndSettle();

    expect(cellBorder(tester, categoryIdDining), AppColors.goldAccent);
    expect(cellDecoration(tester, categoryIdDining).color,
        AppColors.goldContainer);
  });

  testWidgets('3x3 grid: nine cells, fixed order, no horizontal scrolling',
      (tester) async {
    await tester.pumpWidget(harness(now: midday));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('category_grid')), findsOneWidget);
    for (final id in <String>[
      categoryIdDining, categoryIdTransport, categoryIdShopping,
      categoryIdHousing, categoryIdEntertainment, categoryIdStudy,
      categoryIdMedical, categoryIdGift, categoryIdOther,
    ]) {
      expect(find.byKey(Key('category_cell_$id')), findsOneWidget);
    }
    // Fixed order (muscle memory): read the grid's own row order.
    final names = tester
        .widgetList<Text>(find.descendant(
          of: find.byKey(const Key('category_grid')),
          matching: find.byType(Text),
        ))
        .map((t) => t.data)
        .toList();
    expect(names, ['餐饮', '交通', '购物', '居住', '娱乐', '学习', '医疗', '人情', '其他']);

    // The category grid owns no Scrollable at all, so it can never scroll
    // horizontally (the only horizontal scroller on the page is the
    // single-line project-name TextField).
    expect(
      find.descendant(
        of: find.byKey(const Key('category_grid')),
        matching: find.byType(Scrollable),
      ),
      findsNothing,
      reason: 'the category grid must never scroll horizontally',
    );
  });

  testWidgets('smart default: time-of-day first, frequency fallback',
      (tester) async {
    // 1. clock rule (lunch) with no history.
    await tester.pumpWidget(harness(now: midday));
    await tester.pumpAndSettle();
    expect(cellBorder(tester, categoryIdDining), AppColors.goldAccent);
    expect(cellBorder(tester, categoryIdShopping), AppColors.hairline);

    // 2. no clock rule -> recent frequency picks 购物.
    await tester.pumpWidget(harness(
      now: noRule,
      transactions: [
        _spend(categoryIdShopping, noRule.subtract(const Duration(days: 1))),
        _spend(categoryIdShopping, noRule.subtract(const Duration(days: 2))),
        _spend(categoryIdTransport, noRule.subtract(const Duration(days: 3))),
      ],
    ));
    await tester.pumpAndSettle();
    expect(cellBorder(tester, categoryIdShopping), AppColors.goldAccent);

    // 3. no clock rule and no history -> nothing selected.
    await tester.pumpWidget(harness(now: noRule));
    await tester.pumpAndSettle();
    for (final id in <String>[categoryIdDining, categoryIdShopping]) {
      expect(cellBorder(tester, id), AppColors.hairline);
    }
  });

  testWidgets('lunch pattern hint still fires (weekday lunch, ~15)', (tester) async {
    final mondayLunch = DateTime(2026, 9, 14, 12, 0); // Monday 12:00
    await tester.pumpWidget(harness(now: mondayLunch));
    await tester.pumpAndSettle();

    // ¥15 -> 1500 cents, the lunch-pattern anchor.
    await tapKey(tester, '1');
    await tapKey(tester, '5');
    expect(find.text('这是午餐吗？'), findsOneWidget);

    await tester.tap(find.text('是'));
    await tester.pumpAndSettle();
    expect(cellBorder(tester, categoryIdDining), AppColors.goldAccent);
  });

  testWidgets('tapping a cell overrides the smart default', (tester) async {
    await tester.pumpWidget(harness(now: midday));
    await tester.pumpAndSettle();
    expect(cellBorder(tester, categoryIdDining), AppColors.goldAccent);

    await tester.tap(find.byKey(Key('category_cell_$categoryIdGift')));
    await tester.pumpAndSettle();
    expect(cellBorder(tester, categoryIdGift), AppColors.goldAccent);
    expect(cellBorder(tester, categoryIdDining), AppColors.hairline);
  });

  testWidgets('typography: amount and key numbers use Playfair, symbols sans',
      (tester) async {
    await tester.pumpWidget(harness(now: midday));
    await tester.pumpAndSettle();

    final amount = tester.widget<Text>(find.text('¥ 0')).style!;
    expect(amount.fontFamily, 'PlayfairDisplay');
    expect(amount.fontSize, AppFont.amountEntry);
    expect(amount.fontWeight, FontWeight.w600);

    final digit = keyStyle(tester, '9');
    expect(digit.fontFamily, 'PlayfairDisplay');
    expect(digit.fontSize, AppFont.keyNumber);
    expect(digit.fontWeight, FontWeight.w600);

    final dot = keyStyle(tester, '.');
    expect(dot.fontFamily, isNot('PlayfairDisplay'));
    expect(dot.fontSize, AppFont.keySymbol);
  });

  testWidgets('confirm key: gold outline + faint gold fill, no gradient',
      (tester) async {
    await tester.pumpWidget(harness(now: midday));
    await tester.pumpAndSettle();

    final deco = tester
        .widget<DecoratedBox>(find.descendant(
          of: find.byKey(const Key('confirm_cta')),
          matching: find.byType(DecoratedBox),
        ))
        .decoration as BoxDecoration;
    expect(deco.gradient, isNull, reason: 'the gold gradient fill is removed');
    expect(deco.color, AppColors.goldContainer);
    expect((deco.border as Border).top.color, AppColors.goldDeep);
    expect(
      tester.getSize(find.byKey(const Key('confirm_cta'))).height,
      AppSpacing.entryConfirmHeight,
    );
  });

  testWidgets('top bar keeps back + review/assets/stats entries',
      (tester) async {
    await tester.pumpWidget(harness(now: midday));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('quick_back')), findsOneWidget);
    expect(find.byKey(const Key('quick_review')), findsOneWidget);
    expect(find.byKey(const Key('quick_assets')), findsOneWidget);
    expect(find.byKey(const Key('quick_stats')), findsOneWidget);
    // Expense/income switch lives in the top bar (default expense).
    expect(find.text('支出'), findsOneWidget);
    expect(find.text('收入'), findsOneWidget);
  });

  testWidgets('reduce-motion: no scale animation, chip switches instantly',
      (tester) async {
    tester.binding.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.binding.platformDispatcher.clearAccessibilityFeaturesTestValue);

    await tester.pumpWidget(harness(now: midday));
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byType(TouchedScale),
        matching: find.byType(ScaleTransition),
      ),
      findsNothing,
    );
    for (final AnimatedContainer box in tester.widgetList<AnimatedContainer>(
      find.descendant(
        of: find.byKey(const Key('category_grid')),
        matching: find.byType(AnimatedContainer),
      ),
    )) {
      expect(box.duration, Duration.zero);
    }
  });
}
