import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/muse_colors.dart';
import 'muse_nav_bar.dart';

/// Slim marble sidebar for landscape/desktop layouts. Same five
/// destinations as the portrait nav bar, stacked vertically.
class MuseSidebar extends StatelessWidget {
  const MuseSidebar({
    super.key,
    required this.activeIndex,
    required this.onSelect,
  });

  final int activeIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.of(context).padding;

    return Padding(
      padding: EdgeInsets.only(
        left: math.max(padding.left, 12),
        top: math.max(padding.top, 12),
        bottom: math.max(padding.bottom, 12),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: const BorderRadius.all(Radius.circular(24)),
          border: Border.all(color: MuseColors.gold, width: 3),
        ),
        child: Material(
          color: Colors.transparent,
          clipBehavior: Clip.antiAlias,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(24)),
          ),
          child: SizedBox(
            width: 72,
            child: Column(
              children: [
                const SizedBox(height: 18),
                for (var i = 0; i < 5; i++)
                  Expanded(
                    child: Center(
                      child: i == 2
                          ? MuseHomeMedallion(
                              active: activeIndex == i,
                              onTap: () => onSelect(i),
                            )
                          : MuseNavItem(
                              item: museNavItems[i < 2 ? i : i - 1],
                              active: activeIndex == i,
                              onTap: () => onSelect(i),
                            ),
                    ),
                  ),
                const SizedBox(height: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }
}