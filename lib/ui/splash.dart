import 'package:flutter/material.dart';

import 'tokens.dart';

/// Brand splash (T-09E, DESIGN_T09 section 8.6): canvas solid + brand logo at
/// 38% of the shortest side + Playfair wordmark "Gringotts".
///
/// Presentation-only overlay. [child] (the speed-entry keyboard - the home
/// page IS the keypad, there is no navigation layer) is mounted and laid out
/// from the very first frame; the overlay holds, fades out and then removes
/// itself. No route is pushed, so the app entry path is unchanged and the
/// brand moment can never desync from the home page.
///
/// Accessibility: with `disableAnimations` the brand moment is skipped
/// entirely (DESIGN_T09 section 5: motion degrades to direct presentation).
class SplashGate extends StatefulWidget {
  const SplashGate({
    super.key,
    required this.child,
    this.holdDuration = hold,
    this.fadeDuration = fade,
  });

  final Widget child;

  /// Production hold length (brand moment at full opacity).
  static const Duration hold = Duration(milliseconds: 700);

  /// Production fade-out length.
  static const Duration fade = Duration(milliseconds: 400);

  /// How long the overlay holds at full opacity (brand moment).
  ///
  /// Overridable for evidence runs that must capture the brand frame without
  /// racing the real clock; production always uses the default.
  final Duration holdDuration;

  /// Fade-out length at the end of the brand moment (same override rule).
  final Duration fadeDuration;

  /// Logo size as a fraction of the shortest side (ticket: "logo 38%").
  static const double logoFraction = 0.38;

  /// Key of the brand frame (integration evidence anchor).
  static const Key brandMomentKey = Key('splash_brand_moment');

  /// Key of the centred brand logo.
  static const Key logoKey = Key('splash_logo');

  /// Key of the Playfair wordmark.
  static const Key wordmarkKey = Key('splash_wordmark');

  /// Key of the splash fade transition (evidence anchor for the brand fade).
  static const Key fadeKey = Key('splash_fade');

  @override
  State<SplashGate> createState() => _SplashGateState();
}

class _SplashGateState extends State<SplashGate>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  bool _visible = true;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.holdDuration + widget.fadeDuration,
    );
    _opacity = TweenSequence<double>(<TweenSequenceItem<double>>[
      TweenSequenceItem<double>(
        tween: ConstantTween<double>(1),
        weight: widget.holdDuration.inMilliseconds.toDouble(),
      ),
      TweenSequenceItem<double>(
        tween: Tween<double>(begin: 1, end: 0)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: widget.fadeDuration.inMilliseconds.toDouble(),
      ),
    ]).animate(_controller);
    _controller.addStatusListener(_onStatus);
    _controller.forward();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Accessibility: no animated brand moment at all when animations are off.
    if (_visible && MediaQuery.of(context).disableAnimations) {
      _controller.stop();
      _visible = false;
    }
  }

  void _onStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed && mounted && _visible) {
      setState(() => _visible = false);
    }
  }

  @override
  void dispose() {
    _controller.removeStatusListener(_onStatus);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        if (_visible)
          FadeTransition(
            key: SplashGate.fadeKey,
            opacity: _opacity,
            child: const _BrandMoment(),
          ),
      ],
    );
  }
}

/// The static brand frame: canvas solid + logo + Playfair wordmark.
class _BrandMoment extends StatelessWidget {
  const _BrandMoment();

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final logoEdge = media.size.shortestSide * SplashGate.logoFraction;
    return ColoredBox(
      key: SplashGate.brandMomentKey,
      color: AppColors.canvas,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'brand/gringotts-logo.png',
              key: SplashGate.logoKey,
              width: logoEdge,
              height: logoEdge,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: AppSpacing.l),
            // Brand moment typography: Playfair, flat gold (no gradient - the
            // gold-gradient budget stays at 2: confirm CTA + chart gold scale).
            const Text(
              'Gringotts',
              key: SplashGate.wordmarkKey,
              style: TextStyle(
                fontFamily: 'PlayfairDisplay',
                fontWeight: FontWeight.w600,
                fontSize: AppFont.h4,
                letterSpacing: 1.6,
                color: AppColors.goldAccent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
