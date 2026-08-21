import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/muse_spacing.dart';
import '../../core/widgets/medallion_art.dart';
import '../../core/widgets/playing_indicator.dart';
import '../../core/widgets/section_heading.dart';
import '../../shared/models/album.dart';
import '../../shared/models/track.dart';
import '../library/album_art.dart';
import '../library/library_provider.dart';
import '../playback/playback_controller.dart';

/// Search — filters the scanned library by song, album, and artist.
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final TextEditingController _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tracks = ref.watch(libraryProvider).value ?? const [];
    final albums = ref.watch(libraryAlbumsProvider);
    final artists = ref.watch(libraryArtistsProvider);

    final q = _query.trim().toLowerCase();
    final songs = q.isEmpty
        ? const <Track>[]
        : tracks.where((t) {
            return t.title.toLowerCase().contains(q) ||
                t.artist.toLowerCase().contains(q);
          }).toList();
    final albumResults = q.isEmpty
        ? const <Album>[]
        : albums.where((a) {
            return a.title.toLowerCase().contains(q) ||
                a.artist.toLowerCase().contains(q);
          }).toList();
    final artistResults = q.isEmpty
        ? const <String>[]
        : artists.where((a) => a.toLowerCase().contains(q)).toList();

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: MuseSpacing.page,
        vertical: MuseSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeading(title: 'Search'),
          const SizedBox(height: MuseSpacing.lg),
          TextField(
            controller: _controller,
            onChanged: (value) => setState(() => _query = value),
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search_rounded),
              hintText: 'Songs, artists, albums',
            ),
          ),
          const SizedBox(height: MuseSpacing.md),
          Expanded(
            child: _body(theme, songs, albumResults, artistResults, q),
          ),
        ],
      ),
    );
  }

  Widget _body(
    ThemeData theme,
    List<Track> songs,
    List<Album> albumResults,
    List<String> artistResults,
    String q,
  ) {
    final currentId =
        ref.watch(playbackControllerProvider.select((s) => s.current?.id));
    final playing =
        ref.watch(playbackControllerProvider.select((s) => s.playing));
    if (q.isEmpty) {
      return Center(
        child: Text(
          'Search across your local library.',
          style: theme.textTheme.bodySmall,
        ),
      );
    }
    if (songs.isEmpty && albumResults.isEmpty && artistResults.isEmpty) {
      return Center(
        child: Text('No results for "$q".', style: theme.textTheme.bodySmall),
      );
    }

    return ListView(
      children: [
        if (songs.isNotEmpty) ...[
          Text('Songs', style: theme.textTheme.titleMedium),
          const SizedBox(height: MuseSpacing.sm),
          for (final track in songs)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: AlbumArt(albumId: track.albumId, size: 40),
              title: Text(
                track.title,
                style: track.id == currentId
                    ? theme.textTheme.titleSmall?.copyWith(
                        color: theme.colorScheme.primary,
                      )
                    : theme.textTheme.titleSmall,
              ),
              subtitle: Text(track.artist, style: theme.textTheme.bodySmall),
              trailing: track.id == currentId
                  ? PlayingIndicator(playing: playing)
                  : null,
              onTap: () => openPlayer(context, track),
            ),
          const SizedBox(height: MuseSpacing.xl),
        ],
        if (albumResults.isNotEmpty) ...[
          Text('Albums', style: theme.textTheme.titleMedium),
          const SizedBox(height: MuseSpacing.sm),
          for (final album in albumResults)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: AlbumArt(albumId: album.id, size: 40),
              title: Text(album.title, style: theme.textTheme.titleSmall),
              subtitle: Text(album.artist, style: theme.textTheme.bodySmall),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => context.push(MusePaths.albumFor(album.id)),
            ),
          const SizedBox(height: MuseSpacing.xl),
        ],
        if (artistResults.isNotEmpty) ...[
          Text('Artists', style: theme.textTheme.titleMedium),
          const SizedBox(height: MuseSpacing.sm),
          for (final artist in artistResults)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: MedallionArt(size: 40),
              title: Text(artist, style: theme.textTheme.titleSmall),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => context.push(MusePaths.artistFor(artist)),
            ),
        ],
      ],
    );
  }
}