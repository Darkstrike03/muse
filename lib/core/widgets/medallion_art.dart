import 'package:flutter/material.dart';

import '../theme/muse_colors.dart';
import '../theme/muse_text_theme.dart';

/// Circular medallion album art with a thin (1.5px) gold ring border.
///
/// The recurring album-art motif — used everywhere album art appears,
/// including small list thumbnails (always circles, never squares).
class MedallionArt extends StatelessWidget {
  const MedallionArt({
    super.key,
    this.size = 96,
    this.image,
    this.placeholder,
    this.ringColor = MuseColors.gold,
  });

  final double size;
  final ImageProvider? image;
  final Widget? placeholder;
  final Color ringColor;

  @override
  Widget build(BuildContext context) {
    if (!size.isFinite) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final bounded = constraints.biggest.shortestSide;
          final s = (bounded.isFinite && bounded > 0)
              ? bounded
              : 96.0;
          return _build(s);
        },
      );
    }
    return _build(size);
  }

  Widget _build(double s) {
    final inner = image != null
        ? Image(
            image: image!,
            width: s,
            height: s,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => _Monogram(size: s),
          )
        : placeholder ?? _Monogram(size: s);

    return SizedBox(
      width: s,
      height: s,
      child: Stack(
        children: [
          ClipOval(
            child: SizedBox(width: s, height: s, child: inner),
          ),
          Container(
            width: s,
            height: s,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: ringColor, width: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _Monogram extends StatelessWidget {
  const _Monogram({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: MuseColors.cardSurface,
      alignment: Alignment.center,
      child: Text(
        'M',
        style: TextStyle(
          fontFamily: MuseFonts.display,
          fontSize: size * 0.42,
          height: 1,
          color: MuseColors.gold.withValues(alpha: 0.55),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}