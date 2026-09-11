import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gringotts/ui/splash.dart';
import 'package:gringotts/ui/tokens.dart';

/// T-09E: brand splash semantics (DESIGN_T09 section 8.6) - canvas solid +
/// logo at 38% of the shortest side + Playfair wordmark, presented as an
/// overlay above the already-mounted home page and removed when it ends.
void main() {
  Widget harness(WidgetTester tester, {required bool disableAnimations}) =>
      MaterialApp(
        home: MediaQuery(
          // Real view metrics with only the animation flag overridden.
          data: MediaQueryData.fromView(tester.view)
              .copyWith(disableAnimations: disableAnimations),
          child: const SplashGate(
            child: Scaffold(body: Center(child: Text('keyboard'))),
          ),
        ),
      );

  testWidgets('brand frame holds over the mounted home, then removes itself',
      (tester) async {
    await tester.pumpWidget(harness(tester, disableAnimations: false));
    await tester.pump();

    // The home page is mounted from the first frame (no navigation layer).
    expect(find.text('keyboard'), findsOneWidget);

    // Brand frame: canvas solid + logo + Playfair wordmark.
    final moment = find.byKey(SplashGate.brandMomentKey);
    expect(moment, findsOneWidget);
    expect(
      tester.widget<ColoredBox>(moment).color,
      AppColors.canvas,
      reason: 'splash plate is the canvas solid, not a white flash',
    );

    final wordmark = tester.widget<Text>(find.byKey(SplashGate.wordmarkKey));
    expect(wordmark.data, 'Gringotts');
    expect(wordmark.style?.fontFamily, 'PlayfairDisplay');
    expect(wordmark.style?.fontWeight, FontWeight.w600);
    expect(wordmark.style?.color, AppColors.goldAccent,
        reason: 'flat gold accent (gold-gradient budget stays at 2)');

    // Logo = 38% of the shortest side.
    final shortest =
        tester.view.physicalSize.shortestSide / tester.view.devicePixelRatio;
    final logo = tester.getSize(find.byKey(SplashGate.logoKey));
    expect(logo.width, closeTo(shortest * SplashGate.logoFraction, 0.01));
    expect(logo.height, closeTo(shortest * SplashGate.logoFraction, 0.01));
    expect(SplashGate.logoFraction, 0.38);

    final fade = tester.widget<FadeTransition>(find.byKey(SplashGate.fadeKey));
    expect(fade.opacity.value, 1.0, reason: 'starts fully opaque');

    // Still opaque at the end of the hold, gone after the fade.
    await tester.pump(SplashGate.hold);
    expect(find.byKey(SplashGate.brandMomentKey), findsOneWidget);
    expect(
      tester
          .widget<FadeTransition>(find.byKey(SplashGate.fadeKey))
          .opacity
          .value,
      1.0,
      reason: 'the brand moment holds before it fades',
    );

    await tester.pump(SplashGate.fade);
    await tester.pumpAndSettle();
    expect(find.byKey(SplashGate.brandMomentKey), findsNothing,
        reason: 'the overlay removes itself when the brand moment ends');
    expect(find.text('Gringotts'), findsNothing);
    expect(find.text('keyboard'), findsOneWidget,
        reason: 'the home page is untouched by the splash lifecycle');
  });

  testWidgets('reduce-motion skips the brand moment (direct presentation)',
      (tester) async {
    await tester.pumpWidget(harness(tester, disableAnimations: true));
    await tester.pump();

    expect(find.byKey(SplashGate.brandMomentKey), findsNothing);
    expect(find.text('keyboard'), findsOneWidget);
    expect(tester.binding.hasScheduledFrame, isFalse,
        reason: 'no splash animation runs under disableAnimations');
  });

  testWidgets('splash runs once per app instance, not per route push',
      (tester) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(MaterialApp(
      navigatorKey: navigatorKey,
      builder: (context, child) =>
          SplashGate(child: child ?? const SizedBox.shrink()),
      home: const Scaffold(body: Center(child: Text('page one'))),
    ));
    await tester.pumpAndSettle();
    expect(find.byKey(SplashGate.brandMomentKey), findsNothing);

    navigatorKey.currentState!.push(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Center(child: Text('page two'))),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('page two'), findsOneWidget);
    expect(find.byKey(SplashGate.brandMomentKey), findsNothing,
        reason: 'the brand moment never replays on navigation');
  });
}
