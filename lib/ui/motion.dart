/// T-09C motion layer (DESIGN_T09 sections 4-5): unified inertial physics,
/// micro-scale press feedback, staggered group entrance and sink-away
/// parallax helpers. Everything works with Transform/Opacity only and
/// degrades gracefully when animations are disabled.
library;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

import 'tokens.dart';

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

  /// Optional haptic fired on pointer-down. Fires even when animations are
  /// disabled (the "haptics kept" rule of DESIGN_T09 sections 4-5).
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

  void _down() => _controller.forward();

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
      // Haptics are decoupled from the scale animation: pointer-down always
      // reports the press, so reduce-motion keeps the tactile feedback
      // (DESIGN_T09 sections 4-5, "haptics kept").
      onPointerDown: (_) {
        widget.onPressHaptic?.call();
        if (!animationsDisabled) _down();
      },
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

/// Money figure count-up: a critically damped spring settling in ~400 ms
/// (DESIGN_T09 section 4), triggered on page enter and on value change.
///
/// Critical damping means the count never overshoots its target; with
/// animations disabled the target renders straight away.
class CountUpNumber extends StatefulWidget {
  const CountUpNumber({
    super.key,
    required this.valueCents,
    required this.builder,
  });

  /// Target value in integer cents (money is always integer cents).
  final int valueCents;

  /// Builds the display for the value that is currently counted.
  final Widget Function(BuildContext context, int shownCents) builder;

  @override
  State<CountUpNumber> createState() => CountUpNumberState();
}

class CountUpNumberState extends State<CountUpNumber>
    with SingleTickerProviderStateMixin {
  /// Critically damped spring (ratio 1.0 -> no overshoot) tuned to settle in
  /// roughly 400 ms: omega = sqrt(260) ~= 16.1 rad/s, 1% settle ~= 6.6/omega.
  static final SpringDescription spring = SpringDescription.withDampingRatio(
    mass: 1,
    stiffness: 260,
    ratio: 1.0,
  );

  late final AnimationController _controller =
      AnimationController.unbounded(vsync: this, value: 1);
  int _fromCents = 0;
  bool _started = false;

  /// Value currently on screen (deterministic read-back hook for tests).
  int get shownCents => _shownFor(widget.valueCents);

  int _shownFor(int targetCents) {
    final t = _controller.value.clamp(0.0, 1.0);
    return (_fromCents + (targetCents - _fromCents) * t).round();
  }

  /// Whether the count-up is still running (read-back hook for tests).
  bool get isCounting => _controller.isAnimating;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      _restart(from: 0);
    }
  }

  @override
  void didUpdateWidget(CountUpNumber oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.valueCents != widget.valueCents && _started) {
      // Continue from what is currently displayed (measured against the
      // previous target, which is what the controller progress refers to).
      _restart(from: _shownFor(oldWidget.valueCents));
    }
  }

  void _restart({required int from}) {
    _fromCents = from;
    if (from == widget.valueCents ||
        MediaQuery.disableAnimationsOf(context)) {
      _controller.value = 1;
      return;
    }
    _controller.value = 0;
    _controller
        .animateWith(SpringSimulation(spring, 0, 1, 0))
        .then((_) {
      // A spring stops inside its settle tolerance; land exactly on target.
      if (mounted) {
        setState(() => _controller.value = 1);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) {
      return widget.builder(context, widget.valueCents);
    }
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => widget.builder(context, shownCents),
    );
  }
}

/// One-shot 600 ms sheen sweep for the confirm CTA (DESIGN_T09 section 4).
///
/// The sweep runs when [trigger] changes and never repeats or loops; with
/// animations disabled nothing is drawn at all (haptics are unaffected).
class SheenSweep extends StatefulWidget {
  const SheenSweep({
    super.key,
    required this.trigger,
    required this.child,
    this.duration = const Duration(milliseconds: 600),
    this.borderRadius = const BorderRadius.all(Radius.circular(AppRadius.m)),
  });

  /// Change this token to fire one sweep (e.g. a per-confirm counter).
  final int trigger;

  final Widget child;
  final Duration duration;
  final BorderRadius borderRadius;

  @override
  State<SheenSweep> createState() => SheenSweepState();
}

class SheenSweepState extends State<SheenSweep>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  );
  bool _animationsDisabled = false;

  /// Sweep progress 0..1 (read-back hook for tests).
  double get progress => _controller.value;

  /// Whether a sweep is currently running (read-back hook for tests).
  bool get isSweeping => _controller.isAnimating;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _animationsDisabled = MediaQuery.disableAnimationsOf(context);
  }

  @override
  void didUpdateWidget(SheenSweep oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.trigger != oldWidget.trigger && !_animationsDisabled) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_animationsDisabled) {
      return widget.child;
    }
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        if (!_controller.isAnimating) {
          return child!;
        }
        final t = _controller.value;
        // StackFit.passthrough keeps the wrapped widget's own constraints:
        // a full-width CTA must stay full width (regression seen in the
        // evidence frame; guarded by the motion unit test).
        return Stack(
          fit: StackFit.passthrough,
          children: [
            child!,
            Positioned.fill(
              child: IgnorePointer(
                child: ClipRRect(
                  borderRadius: widget.borderRadius,
                  child: Align(
                    // Sweeps left to right, entering and leaving the box.
                    alignment: Alignment(-1.8 + 3.6 * t, 0),
                    child: FractionallySizedBox(
                      widthFactor: 0.4,
                      heightFactor: 1,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: <Color>[
                              AppColors.sheenEdge,
                              AppColors.sheen,
                              AppColors.sheenEdge,
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
      child: widget.child,
    );
  }
}

/// Selectable chip with the DESIGN_T09 section 4 selection beat: a 150 ms
/// [AnimatedContainer] flipping between surfaceElevated/ink and
/// goldContainer/onGoldContainer. Press feedback comes from [TouchedScale].
class MotionChip extends StatelessWidget {
  const MotionChip({
    super.key,
    required this.label,
    required this.selected,
    this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final animationsDisabled = MediaQuery.disableAnimationsOf(context);
    final background =
        selected ? AppColors.goldContainer : AppColors.surfaceElevated;
    final foreground =
        selected ? AppColors.onGoldContainer : AppColors.ink;

    return TouchedScale(
      pressedScale: 0.97,
      onTap: onTap,
      child: AnimatedContainer(
        duration: animationsDisabled
            ? Duration.zero
            : const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.m,
          vertical: AppSpacing.s,
        ),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(
            color: selected ? AppColors.goldAccent : AppColors.hairline,
          ),
        ),
        child: Text(
          label,
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: foreground, fontWeight: FontWeight.w500),
        ),
      ),
    );
  }
}

