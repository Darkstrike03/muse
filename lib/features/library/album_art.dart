import 'dart:io';
import 'dart:typed_data';

import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/muse_colors.dart';
import '../../core/widgets/medallion_art.dart';
import '../../shared/models/track.dart';
import 'library_provider.dart';

const _coverBaseNames = {'cover', 'folder', 'front', 'album'};

/// Resolves album art for an album id: embedded front cover from the album's
/// first audio file, falling back to a cover image file (cover/folder/front/
/// album .jpg/.png) sitting beside the music. `null` when nothing is found —
/// widgets fall back to the monogram medallion.
final albumArtProvider = FutureProvider.family<Uint8List?, String>(
  (ref, albumId) async {
    final tracks = ref.watch(libraryProvider).value ?? const [];
    Track? first;
    for (final track in tracks) {
      final path = track.filePath;
      if (track.albumId == albumId && path != null && path.isNotEmpty) {
        first = track;
        break;
      }
    }
    if (first == null) return null;

    final file = File(first.filePath!);

    // 1. Embedded artwork from the file itself.
    try {
      final meta = readMetadata(file, getImage: true);
      for (final picture in meta.pictures) {
        if (picture.pictureType == PictureType.coverFront ||
            picture.pictureType == PictureType.other) {
          return picture.bytes;
        }
      }
    } catch (_) {
      // No readable tags — fall through to cover files.
    }

    // 2. Cover image files next to the audio.
    return _findCoverFile(file.parent);
  },
);

Future<Uint8List?> _findCoverFile(Directory dir) async {
  try {
    await for (final entity in dir.list(followLinks: false)) {
      if (entity is! File) continue;
      final name = entity.uri.pathSegments.last.toLowerCase();
      final dot = name.lastIndexOf('.');
      if (dot <= 0) continue;
      final base = name.substring(0, dot);
      final ext = name.substring(dot + 1);
      if ((ext == 'jpg' || ext == 'jpeg' || ext == 'png') &&
          _coverBaseNames.contains(base)) {
        return entity.readAsBytesSync();
      }
    }
  } catch (_) {
    // Unreadable directory — treat as no cover.
  }
  return null;
}

/// Medallion with the album's artwork when available; the monogram fallback
/// otherwise. Watch this in list/grid tiles — it is cached per album.
class AlbumArt extends ConsumerWidget {
  const AlbumArt({
    super.key,
    required this.albumId,
    this.size = 96,
    this.ringColor = MuseColors.gold,
  });

  final String albumId;
  final double size;
  final Color ringColor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bytes = ref.watch(albumArtProvider(albumId)).value;
    return MedallionArt(
      size: size,
      image: bytes == null ? null : MemoryImage(bytes),
      ringColor: ringColor,
    );
  }
}