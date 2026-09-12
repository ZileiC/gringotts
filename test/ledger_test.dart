import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gringotts/app/app.dart';
import 'package:gringotts/data/app_database.dart';
import 'package:gringotts/data/repositories/budget_repository.dart';
import 'package:gringotts/data/repositories/repositories.dart';
import 'package:gringotts/domain/models.dart';
import 'package:gringotts/domain/seed_ids.dart';
import 'package:gringotts/pages/ledger_page.dart';
import 'package:gringotts/services/budget_engine.dart';
import 'package:gringotts/services/statistics_service.dart';
import 'package:gringotts/ui/tokens.dart';

// ---------------------------------------------------------------------------
// Widget-test fakes (no database).
// ---------------------------------------------------------------------------

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
];

Transaction _tx({
  required String id,
  required int amountCents,
  required DateTime occurredAt,
  TransactionType type = TransactionType.expense,
  String? categoryId,
  String? merchant,
  String? note,
  bool isDraft = false,
}) =>
    Transaction(
      id: id,
      amountCents: amountCents,
      type: type,
      categoryId: categoryId,
      merchant: merchant,
      note: note,
      occurredAt: occurredAt,
      isDraft: isDraft,
      source: TransactionSource.manual,
      createdAt: occurredAt,
      updatedAt: occurredAt,
      deletedAt: null,
    );

Widget harness({
  required DateTime now,
  required List<Transaction> transactions,
}) =>
    ProviderScope(
      overrides: [
        categoryRepositoryProvider.overrideWithValue(_CatRepo(_seedCategories)),
        transactionRepositoryProvider.overrideWithValue(_TxRepo(transactions)),
      ],
      child: MaterialApp(
        theme: buildAppTheme(),
        home: LedgerPage(now: () => now),
      ),
    );

/// Day-header labels in tree order (newest first by construction).
List<String> dayLabels(WidgetTester tester) => tester
    .widgetList<Text>(find.byWidgetPredicate((w) =>
        w is Text &&
        w.key is ValueKey<String> &&
        (w.key as ValueKey<String>).value.startsWith('ledger_day_')))
    .map((t) => t.data)
    .whereType<String>()
    .toList();

void main() {
  final now = DateTime(2026, 9, 12, 15, 0);

  group('LedgerGrouping (time-first hierarchy, pure)', () {
    final today = DateTime(2026, 9, 12, 9);
    final yesterday = DateTime(2026, 9, 11, 20);
    final older = DateTime(2026, 9, 9, 8);
    final rows = <Transaction>[
      _tx(id: 'a', amountCents: 1000, occurredAt: older, categoryId: categoryIdDining),
      _tx(id: 'b', amountCents: 2000, occurredAt: today, categoryId: categoryIdDining),
      _tx(
        id: 'c',
        amountCents: 3000,
        occurredAt: yesterday,
        categoryId: categoryIdTransport,
        type: TransactionType.income,
      ),
      _tx(id: 'd', amountCents: 4000, occurredAt: today, categoryId: categoryIdShopping),
    ];

    test('groups by day, newest day first, newest entry first within a day',
        () {
      final groups = LedgerGrouping.groupByDay(rows);
      expect(groups.map((g) => g.day).toList(), [
        DateTime(2026, 9, 12),
        DateTime(2026, 9, 11),
        DateTime(2026, 9, 9),
      ]);
      // Same-day rows keep timestamp-descending order; equal timestamps break
      // deterministically by id descending ('d' before 'b').
      expect(groups.first.transactions.map((t) => t.id).toList(), ['d', 'b']);
    });

    test('type filter removes rows but never changes the day dimension/order',
        () {
      final month = DateTime(2026, 9, 1);
      final allDays = LedgerGrouping.groupByDay(
        LedgerGrouping.applyFilter(
            LedgerGrouping.inMonth(rows, month), LedgerFilter.all),
      ).map((g) => g.day).toList();
      for (final filter in <LedgerFilter>[
        LedgerFilter.expense,
        LedgerFilter.income,
      ]) {
        final filtered = LedgerGrouping.groupByDay(
          LedgerGrouping.applyFilter(
            LedgerGrouping.inMonth(rows, month),
            filter,
          ),
        );
        final days = filtered.map((g) => g.day).toList();
        // Same dimension (time) and same order: the filtered day list is a
        // subsequence of the unfiltered one - rows are only ever removed, a
        // day vanishes only when it has no matching entry (never reordered).
        expect(days, allDays.where(days.contains).toList());
        for (final g in filtered) {
          expect(
              g.transactions.every((t) => filter == LedgerFilter.expense
                  ? t.type == TransactionType.expense
                  : t.type == TransactionType.income),
              isTrue);
        }
      }
    });

    test('day labels use 今天 / 昨天 / plain date', () {
      expect(LedgerGrouping.dayLabel(DateTime(2026, 9, 12), now), '今天 · 9月12日');
      expect(LedgerGrouping.dayLabel(DateTime(2026, 9, 11), now), '昨天 · 9月11日');
      expect(LedgerGrouping.dayLabel(DateTime(2026, 9, 9), now), '9月9日');
    });

    test('inMonth drops months outside the selected month', () {
      final rowsAcrossMonths = [
        _tx(id: 'x', amountCents: 100, occurredAt: DateTime(2026, 9, 1)),
        _tx(id: 'y', amountCents: 100, occurredAt: DateTime(2026, 8, 31)),
      ];
      final rows = LedgerGrouping.inMonth(rowsAcrossMonths, DateTime(2026, 9, 1));
      expect(rows.map((t) => t.id), ['x']);
    });
  });

  group('LedgerPage widget (hierarchy + filters + row rendering)', () {
    final today = DateTime(2026, 9, 12, 9, 30);
    final yesterday = DateTime(2026, 9, 11, 20, 15);
    final older = DateTime(2026, 9, 9, 8, 5);

    List<Transaction> rows() => [
          _tx(
            id: 'e1',
            amountCents: 1550,
            occurredAt: today,
            categoryId: categoryIdDining,
            merchant: '瑞幸',
          ),
          _tx(
            id: 'i1',
            amountCents: 500000,
            occurredAt: today,
            categoryId: categoryIdTransport,
            type: TransactionType.income,
          ),
          _tx(
            id: 'd1',
            amountCents: 2500,
            occurredAt: yesterday,
            categoryId: categoryIdShopping,
          ),
          _tx(
            id: 'e2',
            amountCents: 800,
            occurredAt: older,
            categoryId: categoryIdDining,
            note: '早餐',
          ),
        ];

    testWidgets('renders month -> day -> entry, newest day first',
        (tester) async {
      await tester.pumpWidget(harness(now: now, transactions: rows()));
      await tester.pumpAndSettle();

      expect(find.text('2026-09'), findsOneWidget);
      expect(dayLabels(tester), ['今天 · 9月12日', '昨天 · 9月11日', '9月9日']);
      expect(find.byKey(const Key('ledger_row_e1')), findsOneWidget);
      expect(find.byKey(const Key('ledger_row_i1')), findsOneWidget);
      expect(find.byKey(const Key('ledger_row_d1')), findsOneWidget);
      expect(find.byKey(const Key('ledger_row_e2')), findsOneWidget);
      // Entry title falls back merchant -> note -> category name.
      expect(find.text('瑞幸'), findsOneWidget);
      expect(find.text('早餐'), findsOneWidget);
      expect(find.text('购物'), findsOneWidget, reason: 'no merchant/note -> category');
      expect(find.text('交通'), findsOneWidget);
    });

    testWidgets('type filter keeps the same day headers and order',
        (tester) async {
      await tester.pumpWidget(harness(now: now, transactions: rows()));
      await tester.pumpAndSettle();
      final allDays = dayLabels(tester);

      await tester.tap(find.byKey(const Key('ledger_filter_expense')));
      await tester.pumpAndSettle();
      expect(dayLabels(tester), allDays, reason: 'grouping stays month->day');
      expect(find.byKey(const Key('ledger_row_i1')), findsNothing);
      expect(find.byKey(const Key('ledger_row_e1')), findsOneWidget);

      await tester.tap(find.byKey(const Key('ledger_filter_income')));
      await tester.pumpAndSettle();
      // Only today has an income row, so only that day remains - still the
      // same dimension and the same relative order (a subsequence).
      final incomeDays = dayLabels(tester);
      expect(incomeDays, ['今天 · 9月12日']);
      expect(incomeDays, allDays.where(incomeDays.contains).toList());
      expect(find.byKey(const Key('ledger_row_i1')), findsOneWidget);
      expect(find.byKey(const Key('ledger_row_e1')), findsNothing);

      await tester.tap(find.byKey(const Key('ledger_filter_all')));
      await tester.pumpAndSettle();
      expect(dayLabels(tester), allDays);
      expect(find.byKey(const Key('ledger_row_e1')), findsOneWidget);
      expect(find.byKey(const Key('ledger_row_i1')), findsOneWidget);
    });

    testWidgets('amounts colour by type: expense ink, income semanticIncome',
        (tester) async {
      await tester.pumpWidget(harness(now: now, transactions: rows()));
      await tester.pumpAndSettle();

      final incomeAmount = tester.widget<Text>(find.text('¥5000'));
      expect(incomeAmount.style?.color, AppColors.semanticIncome);
      final expenseAmount = tester.widget<Text>(find.text('¥15.5'));
      expect(expenseAmount.style?.color, AppColors.ink);
    });

    testWidgets('empty month shows the empty copy', (tester) async {
      await tester.pumpWidget(harness(
        now: now,
        transactions: [
          _tx(id: 'aug', amountCents: 100, occurredAt: DateTime(2026, 8, 1)),
        ],
      ));
      await tester.pumpAndSettle();
      expect(find.text('这个月还没有记录'), findsOneWidget);
    });
  });

  group('TransactionRepository full-field edit + tombstone semantics', () {
    late AppDatabase db;
    late TransactionRepository repo;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      repo = TransactionRepository(db);
    });

    tearDown(() async => db.close());

    test('updateTransaction writes every field and keeps is_draft', () async {
      final at = DateTime(2026, 9, 12, 10, 0);
      final created = await repo.create(
        amountCents: 1500,
        type: TransactionType.expense,
        categoryId: categoryIdDining,
        merchant: '瑞幸',
        note: '拿铁',
        occurredAt: at,
        isDraft: true,
      );

      final newAt = DateTime(2026, 9, 10, 8, 30);
      await repo.updateTransaction(
        id: created.id,
        amountCents: 9800,
        type: TransactionType.income,
        categoryId: categoryIdTransport,
        merchant: '滴滴',
        note: null,
        occurredAt: newAt,
      );

      final updated = await (db.select(db.transactions)
            ..where((t) => t.id.equals(created.id)))
          .getSingle();
      expect(updated.amountCents, 9800);
      expect(updated.type, TransactionType.income);
      expect(updated.categoryId, categoryIdTransport);
      expect(updated.merchant, '滴滴');
      expect(updated.note, isNull, reason: 'null clears the field');
      expect(updated.occurredAt, newAt);
      expect(updated.isDraft, isTrue,
          reason: 'is_draft is retained (column kept for legacy rows)');
      expect(updated.updatedAt.isAfter(created.updatedAt) ||
          updated.updatedAt == created.updatedAt, isTrue);
    });

    test('softDelete tombstones; the raw row stays', () async {
      final at = DateTime(2026, 9, 12, 10, 0);
      final created = await repo.create(
        amountCents: 2000,
        type: TransactionType.expense,
        categoryId: categoryIdShopping,
        occurredAt: at,
      );
      await repo.softDelete(created.id);

      final raw = await (db.select(db.transactions)
            ..where((t) => t.id.equals(created.id)))
          .getSingle();
      expect(raw.deletedAt, isNotNull, reason: 'tombstone, not a physical delete');
      final live = await repo.watchAll().first;
      expect(live.where((t) => t.id == created.id), isEmpty);

      final restored = await repo.restore(created.id);
      expect(restored, 1);
      expect((await repo.watchAll().first).map((t) => t.id), contains(created.id));
    });

    test('an edit feeds the shared stats/budget math (no second algorithm)',
        () async {
      final now = DateTime(2026, 9, 12, 12, 0);
      final budget = await BudgetRepository(db).upsert(
        yearMonth: BudgetEngine.monthKey(now),
        incomeCents: 500000,
        savingsTargetCents: 200000,
      );
      final created = await repo.create(
        amountCents: 1000,
        type: TransactionType.expense,
        categoryId: categoryIdDining,
        occurredAt: now,
      );

      List<Transaction> list = await repo.watchAll().first;
      final spentBefore =
          BudgetEngine.compute(budget: budget, transactions: list, now: now).spentCents;
      final totalsBefore = StatisticsService.totals(list);
      expect(spentBefore, 1000);

      await repo.updateTransaction(
        id: created.id,
        amountCents: 5000,
        type: TransactionType.expense,
        categoryId: categoryIdDining,
        merchant: null,
        note: null,
        occurredAt: now,
      );

      list = await repo.watchAll().first;
      final spentAfter =
          BudgetEngine.compute(budget: budget, transactions: list, now: now).spentCents;
      final totalsAfter = StatisticsService.totals(list);
      expect(spentAfter, spentBefore + 4000,
          reason: 'home allowance math sees the edited amount');
      expect(totalsAfter.expenseCents, totalsBefore.expenseCents + 4000,
          reason: 'statistics sees the same edited amount');
    });
  });
}
