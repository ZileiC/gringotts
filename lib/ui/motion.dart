/// T-09C motion layer (DESIGN_T09 sections 4-5): unified inertial physics,
/// micro-scale press feedback, staggered group entrance and sink-away
/// parallax helpers. Everything works with Transform/Opacity only and
/// degrades gracefully when animations are disabled.
library;

import 'package:flutter/material.dart';

/// Lenis-flavored physics: heavy spring settle with a friction tail.
///
/// High-stiffness spring + moderate damping gives scrolls "weight": fast
/// start, gentle glide, settled stop - never bouncy toy physics.
class InertialScrollPhysics extends BouncingScrollPhysics {
  const InertialScrollPhysics({super.parent});

  @override
  InertialScrollPhysics applyTo(ScrollPhysics? ancestor) =>
      InertialScrollPhysics(parent: buildParent(ancestor));

  @override
  SpringDescription get spring => SpringDescription.withDampingRatio(
        mass: 0.55,
        stiffness: 220,
        ratio: 1.05,
      );

  @override
  double get minFlingVelocity => 90;

  @override
  double get dragStartDistanceMotionThreshold => 3.0;
}

/// Press feedback wrapper: pointer-down scales to [pressedScale], release
/// springs back. Uses a raw [Listener] so the scale fires even when an
/// inner widget (InkWell, TextButton) wins the gesture arena. Transform
/// only; no layout ever rebuilds.
class TouchedScale extends StatefulWidget {
  const TouchedScale({
    super.key,
    required this.child,
    this.onTap,
    this.pressedScale = 0.98,
    this.pressDuration = const Duration(milliseconds: 240),
    this.onPressHaptic,
  });

  final Widget child;

  /// Tap handler. When null the child keeps handling taps (e.g. InkWell)
  /// while the scale feedback still works.
  final VoidCallback? onTap;

  /// Scale while pressed (tile 0.98 / key 0.97 / CTA 0.96).
  final double pressedScale;

  /// Press-in duration (keys 120 ms per DESIGN_T09 section 4).
  final Duration pressDuration;

  /// Optional haptic fired on pointer-down (触感保留 rule).
  final VoidCallback? onPressHaptic;

  @override
  State<TouchedScale> createState() => _TouchedScaleState();
}

class _TouchedScaleState extends State<TouchedScale>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.pressDuration,
  );
  late final Animation<double> _scale = Tween<double>(
    begin: 1,
    end: widget.pressedScale,
  ).animate(CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
    reverseCurve: Curves.easeOutBack,
  ));

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _down() {
    _controller.forward();
    widget.onPressHaptic?.call();
  }

  void _up() => _controller.reverse();

  @override
  Widget build(BuildContext context) {
    final animationsDisabled = MediaQuery.disableAnimationsOf(context);
    final scaledChild = animationsDisabled
        ? widget.child
        : ScaleTransition(
            scale: _scale,
            child: widget.child,
          );
    return Listener(
      onPointerDown: animationsDisabled ? null : (_) => _down(),
      onPointerUp: animationsDisabled ? null : (_) => _up(),
      onPointerCancel: animationsDisabled ? null : (_) => _up(),
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: scaledChild,
      ),
    );
  }
}

/// Group entrance: children fade in + rise 12 px with 60 ms stagger.
///
/// Transform+Opacity only. With disabled animations everything renders
/// directly.
class StaggerIn extends StatelessWidget {
  const StaggerIn({
    super.key,
    required this.children,
    this.stagger = const Duration(milliseconds: 60),
    this.duration = const Duration(milliseconds: 280),
  });

  final List<Widget> children;
  final Duration stagger;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    final animationsDisabled = MediaQuery.disableAnimationsOf(context);
    return Column(
      children: [
        for (var i = 0; i < children.length; i++)
          animationsDisabled
              ? children[i]
              : _StaggerItem(
                  index: i,
                  stagger: stagger,
                  duration: duration,
                  child: children[i],
                ),
      ],
    );
  }
}

class _StaggerItem extends StatefulWidget {
  const _StaggerItem({
    required this.index,
    required this.stagger,
    required this.duration,
    required this.child,
  });

  final int index;
  final Duration stagger;
  final Duration duration;
  final Widget child;

  @override
  State<_StaggerItem> createState() => _StaggerItemState();
}

class _StaggerItemState extends State<_StaggerItem>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  );
  late final Animation<double> _fade = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
  );
  late final Animation<double> _rise = Tween<double>(
    begin: 12,
    end: 0,
  ).animate(CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
  ));

  @override
  void initState() {
    super.initState();
    Future.delayed(widget.stagger * widget.index, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) => Opacity(
        opacity: _fade.value,
        child: Transform.translate(
          offset: Offset(0, _rise.value),
          child: child,
        ),
      ),
      child: widget.child,
    );
  }
}

/// Scroll-driven "sink away" effect for a dashboard header.
///
/// As the scroll offset grows the content translates at 0.85x (max 48 px),
/// scales 1.0 -> 0.98 and fades 1.0 -> 0.6. Listens to the [ScrollController]
/// itself so position attachment and scroll changes both rebuild.
class SinkAwayHeader extends StatelessWidget {
  const SinkAwayHeader({
    super.key,
    required this.controller,
    required this.child,
  });

  final ScrollController controller;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final animationsDisabled = MediaQuery.disableAnimationsOf(context);
    if (animationsDisabled) {
      return child;
    }
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        if (!controller.hasClients) {
          return child!;
        }
        final offset = controller.position.pixels.clamp(0.0, 48.0);
        final t = (offset / 48).clamp(0.0, 1.0);
        return Transform.translate(
          offset: Offset(0, offset * 0.85),
          child: Transform.scale(
            scale: 1 - 0.02 * t,
            child: Opacity(
              opacity: 1 - 0.4 * t,
              child: child,
            ),
          ),
        );
      },
      child: child,
    );
  }
}

/// Material route retimed to the DESIGN_T09 section 5E Hero relay beat.
///
/// Keeps the platform's standard page transition builders and only stretches
/// the duration to 350 ms, so the shared-element flight (and its reverse)
/// lands on the design beat without inventing a custom transition.
class HeroRelayRoute<T> extends MaterialPageRoute<T> {
  HeroRelayRoute({required super.builder});

  @override
  Duration get transitionDuration => const Duration(milliseconds: 350);

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 350);
}
