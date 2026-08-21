import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/muse_colors.dart';

/// Animated equalizer bars that mark the currently playing song or the
/// currently playing playlist. Bars dance while [playing]; when paused they
/// freeze at a low, steady height. Always animating is fine — this widget is
/// tiny, so repaint cost is negligible.
class PlayingIndicator extends StatefulWidget {
  const PlayingIndicator({
    super.key,
    this.playing = true,
    this.size = 20,
    this.color = MuseColors.gold,
  });

  final bool playing;
  final double size;
  final Color color;

  @override
  State<PlayingIndicator> createState() => _PlayingIndicatorState();
}

class _PlayingIndicatorState extends State<PlayingIndicator>
    with SingleTickerProviderStateMixin {
  static const _barCount = 3;

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat();

  @override
  void didUpdateWidget(PlayingIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.playing != oldWidget.playing) {
      if (widget.playing) {
        _controller.repeat();
      } else {
        _controller.stop();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final barWidth = math.max(2.0, widget.size * 0.12);
    final spacing = math.max(1.5, widget.size * 0.1);
    return SizedBox(
      width: _barCount * barWidth + (_barCount - 1) * spacing,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              for (var i = 0; i < _barCount; i++) ...[
                if (i > 0) SizedBox(width: spacing),
                Container(
                  width: barWidth,
                  height: widget.size * _heightFactor(i),
                  decoration: BoxDecoration(
                    color: widget.color,
                    borderRadius: BorderRadius.circular(barWidth),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  double _heightFactor(int index) {
    if (!widget.playing) return 0.35;
    final value = _controller.value;
    // Three bars with staggered phases so they never rise in unison.
    final phase = index * math.pi / 3;
    final wave = (math.sin(2 * math.pi * value + phase)).abs();
    return 0.25 + 0.75 * wave;
  }
}