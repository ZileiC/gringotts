import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gringotts/app/app.dart';
import 'package:gringotts/data/app_database.dart';
import 'package:gringotts/pages/home_page.dart';
import 'package:gringotts/ui/tokens.dart';

/// T-13a part 4: the month calendar sheet on a viewport shorter than its fixed
/// content.
///
/// Fixed content = padding 8 + handle 4 + gap 16 + year row 48 + gap 16 +
/// 4x52dp rows with 3x6dp gaps (226) + padding 24 = 342dp. T-12c removed the
/// default 9/16 modal cap, which left the boundary "viewport shorter than
/// 342dp overflows"; the sheet now scrolls instead, keeping the 52dp cell
/// (>= the 48dp touch minimum) and every month reachable.
void main() {
  /// The sheet's height when nothing has to scroll (DESIGN_MAIN section 3.1).
  const sheetHeight = 342.0;

  late AppDatabase db;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    final migrator = db.createMigrator();
    await migrator.createAll();
    await db.migration.onCreate(migrator);
  });

  tearDown(() async => db.close());

  /// drift's StreamQueryStore schedules a 0ms close timer when the last stream
  /// is cancelled; flutter_test unmounts after the body with a bare pump().
  Future<void> disposeTree(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  }

  Future<void> openSheetAt(WidgetTester tester, Size logical) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = logical;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(theme: buildAppTheme(), home: const HomePage()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('home_month_button')));
    await tester.pumpAndSettle();
  }

  ScrollPosition sheetScroll(WidgetTester tester) => tester
      .state<ScrollableState>(find.descendant(
        of: find.byKey(const Key('home_month_sheet')),
        matching: find.byType(Scrollable),
      ))
      .position;

  const viewports = <String, Size>{
    '800x600 default test surface': Size(800, 600),
    '800x360 landscape phone': Size(800, 360),
    '640x300 short split view': Size(640, 300),
    '360x280 tiny window': Size(360, 280),
  };

  for (final entry in viewports.entries) {
    testWidgets('month sheet at ${entry.key}: no overflow, 48+ cells, '
        'scrolls exactly when it must', (tester) async {
      await openSheetAt(tester, entry.value);

      expect(tester.takeException(), isNull,
          reason: 'no RenderFlex overflow at ${entry.key}');
      expect(find.byKey(const Key('home_month_sheet')), findsOneWidget);

      final sheet = tester.getSize(find.byKey(const Key('home_month_sheet')));
      expect(sheet.height, lessThanOrEqualTo(entry.value.height),
          reason: 'the sheet never grows past the viewport');
      expect(sheet.height, lessThanOrEqualTo(sheetHeight));

      for (var month = 1; month <= 12; month++) {
        final cell = find.byKey(Key('month_sheet_cell_$month'));
        expect(cell, findsOneWidget, reason: 'month $month stays in the grid');
        expect(tester.getSize(cell).height, greaterThanOrEqualTo(48),
            reason: 'month $month keeps the 48dp touch minimum');
      }

      // Scrolling is needed for exactly the shortfall below the fixed content.
      final expectedScroll = (sheetHeight - entry.value.height).clamp(0, 9999);
      final position = sheetScroll(tester);
      expect(position.maxScrollExtent, closeTo(expectedScroll, 1.0),
          reason: '${entry.key}: the grid scrolls by the shortfall only');
      // ignore: avoid_print
      print('T13A_VIEWPORT size=${entry.value.width.toInt()}x'
          '${entry.value.height.toInt()} sheet=${sheet.height.toStringAsFixed(1)} '
          'cell=${tester.getSize(find.byKey(const Key('month_sheet_cell_1'))).height.toStringAsFixed(1)} '
          'max_scroll=${position.maxScrollExtent.toStringAsFixed(1)}');

      // Dismissal stays available at every size. A sheet shorter than the
      // viewport leaves the barrier tappable above it; when the viewport is at
      // or below the fixed content the sheet takes the whole height (no
      // barrier), so the grid itself must still work: pick the month that is
      // already displayed.
      final now = DateTime.now();
      if (sheet.height < entry.value.height) {
        await tester.tapAt(const Offset(10, 10)); // barrier above the sheet
        await tester.pumpAndSettle();
      } else {
        final cell = find.byKey(Key('month_sheet_cell_${now.month}'));
        await tester.ensureVisible(cell);
        await tester.pumpAndSettle();
        await tester.tap(cell);
        await tester.pumpAndSettle();
        expect(find.text('${now.year} 年 ${now.month} 月'), findsOneWidget,
            reason: 'the in-grid selection still closes the sheet');
      }
      expect(find.byKey(const Key('home_month_sheet')), findsNothing);
      expect(tester.takeException(), isNull);
      await disposeTree(tester);
    });
  }

  testWidgets('on a short viewport the last grid row is still reachable',
      (tester) async {
    await openSheetAt(tester, const Size(640, 300));
    final position = sheetScroll(tester);
    expect(position.maxScrollExtent, greaterThan(0));

    // Step back a year so the last row (Oct..Dec) is selectable, scroll it into
    // view and use it: the sheet must close on the chosen month.
    await tester.tap(find.byKey(const Key('month_sheet_year_prev')));
    await tester.pumpAndSettle();
    final lastRow = find.byKey(const Key('month_sheet_cell_12'));
    await tester.ensureVisible(lastRow);
    await tester.pumpAndSettle();
    final sheetRect = tester.getRect(find.byKey(const Key('home_month_sheet')));
    expect(sheetRect.contains(tester.getCenter(lastRow)), isTrue,
        reason: 'the scrolled-to cell is inside the visible sheet');
    await tester.tap(lastRow);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('home_month_sheet')), findsNothing);
    expect(find.text('${DateTime.now().year - 1} 年 12 月'), findsOneWidget,
        reason: 'the scrolled month is the one the home page shows');
    expect(tester.takeException(), isNull);
    await disposeTree(tester);
  });
}
