import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/muse_spacing.dart';
import '../../core/widgets/gold_button.dart';
import '../../core/widgets/medallion_art.dart';
import '../../core/widgets/meander_divider.dart';
import '../../core/widgets/section_heading.dart';
import '../../shared/models/album.dart';
import '../../shared/models/track.dart';
import '../library/album_art.dart';
import '../library/library_provider.dart';
import '../playback/playback_controller.dart';

/// Home — the calm, grid-based landing screen. Not a hero screen, so no
/// pediment or columns here.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final current =
        ref.watch(playbackControllerProvider.select((s) => s.current));
    final library = ref.watch(libraryProvider);
    final albums = ref.watch(libraryAlbumsProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(
        horizontal: MuseSpacing.page,
        vertical: MuseSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _NowPlayingCard(track: current),
          const SizedBox(height: MuseSpacing.xl),
          if (library.isLoading)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: MuseSpacing.lg),
              child: Text('Scanning your library…',
                  style: theme.textTheme.bodySmall),
            )
          else if (albums.isEmpty)
            const _EmptyLibraryCard()
          else ...[
            const MeanderDivider(),
            const SizedBox(height: MuseSpacing.xl),
            const SectionHeading(title: 'Recently Played'),
            const SizedBox(height: MuseSpacing.lg),
            _RecentList(albums: albums),
            const SizedBox(height: MuseSpacing.xxl),
            const SectionHeading(title: 'Albums', style: 'title'),
            const SizedBox(height: MuseSpacing.lg),
            _AlbumList(albums: albums),
          ],
        ],
      ),
    );
  }
}

/// When nothing is playing: a friendly prompt instead of a fake track.
class _NowPlayingCard extends ConsumerWidget {
  const _NowPlayingCard({required this.track});

  final Track? track;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    if (track == null) {
      return Card(
        child: InkWell(
          onTap: () => context.go(MusePaths.library),
          child: Padding(
            padding: const EdgeInsets.all(MuseSpacing.lg),
            child: Row(
              children: [
                const MedallionArt(size: 64),
                const SizedBox(width: MuseSpacing.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Nothing playing', style: theme.textTheme.labelSmall),
                      const SizedBox(height: MuseSpacing.xs),
                      Text('Pick a song from your library',
                          style: theme.textTheme.titleMedium),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded),
              ],
            ),
          ),
        ),
      );
    }

    final playing =
        ref.watch(playbackControllerProvider.select((s) => s.playing));
    final notifier = ref.read(playbackControllerProvider.notifier);
    return Card(
      child: InkWell(
        onTap: () => openNowPlaying(context, track!),
        child: Padding(
          padding: const EdgeInsets.all(MuseSpacing.lg),
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Keep the medallion + gaps inside the row even on narrow
              // windows: shrink the medallion instead of overflowing.
              final medallionSize =
                  (constraints.maxWidth - 96).clamp(48.0, 96.0);
              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  AlbumArt(albumId: track!.albumId, size: medallionSize),
                  const SizedBox(width: MuseSpacing.lg),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Now Playing',
                            style: theme.textTheme.labelSmall),
                        const SizedBox(height: MuseSpacing.xs),
                        Text(track!.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.headlineSmall),
                        const SizedBox(height: MuseSpacing.xs),
                        Text(track!.artist,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            )),
                        const SizedBox(height: MuseSpacing.sm),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Row(
                            children: [
                              IconButton(
                                onPressed: notifier.previous,
                                tooltip: 'Previous',
                                iconSize: 30,
                                icon: const Icon(Icons.skip_previous_rounded),
                              ),
                              const SizedBox(width: MuseSpacing.md),
                              IconButton(
                                onPressed: notifier.togglePlay,
                                tooltip: playing ? 'Pause' : 'Play',
                                iconSize: 44,
                                icon: Icon(
                                  playing
                                      ? Icons.pause_circle_filled_rounded
                                      : Icons.play_circle_filled_rounded,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                              const SizedBox(width: MuseSpacing.md),
                              IconButton(
                                onPressed: notifier.next,
                                tooltip: 'Next',
                                iconSize: 30,
                                icon: const Icon(Icons.skip_next_rounded),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _EmptyLibraryCard extends ConsumerWidget {
  const _EmptyLibraryCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(MuseSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Your library is empty',
                style: theme.textTheme.titleMedium),
            const SizedBox(height: MuseSpacing.xs),
            Text(
              'Add a music folder in Settings and Muse will scan it.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: MuseSpacing.md),
            GoldButton(
              label: 'Open Settings',
              icon: Icons.settings_rounded,
              onPressed: () => context.go(MusePaths.settings),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecentList extends StatelessWidget {
  const _RecentList({required this.albums});

  final List<Album> albums;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final recent = albums.take(6).toList();
    return SizedBox(
      height: 148,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: recent.length,
        separatorBuilder: (_, _) => const SizedBox(width: MuseSpacing.lg),
        itemBuilder: (context, i) {
          final album = recent[i];
          return InkWell(
            onTap: () => context.push(MusePaths.albumFor(album.id)),
            child: SizedBox(
              width: 88,
              child: Column(
                children: [
                  AlbumArt(albumId: album.id, size: 88),
                  const SizedBox(height: MuseSpacing.sm),
                  Text(album.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _AlbumList extends StatelessWidget {
  const _AlbumList({required this.albums});

  final List<Album> albums;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      height: 168,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: albums.length,
        separatorBuilder: (_, _) => const SizedBox(width: MuseSpacing.lg),
        itemBuilder: (context, i) {
          final album = albums[i];
          return InkWell(
            onTap: () => context.push(MusePaths.albumFor(album.id)),
            child: Column(
              children: [
                AlbumArt(albumId: album.id, size: 112),
                const SizedBox(height: MuseSpacing.sm),
                SizedBox(
                  width: 112,
                  child: Text(album.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}