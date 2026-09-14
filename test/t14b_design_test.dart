import 'dart:io';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FontLoader;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gringotts/app/app.dart';
import 'package:gringotts/data/app_database.dart';
import 'package:gringotts/pages/assets_page.dart';
import 'package:gringotts/pages/home_page.dart';
import 'package:gringotts/pages/home_shell.dart';
import 'package:gringotts/pages/quick_entry_page.dart';
import 'package:gringotts/pages/stats_page.dart';
import 'package:gringotts/ui/line_icons.dart';
import 'package:gringotts/ui/tokens.dart';

/// T-14b Part B acceptance (DESIGN_MAIN section 8.5, items 1-6):
/// 1. home_record_key exists on the analysis tab and nowhere on assets/stats,
/// 2. that key has no text node (vector plus only),
/// 3. top bar stays 56, key is 36 optic / 48 hit, 320x640 does not overflow,
/// 4. bottom bar height is constant and the gold selection line is keyed,
/// 5. tabs + month button use MiSans, Playfair stays in brand moments only,
/// 6. the three tab icons are hand-drawn (no matching Icons.* anywhere).
/// The subset faces are loaded into the test font manager so the 320dp
/// overflow assertion measures the same metrics the phone will render (the
/// flutter_test default Ahem font is a 1em square and would overstate every
/// label).
bool _miSansLoaded = false;

void main() {
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    final migrator = db.createMigrator();
    await migrator.createAll();
    await db.migration.onCreate(migrator);
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> ensureMiSansLoaded(WidgetTester tester) async {
    if (_miSansLoaded) return;
    final loader = FontLoader('MiSans');
    for (final name in const [
      'MiSans-Regular.ttf',
      'MiSans-Medium.ttf',
      'MiSans-Demibold.ttf',
    ]) {
      final bytes = File('fonts/$name').readAsBytesSync();
      loader.addFont(Future<ByteData>.value(ByteData.sublistView(bytes)));
    }
    await loader.load();
    _miSansLoaded = true;
  }

  Future<void> pumpShell(WidgetTester tester, {Size? size}) async {
    await ensureMiSansLoaded(tester);
    if (size != null) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
    }
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(theme: buildAppTheme(), home: const HomeShell()),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Drift's StreamQueryStore schedules a zero-duration close timer when the
  /// last stream subscriber is cancelled; unmount inside the body so it is
  /// flushed deterministically (same pattern as home_shell_test).
  Future<void> disposeTree(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  }

  Finder recordKey() => find.byKey(const Key('home_record_key'));
  Finder recordKeyAnywhere() =>
      find.byKey(const Key('home_record_key'), skipOffstage: false);

  TextStyle textStyleOf(WidgetTester tester, Finder finder) =>
      tester.widget<Text>(finder).style!;

  testWidgets('1) record key exists on analysis and not in assets/stats',
      (tester) async {
    await pumpShell(tester);

    expect(recordKey(), findsOneWidget);
    expect(
      find.descendant(of: find.byType(HomePage), matching: recordKey()),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('tab_assets')));
    await tester.pumpAndSettle();
    expect(recordKey(), findsNothing);
    expect(
      find.descendant(
        of: find.byType(AssetsPage, skipOffstage: false),
        matching: recordKeyAnywhere(),
      ),
      findsNothing,
    );
    expect(find.byType(QuickEntryPage), findsNothing);

    await tester.tap(find.byKey(const Key('tab_stats')));
    await tester.pumpAndSettle();
    expect(recordKey(), findsNothing);
    expect(
      find.descendant(
        of: find.byType(StatsPage, skipOffstage: false),
        matching: recordKeyAnywhere(),
      ),
      findsNothing,
    );
    expect(find.byType(QuickEntryPage), findsNothing);

    await tester.tap(find.byKey(const Key('tab_home')));
    await tester.pumpAndSettle();
    expect(recordKey(), findsOneWidget);

    await disposeTree(tester);
  });

  testWidgets('2) record key has no text node; 36 optic inside 48 hit',
      (tester) async {
    await pumpShell(tester);

    expect(tester.getSize(recordKey()), const Size(48, 48),
        reason: 'transparent hit target is 48x48');
    expect(
      tester.getSize(find.byKey(const Key('home_record_key_visual'))),
      const Size(AppSpacing.recordKeyVisual, AppSpacing.recordKeyVisual),
    );
    expect(
      find.descendant(of: recordKey(), matching: find.byType(Text)),
      findsNothing,
      reason: 'the spec bans a font plus: no text node may exist',
    );
    expect(
      find.descendant(of: recordKey(), matching: find.byType(EditableText)),
      findsNothing,
    );
    expect(
      find.descendant(of: recordKey(), matching: find.byType(CustomPaint)),
      findsWidgets,
      reason: 'the plus is a vector CustomPainter',
    );

    await disposeTree(tester);
  });

  testWidgets('2b) press beat: goldContainer fade + micro scale',
      (tester) async {
    await pumpShell(tester);

    final key = recordKey();
    final visual = find.byKey(const Key('home_record_key_visual'));
    AnimatedContainer box() => tester.widget<AnimatedContainer>(visual);
    expect(box().duration, AppMotion.recordPressFade);
    expect((box().decoration as BoxDecoration).color, Colors.transparent);

    final gesture = await tester.startGesture(tester.getCenter(key));
    await tester.pump();
    expect((box().decoration as BoxDecoration).color, AppColors.goldContainer,
        reason: 'the pressed target fill is goldContainer');
    expect(
      tester
          .widget<AnimatedScale>(
              find.descendant(of: key, matching: find.byType(AnimatedScale)))
          .scale,
      lessThan(1.0),
      reason: 'press adds a micro scale-down',
    );

    await tester.pump(const Duration(milliseconds: 60));
    final mid = (tester
            .widget<DecoratedBox>(find
                .descendant(of: visual, matching: find.byType(DecoratedBox))
                .first)
            .decoration as BoxDecoration)
        .color!;
    expect(mid.a, greaterThan(0.0));
    expect(mid.a, lessThan(1.0),
        reason: 'the 120ms fill is mid-flight, not an instant jump');

    // Cancel (not up) so the tap handler does not push the entry page.
    await gesture.cancel();
    await tester.pumpAndSettle();
    expect((box().decoration as BoxDecoration).color, Colors.transparent);

    await disposeTree(tester);
  });

  testWidgets('2c) reduce-motion press: colour only, no fade and no scale',
      (tester) async {
    tester.binding.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(
        tester.binding.platformDispatcher.clearAccessibilityFeaturesTestValue);

    await pumpShell(tester);
    final key = recordKey();
    final visual = find.byKey(const Key('home_record_key_visual'));
    expect(tester.widget<AnimatedContainer>(visual).duration, Duration.zero);
    expect(
      tester
          .widget<AnimatedScale>(
              find.descendant(of: key, matching: find.byType(AnimatedScale)))
          .scale,
      1.0,
    );

    final gesture = await tester.startGesture(tester.getCenter(key));
    await tester.pump();
    expect(
      (tester.widget<AnimatedContainer>(visual).decoration as BoxDecoration)
          .color,
      AppColors.goldContainer,
      reason: 'reduce-motion keeps the colour change',
    );
    expect(
      tester
          .widget<AnimatedScale>(
              find.descendant(of: key, matching: find.byType(AnimatedScale)))
          .scale,
      1.0,
      reason: 'reduce-motion drops the scale movement',
    );

    await gesture.cancel();
    await tester.pumpAndSettle();
    await disposeTree(tester);
  });

  testWidgets('3) top bar 56; 320x640 does not overflow or squeeze the month',
      (tester) async {
    await pumpShell(tester, size: const Size(360, 800));
    final wideMonth = tester.getSize(find.byKey(const Key('home_month_button')));
    expect(
      tester.getSize(find.byKey(const Key('home_top_bar'))).height,
      AppSpacing.topBarHeight,
    );
    expect(wideMonth.height, 40);
    expect(recordKey(), findsOneWidget);

    await disposeTree(tester);
    await pumpShell(tester, size: const Size(320, 640));

    expect(tester.takeException(), isNull,
        reason: '320x640 must not throw an overflow');
    expect(
      tester.getSize(find.byKey(const Key('home_top_bar'))).height,
      AppSpacing.topBarHeight,
      reason: 'top bar height is constant',
    );
    expect(tester.getSize(find.byKey(const Key('home_month_button'))), wideMonth,
        reason: 'the month button keeps its size on a 320dp viewport');
    final bar = tester.getRect(find.byKey(const Key('home_top_bar')));
    final record = tester.getRect(recordKey());
    final gear = tester.getRect(find.byKey(const Key('home_budget_entry')));
    expect(record.right, lessThanOrEqualTo(bar.right + 0.01));
    expect(gear.right, lessThanOrEqualTo(bar.right + 0.01));
    expect(record.right, lessThan(gear.left),
        reason: 'record key and gear keep their 4dp gap');
    expect(gear.right, lessThanOrEqualTo(320.0));

    await disposeTree(tester);
  });

  testWidgets('4) bottom bar height constant; gold line is keyed and slides',
      (tester) async {
    await pumpShell(tester);

    final bar = find.byKey(const Key('home_bottom_tabs'));
    final indicator = find.byKey(const Key('tab_selected_indicator'));
    expect(tester.getSize(bar).height, AppSpacing.navTabHeight);
    expect(tester.getSize(indicator),
        const Size(AppSpacing.tabIndicatorWidth, AppSpacing.tabIndicatorHeight));
    final line = tester.widget<Container>(indicator);
    expect(line.color, AppColors.goldAccent);

    final slide =
        tester.widget<AnimatedAlign>(find.byKey(const Key('tab_selected_indicator_slide')));
    expect(slide.duration, AppMotion.tabIndicator);

    final homeCenter = tester.getCenter(find.byKey(const Key('tab_home')));
    expect((tester.getCenter(indicator) - homeCenter).dx.abs(), lessThan(0.6),
        reason: 'the line sits under the selected analysis tab');
    expect(tester.getCenter(indicator).dy, greaterThan(homeCenter.dy + 20),
        reason: 'the line is below the icon+label block');

    await tester.tap(find.byKey(const Key('tab_assets')));
    await tester.pump();
    expect(tester.getSize(bar).height, AppSpacing.navTabHeight);
    await tester.pump(const Duration(milliseconds: 90));
    final midX = tester.getCenter(indicator).dx;
    await tester.pumpAndSettle();
    final assetsCenter = tester.getCenter(find.byKey(const Key('tab_assets')));
    expect((tester.getCenter(indicator) - assetsCenter).dx.abs(), lessThan(0.6));
    expect(midX, greaterThan(homeCenter.dx));
    expect(midX, lessThan(assetsCenter.dx),
        reason: 'the 180ms transition really moves the line between tabs');

    await tester.tap(find.byKey(const Key('tab_stats')));
    await tester.pumpAndSettle();
    expect(tester.getSize(bar).height, AppSpacing.navTabHeight);
    final statsCenter = tester.getCenter(find.byKey(const Key('tab_stats')));
    expect((tester.getCenter(indicator) - statsCenter).dx.abs(), lessThan(0.6));

    await disposeTree(tester);
  });

  testWidgets('4b) reduce-motion: line switches with zero displacement',
      (tester) async {
    tester.binding.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(
        tester.binding.platformDispatcher.clearAccessibilityFeaturesTestValue);

    await pumpShell(tester);
    final indicator = find.byKey(const Key('tab_selected_indicator'));
    final slide =
        tester.widget<AnimatedAlign>(find.byKey(const Key('tab_selected_indicator_slide')));
    expect(slide.duration, Duration.zero);

    await tester.tap(find.byKey(const Key('tab_stats')));
    await tester.pump();
    final statsCenter = tester.getCenter(find.byKey(const Key('tab_stats')));
    expect((tester.getCenter(indicator) - statsCenter).dx.abs(), lessThan(0.6),
        reason: 'one frame after the tap the line is already on the new tab');

    await disposeTree(tester);
  });

  testWidgets('5) tabs and month button use MiSans; Playfair stays in brands',
      (tester) async {
    await pumpShell(tester);

    final home = textStyleOf(tester, find.text('分析'));
    expect(home.fontFamily, AppFont.uiFamily);
    expect(home.fontSize, AppFont.tabLabel);
    expect(home.fontWeight, FontWeight.w600);
    expect(home.letterSpacing, AppFont.tabLetterSpacing);
    expect(home.color, AppColors.goldAccent);

    final assets = textStyleOf(tester, find.text('资产'));
    expect(assets.fontFamily, AppFont.uiFamily);
    expect(assets.fontWeight, FontWeight.w500);
    expect(assets.color, AppColors.inkSecondary);

    await tester.tap(find.byKey(const Key('tab_assets')));
    await tester.pumpAndSettle();
    final active = textStyleOf(tester, find.text('资产'));
    expect(active.fontFamily, AppFont.uiFamily);
    expect(active.fontWeight, FontWeight.w600);
    expect(active.color, AppColors.goldAccent);

    final stats = textStyleOf(tester, find.text('统计'));
    expect(stats.fontFamily, AppFont.uiFamily);
    expect(stats.fontWeight, FontWeight.w500);

    // Month button text is the only Text inside its key and must be MiSans.
    await tester.tap(find.byKey(const Key('tab_home')));
    await tester.pumpAndSettle();
    final monthText = tester.widget<Text>(find.descendant(
      of: find.byKey(const Key('home_month_button')),
      matching: find.byType(Text),
    ));
    expect(monthText.style?.fontFamily, AppFont.uiFamily);

    // The three subset faces and the official license are on disk; the real
    // asset bundle is exercised by integration_test/t12c_shell_test.dart.
    for (final name in const [
      'MiSans-Regular.ttf',
      'MiSans-Medium.ttf',
      'MiSans-Demibold.ttf',
    ]) {
      expect(File('fonts/$name').lengthSync(), greaterThan(1000),
          reason: '$name is present');
    }
    expect(File('fonts/MiSans-LICENSE.pdf').lengthSync(), greaterThan(1000));
    expect(File('fonts/README.md').readAsStringSync(), contains('MiSans'));

    await disposeTree(tester);
  });

  testWidgets('6) the three tab icons are hand-drawn line widgets',
      (tester) async {
    await pumpShell(tester);
    expect(find.byType(LineTabIconView), findsNWidgets(3));
    for (final key in const [
      Key('tab_icon_home'),
      Key('tab_icon_assets'),
      Key('tab_icon_stats'),
    ]) {
      expect(find.byKey(key), findsOneWidget);
    }
    await disposeTree(tester);
  });

  test('6b) source audit: no matching Icons.*, no serif in tabs/keys', () {
    final libFiles = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .toList();
    final bannedIcons = [
      'Icons.insights',
      'Icons.inventory_2',
      'Icons.bar_chart',
    ];
    // The tab bar is the scope: it must not reference any Material icon at
    // all, in particular not the three Material glyphs it replaced. Other
    // pages may keep Material icons for their own affordances.
    final shell = File('lib/pages/home_shell.dart').readAsStringSync();
    expect(shell.contains('Icons.'), isFalse,
        reason: 'the bottom bar must not use Material Icons at all');
    for (final banned in bannedIcons) {
      expect(shell.contains(banned), isFalse,
          reason: 'the tab bar still references $banned');
    }
    expect(File('lib/ui/line_icons.dart').readAsStringSync().contains('Icons.'),
        isFalse);
    expect(shell.contains('LineTabIcon.analysis'), isTrue);
    expect(shell.contains('LineTabIcon.assets'), isTrue);
    expect(shell.contains('LineTabIcon.stats'), isTrue);

    final withPlayfair = <String>[];
    for (final file in libFiles) {
      if (file.readAsStringSync().contains("fontFamily: 'PlayfairDisplay'")) {
        withPlayfair.add(file.path.replaceAll('\\', '/'));
      }
    }
    expect(withPlayfair.map((p) => p.replaceFirst('lib/', '')).toSet(),
        <String>{
          'pages/assets_page.dart',
          'pages/home_page.dart',
          'pages/quick_entry_page.dart',
          'ui/splash.dart',
        },
        reason: 'Playfair is reserved for the brand moments');
    expect(File('lib/ui/record_key.dart').readAsStringSync().contains('Playfair'),
        isFalse);
  });
}
