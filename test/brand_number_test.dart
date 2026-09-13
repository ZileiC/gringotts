import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gringotts/app/app.dart';
import 'package:gringotts/data/app_database.dart';
import 'package:gringotts/data/repositories/repositories.dart';
import 'package:gringotts/data/repositories/budget_repository.dart';
import 'package:gringotts/domain/models.dart';
import 'package:gringotts/pages/assets_page.dart';
import 'package:gringotts/pages/home_page.dart';
import 'package:gringotts/services/budget_engine.dart';
import 'package:gringotts/ui/tokens.dart';

/// T-13a part 1 acceptance: the assets net value is a brand serif number with
/// the gold gradient (DESIGN_MAIN.md section 6), sharing one spec with the home
/// hero allowance (section 7). Every other number on the page stays tabular
/// sans, and the list / CPD / holding days are untouched.
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
  /// is cancelled; flutter_test disposes the tree after the body and only does
  /// a bare pump() (no elapse), which would leave that timer pending.
  Future<void> disposeTree(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  }

  Future<void> pumpPage(WidgetTester tester, Widget page) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(theme: buildAppTheme(), home: page),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// The page's single gold-gradient number: exactly one ShaderMask must exist
  /// and its child carries the brand-number spec.
  TextStyle brandNumberStyle(WidgetTester tester, String page) {
    final mask = find.byType(ShaderMask);
    expect(mask, findsOneWidget,
        reason: '$page must have exactly one gold-gradient number '
            '(DESIGN_MAIN section 7 caps gradient definitions)');
    final text = tester.widget<Text>(
      find.descendant(of: mask, matching: find.byType(Text)),
    );
    expect(text.style?.fontFamily, 'PlayfairDisplay',
        reason: '$page brand number is a serif moment');
    expect(text.style?.fontWeight, FontWeight.w600);
    expect(text.style?.fontSize, AppFont.brandNumber);
    expect(text.style?.fontFeatures, AppFont.tabularFigures,
        reason: 'money must not jitter while it counts up');
    return text.style!;
  }

  test('the gradient token is the spec value (goldAccent -> goldDeep)', () {
    // DESIGN_MAIN section 7: the two text moments share this one definition.
    expect(AppGradient.goldText.colors,
        <Color>[AppColors.goldAccent, AppColors.goldDeep]);
    expect(AppFont.brandNumber, 48,
        reason: 'one size for the hero allowance and the net value');
  });

  testWidgets('home hero and assets net value share one brand-number spec',
      (tester) async {
    await BudgetRepository(db).upsert(
      yearMonth: BudgetEngine.monthKey(DateTime.now()),
      incomeCents: 1000000,
      savingsTargetCents: 200000,
    );
    await pumpPage(tester, const HomePage());
    final hero = brandNumberStyle(tester, 'HomePage');
    await disposeTree(tester);

    await AssetRepository(db).create(
      name: '测试相机',
      category: AssetCategory.digital,
      valueCents: 600000,
      purchasedAt: DateTime(2026, 1, 1),
    );
    await pumpPage(tester, const AssetsPage());
    final net = brandNumberStyle(tester, 'AssetsPage');

    expect(net, hero,
        reason: 'the net value and the hero allowance are one spec, not two');
    await disposeTree(tester);
  });

  testWidgets('assets list / CPD / holding days stay sans and unchanged',
      (tester) async {
    await AssetRepository(db).create(
      name: '测试相机',
      category: AssetCategory.digital,
      valueCents: 600000,
      purchasedAt: DateTime(2026, 1, 1),
    );
    await pumpPage(tester, const AssetsPage());

    // Exactly one serif node on the page: the net value.
    final serif = tester
        .widgetList<Text>(find.byType(Text))
        .where((t) => t.style?.fontFamily == 'PlayfairDisplay')
        .toList();
    expect(serif, hasLength(1));
    expect(serif.single.data?.startsWith('¥'), isTrue,
        reason: 'the only serif node is the net value');

    // The list row keeps its flat sans styles: value + holding days and the
    // CPD badge (same copy as T-04/T-13a frames assert).
    final days = tester
        .widgetList<Text>(find.byType(Text))
        .where((t) => t.data != null && t.data!.contains('天'))
        .toList();
    expect(days, isNotEmpty, reason: 'holding days are still rendered');
    for (final t in days) {
      expect(t.style?.fontFamily, isNot('PlayfairDisplay'),
          reason: 'cpd / days keep tabular sans');
    }
    await disposeTree(tester);
  });
}
