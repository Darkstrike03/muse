import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/muse_colors.dart';
import '../../core/theme/muse_spacing.dart';
import '../../core/widgets/gold_button.dart';
import '../../core/widgets/medallion_art.dart';
import '../../core/widgets/playing_indicator.dart';
import '../../core/widgets/section_heading.dart';
import '../playback/playback_controller.dart';
import '../playlist/playlist_art.dart';
import '../playlist/playlist_dialogs.dart';
import '../playlist/playlists_provider.dart';
import 'album_art.dart';
import 'library_provider.dart';

/// Library — calm, grid/list-based. No pediment or columns here.
enum _LibraryView { songs, albums, artists, playlists }

class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: _LibraryView.values.length,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(
                MuseSpacing.page, MuseSpacing.lg, MuseSpacing.page, MuseSpacing.lg),
            child: SectionHeading(title: 'Library'),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: MuseSpacing.page),
            child: TabBar(
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              tabs: const [
                Tab(text: 'Songs'),
                Tab(text: 'Albums'),
                Tab(text: 'Artists'),
                Tab(text: 'Playlists'),
              ],
            ),
          ),
          const SizedBox(height: MuseSpacing.sm),
          const Expanded(
            child: TabBarView(
              children: [
                _SongsTab(),
                _AlbumsTab(),
                _ArtistsTab(),
                _PlaylistsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SongsTab extends ConsumerWidget {
  const _SongsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final library = ref.watch(libraryProvider);
    final currentId =
        ref.watch(playbackControllerProvider.select((s) => s.current?.id));
    final playing =
        ref.watch(playbackControllerProvider.select((s) => s.playing));

    return library.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(MuseSpacing.xl),
          child: Text(
            'Could not scan your music.',
            style: theme.textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ),
      ),
      data: (tracks) {
        if (tracks.isEmpty) {
          return const _EmptyLibrary();
        }
        return ListView.separated(
          padding: const EdgeInsets.symmetric(
            horizontal: MuseSpacing.page,
            vertical: MuseSpacing.sm,
          ),
          itemCount: tracks.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, i) {
            final track = tracks[i];
            final isCurrent = track.id == currentId;
            return ListTile(
              contentPadding: EdgeInsets.zero,
              leading: AlbumArt(albumId: track.albumId, size: 40),
              title: Text(
                track.title,
                style: isCurrent
                    ? theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.primary,
                      )
                    : theme.textTheme.titleMedium,
              ),
              subtitle: Text(track.artist, style: theme.textTheme.bodySmall),
              trailing: isCurrent
                  ? PlayingIndicator(playing: playing)
                  : null,
              onTap: () => openPlayer(context, track),
            );
          },
        );
      },
    );
  }
}

class _AlbumsTab extends ConsumerWidget {
  const _AlbumsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final library = ref.watch(libraryProvider);
    final albums = ref.watch(libraryAlbumsProvider);

    return library.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(MuseSpacing.xl),
          child: Text(
            'Could not scan your music.',
            style: theme.textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ),
      ),
      data: (_) {
        if (albums.isEmpty) {
          return const _EmptyLibrary();
        }
        return GridView.builder(
          padding: const EdgeInsets.symmetric(
            horizontal: MuseSpacing.page,
            vertical: MuseSpacing.sm,
          ),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 160,
            mainAxisSpacing: MuseSpacing.lg,
            crossAxisSpacing: MuseSpacing.lg,
            mainAxisExtent: 212,
          ),
          itemCount: albums.length,
          itemBuilder: (context, i) {
            final album = albums[i];
            return InkWell(
              onTap: () => context.push(MusePaths.albumFor(album.id)),
              child: Column(
                children: [
                  const SizedBox(height: MuseSpacing.sm),
                  AlbumArt(albumId: album.id, size: 128),
                  const SizedBox(height: MuseSpacing.sm),
                  Text(album.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall),
                  Text(album.artist,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _ArtistsTab extends ConsumerWidget {
  const _ArtistsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final library = ref.watch(libraryProvider);
    final artists = ref.watch(libraryArtistsProvider);

    return library.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(MuseSpacing.xl),
          child: Text(
            'Could not scan your music.',
            style: theme.textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ),
      ),
      data: (_) {
        if (artists.isEmpty) {
          return const _EmptyLibrary();
        }
        return ListView.separated(
          padding: const EdgeInsets.symmetric(
            horizontal: MuseSpacing.page,
            vertical: MuseSpacing.sm,
          ),
          itemCount: artists.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, i) {
            final artist = artists[i];
            return ListTile(
              contentPadding: EdgeInsets.zero,
              leading: MedallionArt(size: 40),
              title: Text(artist, style: theme.textTheme.titleMedium),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => context.push(MusePaths.artistFor(artist)),
            );
          },
        );
      },
    );
  }
}

class _PlaylistsTab extends ConsumerWidget {
  const _PlaylistsTab();

  Future<void> _createPlaylist(BuildContext context, WidgetRef ref) async {
    final name = await showPlaylistNameDialog(context);
    if (name == null) return;
    final created = await ref.read(playlistsProvider.notifier).create(name);
    if (created != null && context.mounted) {
      context.push(MusePaths.playlistFor(created.id));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final playlists = ref.watch(playlistsProvider);
    final sourceId =
        ref.watch(playbackControllerProvider.select((s) => s.sourceId));
    final playing =
        ref.watch(playbackControllerProvider.select((s) => s.playing));

    return playlists.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => Center(
        child: Text('Could not load your playlists.',
            style: theme.textTheme.bodyMedium),
      ),
      data: (items) {
        if (items.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(MuseSpacing.xxl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  MedallionArt(size: 72, placeholder: const SizedBox()),
                  const SizedBox(height: MuseSpacing.lg),
                  Text('No playlists yet',
                      style: theme.textTheme.titleMedium),
                  const SizedBox(height: MuseSpacing.sm),
                  Text(
                    'Playlists you create here can later be shared directly '
                    'with a paired device.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: MuseSpacing.xl),
                  GoldButton(
                    label: 'New playlist',
                    icon: Icons.add_rounded,
                    onPressed: () => _createPlaylist(context, ref),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView(
          padding: const EdgeInsets.symmetric(
            horizontal: MuseSpacing.page,
            vertical: MuseSpacing.sm,
          ),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: () => _createPlaylist(context, ref),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('New playlist'),
              ),
            ),
            const SizedBox(height: MuseSpacing.md),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 160,
                mainAxisSpacing: MuseSpacing.lg,
                crossAxisSpacing: MuseSpacing.lg,
                mainAxisExtent: 190,
              ),
              itemCount: items.length,
              itemBuilder: (context, i) {
                final playlist = items[i];
                final isPlayingSource = playlist.id == sourceId;
                return InkWell(
                  onTap: () =>
                      context.push(MusePaths.playlistFor(playlist.id)),
                  child: Column(
                    children: [
                      const SizedBox(height: MuseSpacing.sm),
                      Stack(
                        children: [
                          PlaylistArt(
                            imagePath: playlist.imagePath,
                            size: 128,
                          ),
                          if (isPlayingSource)
                            Positioned(
                              right: 0,
                              bottom: 0,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: MuseColors.cardSurface,
                                  border: Border.all(
                                    color: MuseColors.gold,
                                    width: 1.5,
                                  ),
                                ),
                                child: PlayingIndicator(
                                  playing: playing,
                                  size: 16,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: MuseSpacing.sm),
                      Text(playlist.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: isPlayingSource
                              ? theme.textTheme.titleSmall?.copyWith(
                                  color: theme.colorScheme.primary,
                                )
                              : theme.textTheme.titleSmall),
                      Text(
                        playlist.isRemote
                            ? 'Shared · ${playlist.trackIds.length} songs'
                            : '${playlist.trackIds.length} songs',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }
}

/// Shown when the library is empty (no folders configured or nothing found).
class _EmptyLibrary extends StatelessWidget {
  const _EmptyLibrary();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(MuseSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            MedallionArt(size: 72, placeholder: const SizedBox()),
            const SizedBox(height: MuseSpacing.lg),
            Text('No music yet', style: theme.textTheme.titleMedium),
            const SizedBox(height: MuseSpacing.sm),
            Text(
              'Add a music folder in Settings to build your library.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: MuseSpacing.xl),
            GoldButton(
              label: 'Open Settings',
              icon: Icons.settings_rounded,
              onPressed: () => context.push(MusePaths.settings),
            ),
          ],
        ),
      ),
    );
  }
}