import 'package:flutter/material.dart';

import '../theme/muse_colors.dart';

/// A slim Doric column graphic (capital / shaft / base) drawn in thin
/// gold linework.
///
/// Usage rule from the spec: hero/anchor screens only (now playing,
/// onboarding). Not used on Home/Library/Settings.
class ColumnDivider extends StatelessWidget {
  const ColumnDivider({
    super.key,
    this.width = 18,
    this.height = 220,
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
      painter: _ColumnPainter(color: color, strokeWidth: strokeWidth),
    );
  }
}

class _ColumnPainter extends CustomPainter {
  _ColumnPainter({required this.color, required this.strokeWidth});

  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    // Proportions (Doric order, simplified).
    final capitalTop = h * 0.06;
    final capitalBottom = h * 0.13; // abacus + echinus
    final baseTop = h * 0.92;
    final baseBottom = h * 0.98;
    final shaftTop = capitalBottom;
    final shaftBottom = baseTop;

    // Capital: abacus bar, then echinus flaring down to the shaft.
    canvas.drawLine(Offset(w * 0.1, capitalTop), Offset(w * 0.9, capitalTop), paint);
    canvas.drawLine(Offset(w * 0.15, capitalBottom), Offset(w * 0.85, capitalBottom), paint);
    canvas.drawLine(Offset(w * 0.1, capitalTop), Offset(w * 0.15, capitalBottom), paint);
    canvas.drawLine(Offset(w * 0.9, capitalTop), Offset(w * 0.85, capitalBottom), paint);

    // Shaft: two tapering vertical lines.
    canvas.drawLine(
        Offset(w * 0.28, shaftTop), Offset(w * 0.3, shaftBottom), paint);
    canvas.drawLine(
        Offset(w * 0.72, shaftTop), Offset(w * 0.7, shaftBottom), paint);

    // Base: plinth with a steeper flare.
    canvas.drawLine(Offset(w * 0.22, baseTop), Offset(w * 0.78, baseTop), paint);
    canvas.drawLine(Offset(w * 0.15, baseBottom), Offset(w * 0.85, baseBottom), paint);
    canvas.drawLine(Offset(w * 0.22, baseTop), Offset(w * 0.15, baseBottom), paint);
    canvas.drawLine(Offset(w * 0.78, baseTop), Offset(w * 0.85, baseBottom), paint);
  }

  @override
  bool shouldRepaint(_ColumnPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.strokeWidth != strokeWidth;
}