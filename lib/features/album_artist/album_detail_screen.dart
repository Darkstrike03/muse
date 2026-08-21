import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/muse_spacing.dart';
import '../../core/widgets/gold_button.dart';
import '../../core/widgets/playing_indicator.dart';
import '../../shared/models/album.dart';
import '../../shared/models/track.dart';
import '../../shared/navigation/mini_player_bar.dart';
import '../library/album_art.dart';
import '../library/library_provider.dart';
import '../playback/playback_controller.dart';

/// Album detail — medallion art, Cinzel headings, gold accents, real tracks
/// from the scanned library.
class AlbumDetailScreen extends ConsumerWidget {
  const AlbumDetailScreen({super.key, required this.albumId});

  final String albumId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final albums = ref.watch(libraryAlbumsProvider);
    Album? album;
    for (final a in albums) {
      if (a.id == albumId) {
        album = a;
        break;
      }
    }

    if (album == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Album')),
        bottomNavigationBar: const MiniPlayerBar(),
        body: SafeArea(
          child: Center(
            child: Text('Album not found.',
                style: theme.textTheme.bodySmall),
          ),
        ),
      );
    }

    // Promote to a non-null local so closures below can capture it safely.
    final found = album;

    return Scaffold(
      appBar: AppBar(title: Text(found.title)),
      bottomNavigationBar: const MiniPlayerBar(),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(
            horizontal: MuseSpacing.page,
            vertical: MuseSpacing.md,
          ),
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final medallionSize =
                    (constraints.maxWidth - 48).clamp(72.0, 144.0);
                return Row(
                  children: [
                    AlbumArt(albumId: found.id, size: medallionSize),
                    const SizedBox(width: MuseSpacing.xl),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(found.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.headlineLarge),
                          const SizedBox(height: MuseSpacing.xs),
                          Text(found.artist,
                              style: theme.textTheme.bodyLarge?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              )),
                          const SizedBox(height: MuseSpacing.xs),
                          Text(
                            found.tracks.length == 1
                                ? '1 song'
                                : '${found.tracks.length} songs',
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: MuseSpacing.xl),
            GoldButton(
              label: 'Play album',
              icon: Icons.play_arrow_rounded,
              expand: true,
              onPressed: found.tracks.isEmpty
                  ? null
                  : () => openPlayer(context, found.tracks.first),
            ),
            const SizedBox(height: MuseSpacing.lg),
            ..._buildTrackTiles(theme, found),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildTrackTiles(ThemeData theme, Album album) {
    return [
      for (final (i, track) in album.tracks.indexed)
        _TrackRow(index: i, track: track),
      if (album.tracks.isEmpty)
        Padding(
          padding: const EdgeInsets.all(MuseSpacing.xl),
          child: Text('No tracks yet.', style: theme.textTheme.bodySmall),
        ),
    ];
  }
}

class _TrackRow extends ConsumerWidget {
  const _TrackRow({required this.index, required this.track});

  final int index;
  final Track track;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final currentId =
        ref.watch(playbackControllerProvider.select((s) => s.current?.id));
    final playing =
        ref.watch(playbackControllerProvider.select((s) => s.playing));
    final isCurrent = track.id == currentId;
    String fmt(Duration d) {
      final m = d.inMinutes;
      final s = (d.inSeconds % 60).toString().padLeft(2, '0');
      return '$m:$s';
    }

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: SizedBox(
        width: 32,
        child: Text('${index + 1}',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            )),
      ),
      title: Text(
        track.title,
        style: isCurrent
            ? theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.primary,
              )
            : theme.textTheme.titleSmall,
      ),
      trailing: isCurrent
          ? PlayingIndicator(playing: playing)
          : Text(fmt(track.duration), style: theme.textTheme.labelSmall),
      onTap: () => openPlayer(context, track),
    );
  }
}