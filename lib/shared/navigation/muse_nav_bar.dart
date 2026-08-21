import 'package:flutter/material.dart';

import '../../core/theme/muse_colors.dart';
import '../../core/theme/muse_text_theme.dart';
import 'muse_wave.dart';

/// Data for the four non-home destinations. Home sits at nav index 2 and is
/// rendered as the medallion, so this list maps to nav indices 0,1,3,4.
const List<MuseNavItemData> museNavItems = [
  MuseNavItemData(Icons.library_music_outlined, 'Library'),
  MuseNavItemData(Icons.search_rounded, 'Search'),
  MuseNavItemData(Icons.tune_rounded, 'Settings'),
  MuseNavItemData(Icons.wifi_tethering_rounded, 'Stream'),
];

class MuseNavItemData {
  const MuseNavItemData(this.icon, this.label);

  final IconData icon;
  final String label;
}

/// Floating marble "plinth" navigation bar. The pill is card-surface with a
/// gold hairline and fully rounded ends; the Home medallion rises above its
/// top edge like a temple button resting on a platform. No glass, no
/// gradients, no shadows.
class MuseNavBar extends StatelessWidget {
  const MuseNavBar({
    super.key,
    required this.activeIndex,
    required this.onSelect,
  });

  final int activeIndex;
  final ValueChanged<int> onSelect;

  static const double _pillHeight = 56;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, bottomInset + 8),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: const BorderRadius.all(Radius.circular(28)),
          border: Border.all(color: MuseColors.gold, width: 3),
        ),
        child: Material(
          color: Colors.transparent,
          clipBehavior: Clip.antiAlias,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(28)),
          ),
          child: SizedBox(
            height: _pillHeight,
            child: Row(
            children: [
              const _EndChevron(Icons.chevron_left_rounded),
              Expanded(
                child: MuseNavItem(
                  item: museNavItems[0],
                  active: activeIndex == 0,
                  onTap: () => onSelect(0),
                ),
              ),
              Expanded(
                child: MuseNavItem(
                  item: museNavItems[1],
                  active: activeIndex == 1,
                  onTap: () => onSelect(1),
                ),
              ),
              Expanded(
                child: MuseHomeMedallion(
                  active: activeIndex == 2,
                  onTap: () => onSelect(2),
                ),
              ),
              Expanded(
                child: MuseNavItem(
                  item: museNavItems[2],
                  active: activeIndex == 3,
                  onTap: () => onSelect(3),
                ),
              ),
              Expanded(
                child: MuseNavItem(
                  item: museNavItems[3],
                  active: activeIndex == 4,
                  onTap: () => onSelect(4),
                ),
              ),
              const _EndChevron(Icons.chevron_right_rounded),
            ],
          ),
        ),
        ),
      ),
    );
  }
}

class _EndChevron extends StatelessWidget {
  const _EndChevron(this.icon);

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 18,
      child: Icon(icon, size: 18, color: MuseColors.gold.withValues(alpha: 0.4)),
    );
  }
}

/// A nav destination rendered as a small icon + tiny label.
class MuseNavItem extends StatelessWidget {
  const MuseNavItem({
    super.key,
    required this.item,
    required this.active,
    required this.onTap,
  });

  final MuseNavItemData item;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = active ? MuseColors.gold : MuseColors.textSecondary;

    return Semantics(
      label: item.label,
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(item.icon, size: 20, color: color),
            const SizedBox(height: 3),
            Text(
              item.label,
              style: TextStyle(
                fontFamily: MuseFonts.body,
                fontSize: 8,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The center Home destination: a marble medallion with a full gold ring,
/// raised above the nav pill. Active state fills solid gold.
class MuseHomeMedallion extends StatelessWidget {
  const MuseHomeMedallion({
    super.key,
    required this.active,
    required this.onTap,
  });

  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Home',
      button: true,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: active ? MuseColors.gold : MuseColors.baseSurface,
            border: Border.all(color: MuseColors.gold, width: 1.5),
          ),
          child: Padding(
            padding: const EdgeInsets.all(7),
            child: MuseWave(
              color: active ? MuseColors.baseSurface : MuseColors.gold,
            ),
          ),
        ),
      ),
    );
  }
}