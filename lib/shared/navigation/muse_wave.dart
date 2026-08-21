import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Animated equalizer wave made of the 26 vertical bars from the app icon's
/// layer2 (two tall central peaks, symmetric sides). Each bar's height pulses
/// on a per-bar phase so the wave ripples outward like an audio visualizer.
class MuseWave extends StatefulWidget {
  const MuseWave({super.key, required this.color});

  final Color color;

  @override
  State<MuseWave> createState() => _MuseWaveState();
}

class _MuseWaveState extends State<MuseWave>
    with SingleTickerProviderStateMixin {
  /// Bar heights normalized from the icon's layer2 rects (max = 1.0),
  /// ordered left to right.
  static const List<double> _baseHeights = [
    0.044, 0.121, 0.223, 0.375, 0.518, 0.342, 0.196, 0.196, 0.388, 0.640,
    0.641, 0.854, 1.000, 1.000, 0.854, 0.641, 0.640, 0.388, 0.196, 0.196,
    0.342, 0.518, 0.375, 0.223, 0.121, 0.044,
  ];

  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double _pulse(int index, double t) {
    final wave = (math.sin(2 * math.pi * t + index * 0.35) + 1) / 2;
    return wave.clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value;
        return LayoutBuilder(
          builder: (context, constraints) {
            const gap = 0.6;
            final rawBarWidth =
                (constraints.maxWidth - gap * (_baseHeights.length - 1)) /
                    _baseHeights.length;
            final barWidth = math.max(0.4, rawBarWidth);
            final maxHeight = constraints.maxHeight;

            return FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  for (var i = 0; i < _baseHeights.length; i++)
                    Padding(
                      padding: EdgeInsets.only(
                        right: i == _baseHeights.length - 1 ? 0 : gap,
                      ),
                      child: Container(
                        width: barWidth,
                        height: maxHeight *
                            _baseHeights[i] *
                            (0.35 + 0.65 * _pulse(i, t)),
                        decoration: BoxDecoration(
                          color: widget.color,
                          borderRadius: BorderRadius.circular(barWidth / 2),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}