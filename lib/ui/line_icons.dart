import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'tokens.dart';

/// Hand-drawn 1.25px line icons for the four bottom tabs (T-14b / T-15 /
/// DESIGN_MAIN section 8.3).
///
/// These are deliberately *not* Material Icons: the tab glyphs share the
/// black-gold hairline language of the app. Geometry is authored on a 20x20
/// grid and scaled by [size], so every stroke stays crisp at the 20pt tab
/// size while tests can still measure it.
enum LineTabIcon { analysis, ai, assets, stats }

/// Renders one [LineTabIcon] at [color] (stroke only, round caps/joins).
class LineTabIconView extends StatelessWidget {
  const LineTabIconView({
    super.key,
    required this.icon,
    required this.color,
    this.size = AppSpacing.tabIconSize,
    this.strokeWidth = AppSpacing.tabIconStroke,
  });

  final LineTabIcon icon;
  final Color color;
  final double size;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _LineTabIconPainter(
        icon: icon,
        color: color,
        strokeWidth: strokeWidth,
      ),
    );
  }
}

class _LineTabIconPainter extends CustomPainter {
  const _LineTabIconPainter({
    required this.icon,
    required this.color,
    required this.strokeWidth,
  });

  final LineTabIcon icon;
  final Color color;
  final double strokeWidth;

  /// Design grid the paths below are authored on.
  static const double _grid = 20;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.shortestSide / _grid;
    Offset p(double x, double y) => Offset(x * scale, y * scale);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;

    switch (icon) {
      case LineTabIcon.analysis:
        // Rising polyline with a small end circle.
        final path = Path()
          ..moveTo(p(2.5, 14.5).dx, p(2.5, 14.5).dy)
          ..lineTo(p(7, 9.5).dx, p(7, 9.5).dy)
          ..lineTo(p(10.5, 12.5).dx, p(10.5, 12.5).dy)
          ..lineTo(p(16, 5.5).dx, p(16, 5.5).dy);
        canvas.drawPath(path, paint);
        canvas.drawCircle(p(16, 5.5), 1.6 * scale, paint);
      case LineTabIcon.ai:
        // Six-point starburst (DESIGN_AI.md section 13): three hairlines
        // through the centre at 0 / 60 / 120 degrees, authored on a 16x16
        // frame centred in the 20pt slot with round caps; the endpoints are
        // inset by half the stroke width so the caps stay inside the frame.
        final centre = p(10, 10);
        final reach = AppSpacing.aiIconGrid / 2 * scale - strokeWidth / 2;
        for (var i = 0; i < 3; i++) {
          final angle = i * math.pi / 3;
          final direction = Offset(math.cos(angle), math.sin(angle));
          canvas.drawLine(
            centre - direction * reach,
            centre + direction * reach,
            paint,
          );
        }
      case LineTabIcon.assets:
        // Two stacked frames: the back frame peeks above the front one, so the
        // hidden overlap is never drawn twice.
        final back = Path()
          ..moveTo(p(5.5, 7.5).dx, p(5.5, 7.5).dy)
          ..lineTo(p(5.5, 4.5).dx, p(5.5, 4.5).dy)
          ..arcToPoint(p(7.5, 2.5), radius: Radius.circular(2 * scale))
          ..lineTo(p(15.5, 2.5).dx, p(15.5, 2.5).dy)
          ..arcToPoint(p(17.5, 4.5), radius: Radius.circular(2 * scale))
          ..lineTo(p(17.5, 7.5).dx, p(17.5, 7.5).dy);
        canvas.drawPath(back, paint);
        final front = RRect.fromRectAndRadius(
          Rect.fromPoints(p(2.5, 7.5), p(14.5, 17.5)),
          Radius.circular(2 * scale),
        );
        canvas.drawRRect(front, paint);
      case LineTabIcon.stats:
        // Three bars of different heights.
        canvas.drawLine(p(4.5, 12.5), p(4.5, 16.5), paint);
        canvas.drawLine(p(10, 7.5), p(10, 16.5), paint);
        canvas.drawLine(p(15.5, 3.5), p(15.5, 16.5), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _LineTabIconPainter oldDelegate) =>
      oldDelegate.icon != icon ||
      oldDelegate.color != color ||
      oldDelegate.strokeWidth != strokeWidth;
}
