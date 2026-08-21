import 'package:flutter/material.dart';

import '../../core/theme/muse_colors.dart';
import '../../core/theme/muse_spacing.dart';

/// Collapsing app header: the "muse" wordmark with a pair action, and a thin
/// gold progress line that fills while the user pulls to refresh.
class MuseHeader extends StatelessWidget {
  const MuseHeader({
    super.key,
    required this.visible,
    required this.pullProgress,
    required this.refreshing,
    required this.onPairTap,
  });

  final bool visible;
  final double pullProgress;
  final bool refreshing;
  final VoidCallback onPairTap;

  static const double contentHeight = 56;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final topInset = MediaQuery.of(context).padding.top;

    return IgnorePointer(
      ignoring: !visible,
      child: AnimatedSlide(
        offset: visible ? Offset.zero : const Offset(0, -1),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        child: AnimatedOpacity(
          opacity: visible ? 1 : 0,
          duration: const Duration(milliseconds: 200),
child: SizedBox(
          height: topInset + contentHeight,
          child: Stack(
            children: [
              Positioned(
                top: topInset,
                left: 0,
                right: 0,
                child: SizedBox(
                  height: contentHeight,
                  child: Row(
                    children: [
                      const SizedBox(width: MuseSpacing.page),
                      if (refreshing) ...[
                        const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: MuseColors.gold,
                          ),
                        ),
                        const SizedBox(width: MuseSpacing.sm),
                      ],
                      Text('muse', style: theme.textTheme.titleLarge),
                      const Spacer(),
                      IconButton(
                        tooltip: 'Pair a device',
                        onPressed: onPairTap,
                        icon: const Icon(Icons.link_rounded),
                      ),
                      const SizedBox(width: MuseSpacing.sm),
                    ],
                  ),
                ),
              ),
              // Pull-to-refresh progress line.
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: SizedBox(
                  height: 2,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      const Align(
                        alignment: Alignment.bottomCenter,
                        child: SizedBox(
                          height: 1,
                          width: double.infinity,
                          child: ColoredBox(color: MuseColors.goldHairline),
                        ),
                      ),
                      FractionallySizedBox(
                        widthFactor:
                            (pullProgress.clamp(0.0, 1.0)).toDouble(),
                        alignment: Alignment.centerLeft,
                        child: const ColoredBox(color: MuseColors.gold),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        ),
      ),
    );
  }
}