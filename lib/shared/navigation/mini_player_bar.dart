import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/muse_colors.dart';
import '../../core/theme/muse_spacing.dart';
import '../../features/library/album_art.dart';
import '../../features/playback/playback_controller.dart';

/// Slim persistent "now playing" bar shown whenever a song is playing: album
/// art, title/artist, play-pause and next. Tapping the track info opens the
/// full Now Playing screen without restarting playback. Returns nothing when
/// the player is idle, so it never wastes layout space.
class MiniPlayerBar extends ConsumerWidget {
  const MiniPlayerBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final current =
        ref.watch(playbackControllerProvider.select((s) => s.current));
    if (current == null) return const SizedBox.shrink();

    final track = current;
    final playing =
        ref.watch(playbackControllerProvider.select((s) => s.playing));
    final notifier = ref.read(playbackControllerProvider.notifier);

    return Material(
      color: MuseColors.cardSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: MuseColors.goldHairline, width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        height: 54,
        child: Row(
          children: [
            const SizedBox(width: MuseSpacing.sm),
            AlbumArt(albumId: track.albumId, size: 40),
            const SizedBox(width: MuseSpacing.md),
            Expanded(
              child: InkWell(
                onTap: () => openNowPlaying(context, track),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      track.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      track.artist,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: MuseSpacing.sm),
            IconButton(
              tooltip: playing ? 'Pause' : 'Play',
              onPressed: notifier.togglePlay,
              iconSize: 30,
              icon: Icon(
                playing
                    ? Icons.pause_circle_filled_rounded
                    : Icons.play_circle_filled_rounded,
                color: theme.colorScheme.primary,
              ),
            ),
            IconButton(
              tooltip: 'Next',
              onPressed: notifier.next,
              iconSize: 28,
              icon: const Icon(Icons.skip_next_rounded),
            ),
            const SizedBox(width: MuseSpacing.xs),
          ],
        ),
      ),
    );
  }
}