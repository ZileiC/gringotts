import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gringotts/ui/motion.dart';
import 'package:gringotts/ui/tokens.dart';

/// Deterministic proof for the DESIGN_T09 section 4 base motions (T-09C2):
/// count-up spring, one-shot sheen, chip selection beat, plus the P4 fix
/// (haptics must survive reduce-motion).
void main() {
  final List<MethodCall> haptics = <MethodCall>[];

  setUp(() {
    haptics.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform,
            (MethodCall call) async {
      if (call.method == 'HapticFeedback.vibrate') {
        haptics.add(call);
      }
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  Future<void> pumpHarness(
    WidgetTester tester,
    Widget child, {
    bool reduceMotion = false,
  }) {
    return tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: reduceMotion),
          child: Scaffold(body: Center(child: child)),
        ),
      ),
    );
  }

  group('P4: haptics survive reduce-motion (DESIGN_T09 sections 4-5)', () {
    testWidgets('normal mode: pointer-down fires the haptic once',
        (tester) async {
      await pumpHarness(
        tester,
        TouchedScale(
          pressedScale: 0.96,
          onPressHaptic: () => HapticFeedback.mediumImpact(),
          child: const SizedBox(width: 200, height: 56),
        ),
      );
      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(TouchedScale)),
      );
      await tester.pump();
      expect(haptics, hasLength(1));
      expect(haptics.single.arguments, 'HapticFeedbackType.mediumImpact');
      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets('reduce-motion: no scale animation, haptic still fires',
        (tester) async {
      var taps = 0;
      await pumpHarness(
        tester,
        TouchedScale(
          pressedScale: 0.97,
          onTap: () => taps++,
          onPressHaptic: () => HapticFeedback.selectionClick(),
          child: const SizedBox(width: 88, height: 64),
        ),
        reduceMotion: true,
      );
      expect(
        find.descendant(
          of: find.byType(TouchedScale),
          matching: find.byType(ScaleTransition),
        ),
        findsNothing,
        reason: 'reduce-motion must not build the scale transition',
      );

      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(TouchedScale)),
      );
      await tester.pump();
      expect(haptics, hasLength(1),
          reason: 'haptics are decoupled from the scale animation');
      expect(haptics.single.arguments, 'HapticFeedbackType.selectionClick');
      await gesture.up();
      await tester.pumpAndSettle();
      expect(taps, 1, reason: 'the tap must still be delivered');
    });
  });

  group('CountUpNumber: 400 ms critically damped spring (section 4)', () {
    Future<void> pumpCounter(WidgetTester tester, int cents,
        {bool reduceMotion = false}) {
      return pumpHarness(
        tester,
        CountUpNumber(
          valueCents: cents,
          builder: (context, shown) => Text('$shown',
              key: const Key('countup_value')),
        ),
        reduceMotion: reduceMotion,
      );
    }

    int shownValue(WidgetTester tester) => int.parse(
        tester.widget<Text>(find.byKey(const Key('countup_value'))).data!);

    testWidgets('counts up monotonically, never overshoots, lands exact',
        (tester) async {
      await pumpCounter(tester, 100000);
      expect(shownValue(tester), 0);

      final samples = <int>[];
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 25));
        samples.add(shownValue(tester));
      }
      // Mid-flight: past the start, not yet at the target, strictly rising.
      expect(samples.first, greaterThan(0));
      expect(samples.last, lessThan(100000));
      for (var i = 1; i < samples.length; i++) {
        expect(samples[i], greaterThanOrEqualTo(samples[i - 1]));
      }
      // 300 ms in, the spring is close but not finished.
      await tester.pump(const Duration(milliseconds: 0));
      expect(shownValue(tester), lessThan(100000));

      await tester.pumpAndSettle();
      expect(shownValue(tester), 100000,
          reason: 'the count must land exactly on the target');

      // No overshoot at any point either (critically damped).
      expect(samples.every((v) => v <= 100000), isTrue);
    });

    testWidgets('value change restarts the count from the shown value',
        (tester) async {
      await pumpCounter(tester, 100000);
      await tester.pumpAndSettle();
      expect(shownValue(tester), 100000);

      await pumpCounter(tester, 400000);
      await tester.pump(const Duration(milliseconds: 25));
      final mid = shownValue(tester);
      expect(mid, greaterThan(100000));
      expect(mid, lessThan(400000));
      await tester.pumpAndSettle();
      expect(shownValue(tester), 400000);
    });

    testWidgets('reduce-motion renders the target straight away',
        (tester) async {
      await pumpCounter(tester, 70000, reduceMotion: true);
      expect(shownValue(tester), 70000);
    });
  });

  group('SheenSweep: 600 ms one-shot, never loops (section 4)', () {
    Finder sweepOverlay() => find.descendant(
          of: find.byType(SheenSweep),
          matching: find.byType(Stack),
        );

    testWidgets('sweeps once per trigger, left to right, then stops',
        (tester) async {
      var trigger = 0;
      late StateSetter setState;
      await pumpHarness(
        tester,
        StatefulBuilder(
          builder: (context, setter) {
            setState = setter;
            return SheenSweep(
              trigger: trigger,
              child: const SizedBox(width: 300, height: 56),
            );
          },
        ),
      );
      final state = tester.state<SheenSweepState>(find.byType(SheenSweep));
      expect(state.isSweeping, isFalse, reason: 'no sweep before a confirm');
      expect(state.progress, 0.0);
      expect(sweepOverlay(), findsNothing);

      setState(() => trigger = 1);
      await tester.pump();
      expect(state.isSweeping, isTrue);
      expect(sweepOverlay(), findsOneWidget);

      double bandX() => (tester
              .widget<Align>(find.descendant(
                of: find.byType(SheenSweep),
                matching: find.byType(Align),
              ))
              .alignment as Alignment)
          .x;
      await tester.pump(const Duration(milliseconds: 150));
      expect(state.progress, greaterThan(0.0));
      expect(state.progress, lessThan(1.0));
      final early = bandX();
      await tester.pump(const Duration(milliseconds: 200));
      expect(bandX(), greaterThan(early),
          reason: 'the sheen travels left to right');

      await tester.pumpAndSettle();
      expect(state.isSweeping, isFalse);
      expect(state.progress, 1.0);
      expect(sweepOverlay(), findsNothing,
          reason: 'the sweep is one-shot: nothing is drawn once it ends');

      // No loop: waiting much longer must not restart it.
      await tester.pump(const Duration(seconds: 3));
      expect(state.isSweeping, isFalse);
      expect(state.progress, 1.0);
      expect(sweepOverlay(), findsNothing);
    });

    testWidgets('the sweep overlay never resizes the button', (tester) async {
      var trigger = 0;
      late StateSetter setState;
      await pumpHarness(
        tester,
        StatefulBuilder(
          builder: (context, setter) {
            setState = setter;
            return Center(
              child: SizedBox(
                width: 320,
                height: 56,
                child: SheenSweep(
                  trigger: trigger,
                  child: ColoredBox(
                    key: const Key('cta_body'),
                    color: AppColors.goldAccent,
                  ),
                ),
              ),
            );
          },
        ),
      );
      const Size expected = Size(320, 56);
      expect(tester.getSize(find.byKey(const Key('cta_body'))), expected);

      setState(() => trigger = 1);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.state<SheenSweepState>(find.byType(SheenSweep)).isSweeping,
          isTrue);
      expect(tester.getSize(find.byKey(const Key('cta_body'))), expected,
          reason: 'the sheen Stack must not shrink-wrap the button');
      await tester.pumpAndSettle();
      expect(tester.getSize(find.byKey(const Key('cta_body'))), expected);
    });

    testWidgets('reduce-motion skips the sweep entirely', (tester) async {
      var trigger = 0;
      late StateSetter setState;
      await pumpHarness(
        tester,
        StatefulBuilder(
          builder: (context, setter) {
            setState = setter;
            return SheenSweep(
              trigger: trigger,
              child: const SizedBox(width: 300, height: 56),
            );
          },
        ),
        reduceMotion: true,
      );
      setState(() => trigger = 1);
      await tester.pump(const Duration(milliseconds: 150));
      final state = tester.state<SheenSweepState>(find.byType(SheenSweep));
      expect(state.isSweeping, isFalse);
      expect(state.progress, 0.0);
      expect(sweepOverlay(), findsNothing);
    });
  });

  group('MotionChip: 150 ms AnimatedContainer selection (section 4)', () {
    Future<void> pumpChip(
      WidgetTester tester, {
      required bool selected,
      VoidCallback? onTap,
      bool reduceMotion = false,
    }) {
      return pumpHarness(
        tester,
        MotionChip(
          label: 'Entertainment',
          selected: selected,
          onTap: onTap,
        ),
        reduceMotion: reduceMotion,
      );
    }

    AnimatedContainer animatedBox(WidgetTester tester) =>
        tester.widget<AnimatedContainer>(find.descendant(
          of: find.byType(MotionChip),
          matching: find.byType(AnimatedContainer),
        ));

    BoxDecoration decoration(WidgetTester tester) =>
        tester
            .widget<DecoratedBox>(find.descendant(
              of: find.byType(MotionChip),
              matching: find.byType(DecoratedBox),
            ))
            .decoration as BoxDecoration;

    Color labelColor(WidgetTester tester) =>
        tester.widget<Text>(find.text('Entertainment')).style!.color!;

    testWidgets('selected uses goldContainer/onGoldContainer at 150 ms',
        (tester) async {
      await pumpChip(tester, selected: false, onTap: () {});
      expect(animatedBox(tester).duration,
          const Duration(milliseconds: 150));
      expect(decoration(tester).color, AppColors.surfaceElevated);
      expect(labelColor(tester), AppColors.ink);

      var taps = 0;
      await pumpChip(tester, selected: true, onTap: () => taps++);
      // Mid-transition the colour is a lerp of the two tokens.
      await tester.pump(const Duration(milliseconds: 75));
      final mid = decoration(tester).color!;
      expect(mid, isNot(AppColors.surfaceElevated));
      expect(mid, isNot(AppColors.goldContainer));

      await tester.pumpAndSettle();
      expect(decoration(tester).color, AppColors.goldContainer);
      expect(labelColor(tester), AppColors.onGoldContainer);
      await tester.tap(find.byType(MotionChip));
      await tester.pump();
      expect(taps, 1);
    });

    testWidgets('reduce-motion switches instantly and still taps',
        (tester) async {
      var taps = 0;
      await pumpChip(
        tester,
        selected: true,
        onTap: () => taps++,
        reduceMotion: true,
      );
      expect(animatedBox(tester).duration, Duration.zero);
      expect(decoration(tester).color, AppColors.goldContainer);
      await tester.tap(find.byType(MotionChip));
      await tester.pump();
      expect(taps, 1);
    });
  });
}
