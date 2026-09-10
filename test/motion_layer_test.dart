import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gringotts/ui/motion.dart';

/// Deterministic proof for the T-09C motion layer (DESIGN_T09 sections 4-5).
///
/// Pixels are the visual record (evidence/t09c/); these tests lock the
/// *semantics* with numbers that cannot go flaky: press scale values, the
/// press/release spring, the 60 ms stagger delay, the 48 px sink-away cap and
/// the reduce-motion degradation rule.
void main() {
  Finder touchedScaleTransition() => find.descendant(
        of: find.byType(TouchedScale),
        matching: find.byType(ScaleTransition),
      );

  double pressedScale(WidgetTester tester) {
    return tester.widget<ScaleTransition>(touchedScaleTransition()).scale.value;
  }

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

  Widget box({double width = 200, double height = 56}) =>
      SizedBox(width: width, height: height);

  group('TouchedScale (DESIGN_T09 5C)', () {
    testWidgets('CTA press reaches 0.96 while held and springs back to 1.0',
        (tester) async {
      var taps = 0;
      await pumpHarness(
        tester,
        TouchedScale(
          onTap: () => taps++,
          pressedScale: 0.96,
          child: box(),
        ),
      );
      expect(pressedScale(tester), 1.0);

      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(TouchedScale)),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 240));
      expect(pressedScale(tester), closeTo(0.96, 0.0005));

      await gesture.up();
      await tester.pumpAndSettle();
      expect(pressedScale(tester), closeTo(1.0, 0.0005));
      expect(taps, 1, reason: 'scale feedback must not eat the tap');
    });

    testWidgets('keyboard cap uses the 0.97 / 120 ms beat', (tester) async {
      await pumpHarness(
        tester,
        TouchedScale(
          onTap: () {},
          pressedScale: 0.97,
          pressDuration: const Duration(milliseconds: 120),
          child: box(width: 88, height: 64),
        ),
      );
      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(TouchedScale)),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 120));
      expect(pressedScale(tester), closeTo(0.97, 0.0005));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(pressedScale(tester), closeTo(1.0, 0.0005));
    });

    testWidgets('reduce-motion degrades to the plain child, taps still fire',
        (tester) async {
      var taps = 0;
      await pumpHarness(
        tester,
        TouchedScale(
          onTap: () => taps++,
          pressedScale: 0.96,
          child: box(),
        ),
        reduceMotion: true,
      );
      expect(touchedScaleTransition(), findsNothing);
      await tester.tap(find.byType(TouchedScale));
      await tester.pump();
      expect(taps, 1);
    });
  });

  group('StaggerIn (DESIGN_T09 5D)', () {
    Finder staggerItems(Type type) => find.descendant(
          of: find.byType(StaggerIn),
          matching: find.byType(type),
        );

    Future<void> pumpRows(WidgetTester tester, {bool reduceMotion = false}) {
      return pumpHarness(
        tester,
        StaggerIn(
          children: [
            for (var i = 0; i < 3; i++)
              SizedBox(key: ValueKey(i), width: 200, height: 20),
          ],
        ),
        reduceMotion: reduceMotion,
      );
    }

    testWidgets('group of three reveals in order, 60 ms apart, then settles',
        (tester) async {
      await pumpRows(tester);
      expect(staggerItems(Opacity), findsNWidgets(3));

      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      final opacities =
          tester.widgetList<Opacity>(staggerItems(Opacity)).toList();
      final rises =
          tester.widgetList<Transform>(staggerItems(Transform)).toList();

      // Item i+1 starts 60 ms after item i, so at t=200 ms the group is a
      // strict ladder - that ordering is the stagger proof.
      expect(opacities[0].opacity, greaterThan(opacities[1].opacity));
      expect(opacities[1].opacity, greaterThan(opacities[2].opacity));
      expect(opacities[2].opacity, greaterThan(0.0));
      expect(opacities[0].opacity, lessThan(1.0));
      expect(rises[0].transform.getTranslation().y,
          lessThan(rises[2].transform.getTranslation().y));

      await tester.pumpAndSettle();
      for (final o in tester.widgetList<Opacity>(staggerItems(Opacity))) {
        expect(o.opacity, 1.0);
      }
      for (final t in tester.widgetList<Transform>(staggerItems(Transform))) {
        expect(t.transform.getTranslation().y, 0.0);
      }
    });

    testWidgets('reduce-motion renders the children directly', (tester) async {
      await pumpRows(tester, reduceMotion: true);
      expect(staggerItems(Opacity), findsNothing);
      expect(staggerItems(Transform), findsNothing);
      expect(find.byType(SizedBox), findsNWidgets(3));
    });
  });

  group('SinkAwayHeader (DESIGN_T09 5B)', () {
    Finder sinkTransforms() => find.descendant(
          of: find.byType(SinkAwayHeader),
          matching: find.byType(Transform),
        );

    double sinkOpacityOf(WidgetTester tester) => tester
        .widgetList<Opacity>(
          find.descendant(
            of: find.byType(SinkAwayHeader),
            matching: find.byType(Opacity),
          ),
        )
        .first
        .opacity;

    double sinkRise(WidgetTester tester) => tester
        .widgetList<Transform>(sinkTransforms())
        .first
        .transform
        .getTranslation()
        .y;

    // Note: getMaxScaleOnAxis() reports 1.0 for a 2D shrink because the Z
    // axis stays at 1 - read the X axis entry instead.
    double sinkScale(WidgetTester tester) => tester
        .widgetList<Transform>(sinkTransforms())
        .last
        .transform
        .entry(0, 0);

    testWidgets('sinks 0.85x, scales to 0.98, fades to 0.6, capped at 48 px',
        (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      await pumpHarness(
        tester,
        Column(
          children: [
            SinkAwayHeader(
              controller: controller,
              child: box(width: 320, height: 120),
            ),
            Expanded(
              child: ListView(
                controller: controller,
                children: const [SizedBox(height: 2000)],
              ),
            ),
          ],
        ),
      );
      // Before the first scroll the header renders untransformed (identity).
      expect(sinkTransforms(), findsNothing);

      controller.jumpTo(24);
      await tester.pump();
      expect(sinkRise(tester), closeTo(20.4, 0.001));
      expect(sinkScale(tester), closeTo(0.99, 0.001));
      expect(sinkOpacityOf(tester), closeTo(0.8, 0.001));

      controller.jumpTo(48);
      await tester.pump();
      expect(sinkRise(tester), closeTo(40.8, 0.001));
      expect(sinkScale(tester), closeTo(0.98, 0.001));
      expect(sinkOpacityOf(tester), closeTo(0.6, 0.001));

      // 48 px is a hard budget: deeper scrolling must not move it further.
      controller.jumpTo(600);
      await tester.pump();
      expect(sinkRise(tester), closeTo(40.8, 0.001));
      expect(sinkScale(tester), closeTo(0.98, 0.001));
      expect(sinkOpacityOf(tester), closeTo(0.6, 0.001));
    });

    testWidgets('reduce-motion renders the dashboard directly', (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      await pumpHarness(
        tester,
        Column(
          children: [
            SinkAwayHeader(
              controller: controller,
              child: box(width: 320, height: 120),
            ),
            Expanded(
              child: ListView(
                controller: controller,
                children: const [SizedBox(height: 2000)],
              ),
            ),
          ],
        ),
        reduceMotion: true,
      );
      expect(sinkTransforms(), findsNothing);
      expect(
        find.descendant(
          of: find.byType(SinkAwayHeader),
          matching: find.byType(Opacity),
        ),
        findsNothing,
      );
    });
  });

  group('physics + relay route (DESIGN_T09 5A / 5E)', () {
    test('InertialScrollPhysics keeps its tuned spring through applyTo', () {
      const physics = InertialScrollPhysics();
      final scrolled = physics.applyTo(const ClampingScrollPhysics());
      expect(scrolled, isA<InertialScrollPhysics>());
      expect(scrolled.parent, isA<ClampingScrollPhysics>());
      expect(physics.minFlingVelocity, 90);
      expect(physics.dragStartDistanceMotionThreshold, 3.0);
      final spring = physics.spring;
      expect(spring.mass, 0.55);
      expect(spring.stiffness, 220);
    });

    test('HeroRelayRoute retimes the transition to the 350 ms beat', () {
      final route = HeroRelayRoute<void>(builder: (_) => const SizedBox());
      expect(route.transitionDuration, const Duration(milliseconds: 350));
      expect(route.reverseTransitionDuration,
          const Duration(milliseconds: 350));
    });
  });
}
