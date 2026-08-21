import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/widgets/medallion_art.dart';

/// Medallion for a playlist: its chosen image when set, the monogram fallback
/// otherwise. Missing/unreadable files fall back to the monogram too.
class PlaylistArt extends StatelessWidget {
  const PlaylistArt({
    super.key,
    required this.imagePath,
    this.size = 96,
  });

  final String? imagePath;
  final double size;

  @override
  Widget build(BuildContext context) {
    final path = imagePath;
    final image = (path == null || path.isEmpty) ? null : FileImage(File(path));
    return MedallionArt(
      size: size,
      image: image,
    );
  }
}