import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'tokens.dart';

/// Analysis-page record key (T-14b / DESIGN_MAIN section 8.2).
///
/// A [AppSpacing.recordKeyVisual]-pt gold ring with a vector plus and nothing
/// else: no text, no first-run coach mark. The extra transparent area around
/// the visual grows the hit target to [AppSpacing.recordKeyHit] x
/// [AppSpacing.recordKeyHit] without changing the 36pt optic.
///
/// Press beat: the ring interior fades in [AppColors.goldContainer] over
/// [AppMotion.recordPressFade] (single shot) plus a micro scale-down; haptics
/// always fire. reduce-motion keeps the colour change and the haptics but
/// drops every movement.
class RecordKey extends StatefulWidget {
  const RecordKey({super.key, required this.onPressed});

  /// Pushes the speed-entry child. When null the key renders (it belongs to
  /// the analysis page) but stays inert.
  final VoidCallback? onPressed;

  @override
  State<RecordKey> createState() => _RecordKeyState();
}

class _RecordKeyState extends State<RecordKey> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final animationsDisabled = MediaQuery.disableAnimationsOf(context);
    final enabled = widget.onPressed != null;
    final pressed = _pressed && enabled;

    return Semantics(
      button: true,
      enabled: enabled,
      label: '\u8bb0\u4e00\u7b14',
      child: SizedBox(
        width: AppSpacing.recordKeyHit,
        height: AppSpacing.recordKeyHit,
        child: Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: enabled
              ? (_) {
                  HapticFeedback.lightImpact();
                  _setPressed(true);
                }
              : null,
          onPointerUp: enabled ? (_) => _setPressed(false) : null,
          onPointerCancel: enabled ? (_) => _setPressed(false) : null,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.onPressed,
            child: Center(
              child: AnimatedScale(
                scale: pressed && !animationsDisabled ? 0.96 : 1.0,
                duration:
                    animationsDisabled ? Duration.zero : AppMotion.recordPressFade,
                curve: Curves.easeOutCubic,
                child: AnimatedContainer(
                  key: const Key('home_record_key_visual'),
                  duration:
                      animationsDisabled ? Duration.zero : AppMotion.recordPressFade,
                  curve: Curves.easeOut,
                  width: AppSpacing.recordKeyVisual,
                  height: AppSpacing.recordKeyVisual,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: pressed ? AppColors.goldContainer : Colors.transparent,
                    border: Border.all(
                      color: AppColors.goldAccent,
                      width: AppSpacing.recordRingStroke,
                    ),
                  ),
                  child: const Center(
                    child: CustomPaint(
                      size: Size.square(AppSpacing.recordPlusSize),
                      painter: _PlusPainter(
                        color: AppColors.goldAccent,
                        strokeWidth: AppSpacing.recordPlusStroke,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The vector plus glyph (16x16 design box, 1.75 stroke, round caps).
///
/// The line endpoints are inset by half a stroke so the round caps end exactly
/// on the 16x16 optical box - a font "+" never gets this precise, which is why
/// the spec bans it (DESIGN_MAIN section 8.2).
class _PlusPainter extends CustomPainter {
  const _PlusPainter({required this.color, required this.strokeWidth});

  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;
    final inset = strokeWidth / 2;
    final center = size.center(Offset.zero);
    canvas.drawLine(
      Offset(inset, center.dy),
      Offset(size.width - inset, center.dy),
      paint,
    );
    canvas.drawLine(
      Offset(center.dx, inset),
      Offset(center.dx, size.height - inset),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _PlusPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.strokeWidth != strokeWidth;
}
