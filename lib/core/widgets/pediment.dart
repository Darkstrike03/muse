import 'package:flutter/material.dart';

import '../theme/muse_colors.dart';

/// Subtle triangular pediment linework used at the top of hero/anchor
/// screens only (onboarding, now playing).
class Pediment extends StatelessWidget {
  const Pediment({
    super.key,
    this.width = 260,
    this.height = 84,
    this.color = MuseColors.gold,
    this.strokeWidth = 1.4,
  });

  final double width;
  final double height;
  final Color color;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(width, height),
      painter: _PedimentPainter(color: color, strokeWidth: strokeWidth),
    );
  }
}

class _PedimentPainter extends CustomPainter {
  _PedimentPainter({required this.color, required this.strokeWidth});

  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeJoin = StrokeJoin.miter;

    final apex = Offset(w / 2, h * 0.12);
    final left = Offset(w * 0.02, h * 0.62);
    final right = Offset(w * 0.98, h * 0.62);
    final baseLeft = Offset(w * 0.12, h * 0.88);
    final baseRight = Offset(w * 0.88, h * 0.88);

    // Triangle roofline (left edge, rake, right edge).
    final tri = Path()
      ..moveTo(left.dx, left.dy)
      ..lineTo(apex.dx, apex.dy)
      ..lineTo(right.dx, right.dy)
      ..close();
    canvas.drawPath(tri, paint);

    // Cornice beneath the triangle.
    canvas.drawLine(baseLeft, baseRight, paint);
  }

  @override
  bool shouldRepaint(_PedimentPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.strokeWidth != strokeWidth;
}