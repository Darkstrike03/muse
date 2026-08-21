import 'package:flutter/material.dart';

import '../theme/muse_colors.dart';

/// Thin horizontal Greek key / meander pattern divider.
///
/// Usage rule from the spec: max once per screen, used as a single
/// decorative section divider.
class MeanderDivider extends StatelessWidget {
  const MeanderDivider({
    super.key,
    this.height = 16,
    this.color = MuseColors.gold,
    this.strokeWidth = 1.2,
  });

  final double height;
  final Color color;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(double.infinity, height),
      painter: _MeanderPainter(color: color, strokeWidth: strokeWidth),
    );
  }
}

class _MeanderPainter extends CustomPainter {
  _MeanderPainter({required this.color, required this.strokeWidth});

  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    // One period = W wide, H tall. The line is a single continuous stroke.
    final h = size.height;
    final w = h * 2;
    final path = Path();
    var startX = -(size.width % w);

    // Walk periods across the canvas so the pattern tiles seamlessly.
    for (double x = startX; x <= size.width + 1; x += w) {
      path
        ..moveTo(x, h)
        ..lineTo(x, h / 2)
        ..lineTo(x + w / 4, h / 2)
        ..lineTo(x + w / 4, h)
        ..lineTo(x + w / 2, h)
        ..lineTo(x + w / 2, 0)
        ..lineTo(x + w, 0)
        ..lineTo(x + w, h);
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_MeanderPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.strokeWidth != strokeWidth;
}