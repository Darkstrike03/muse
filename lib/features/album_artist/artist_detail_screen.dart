import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/muse_spacing.dart';
import '../../core/widgets/playing_indicator.dart';
import '../../shared/navigation/mini_player_bar.dart';
import '../library/album_art.dart';
import '../library/library_provider.dart';
import '../playback/playback_controller.dart';

/// Artist detail — the artist's albums and songs from the local library.
class ArtistDetailScreen extends ConsumerWidget {
  const ArtistDetailScreen({super.key, required this.artist});

  final String artist;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final albums = ref.watch(libraryAlbumsProvider);
    final currentId =
        ref.watch(playbackControllerProvider.select((s) => s.current?.id));
    final playing =
        ref.watch(playbackControllerProvider.select((s) => s.playing));
    final artistAlbums =
        albums.where((a) => a.artist == artist).toList(growable: false);
    final tracks = artistAlbums.expand((a) => a.tracks).toList(growable: false);

    if (artistAlbums.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Artist')),
        bottomNavigationBar: const MiniPlayerBar(),
        body: SafeArea(
          child: Center(
            child: Text('Artist not found.',
                style: theme.textTheme.bodySmall),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Artist')),
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
                    (constraints.maxWidth - 40).clamp(56.0, 96.0);
                return Row(
                  children: [
                    AlbumArt(albumId: artistAlbums.first.id,
                        size: medallionSize),
                    const SizedBox(width: MuseSpacing.xl),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(artist,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.headlineLarge),
                          const SizedBox(height: MuseSpacing.xs),
                          Text(
                            artistAlbums.length == 1
                                ? '1 album in your library'
                                : '${artistAlbums.length} albums in your library',
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: MuseSpacing.xxl),
            Text('Albums', style: theme.textTheme.titleLarge),
            const SizedBox(height: MuseSpacing.md),
            ...artistAlbums.map(
              (album) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: AlbumArt(albumId: album.id, size: 48),
                title: Text(album.title, style: theme.textTheme.titleSmall),
                subtitle: Text('${album.tracks.length} songs',
                    style: theme.textTheme.bodySmall),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => context.push(MusePaths.albumFor(album.id)),
              ),
            ),
            const SizedBox(height: MuseSpacing.xxl),
            Text('Songs', style: theme.textTheme.titleLarge),
            const SizedBox(height: MuseSpacing.md),
            ...tracks.map(
              (track) {
                final isCurrent = track.id == currentId;
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: AlbumArt(albumId: track.albumId, size: 40),
                  title: Text(
                    track.title,
                    style: isCurrent
                        ? theme.textTheme.titleSmall?.copyWith(
                            color: theme.colorScheme.primary,
                          )
                        : theme.textTheme.titleSmall,
                  ),
                  subtitle: Text(track.albumTitle.isNotEmpty
                      ? track.albumTitle
                      : track.albumId, style: theme.textTheme.bodySmall),
                  trailing: isCurrent
                      ? PlayingIndicator(playing: playing)
                      : null,
                  onTap: () => openPlayer(context, track),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}