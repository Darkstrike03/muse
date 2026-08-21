import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/muse_colors.dart';
import '../../core/theme/muse_spacing.dart';
import '../../core/widgets/gold_button.dart';
import '../../core/widgets/playing_indicator.dart';
import '../../shared/models/friend.dart';
import '../../shared/models/playlist.dart';
import '../../shared/models/track.dart';
import '../../shared/navigation/mini_player_bar.dart';
import '../library/album_art.dart';
import '../library/library_provider.dart';
import '../pairing/friends_provider.dart';
import '../playback/playback_controller.dart';
import '../stream/cache_provider.dart';
import 'playlist_art.dart';
import 'playlist_dialogs.dart';
import 'playlists_provider.dart';

/// Playlist detail — name, art, and the songs it contains. Songs play in
/// playlist order (shuffle/repeat available in the player); tapping a row
/// starts from that song. Image, rename, add and remove are all available.
class PlaylistDetailScreen extends ConsumerWidget {
  const PlaylistDetailScreen({super.key, required this.playlistId});

  final String playlistId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final playlists = ref.watch(playlistsProvider).value ?? const [];
    final playlist = _firstWhereOrNull(playlists, (p) => p.id == playlistId);

    if (playlist == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Playlist')),
        bottomNavigationBar: const MiniPlayerBar(),
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(MuseSpacing.xl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Playlist not found.',
                      style: theme.textTheme.bodySmall),
                  const SizedBox(height: MuseSpacing.lg),
                  OutlinedButton(
                    onPressed: () {
                      if (context.canPop()) {
                        Navigator.of(context).pop();
                      } else {
                        context.go(MusePaths.home);
                      }
                    },
                    child: const Text('Go back'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final found = playlist;
    final isImported = found.ownerOnion != null;
    final friends = ref.watch(friendsProvider).value ?? const <Friend>[];
    String sharedByName = '';
    if (isImported) {
      for (final f in friends) {
        if (f.onion == found.ownerOnion) {
          sharedByName = f.name;
          break;
        }
      }
      if (sharedByName.isEmpty) {
        sharedByName = friendDisplayName(null, found.ownerOnion);
      }
    }
    final tracksAsync = ref.watch(playlistTracksProvider(playlistId));
    final tracks = tracksAsync.value ?? const <Track>[];
    final notifier = ref.read(playlistsProvider.notifier);
    final isPlayingSource = ref.watch(
      playbackControllerProvider.select((s) => s.sourceId == found.id),
    );
    final currentId =
        ref.watch(playbackControllerProvider.select((s) => s.current?.id));
    final playing =
        ref.watch(playbackControllerProvider.select((s) => s.playing));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Playlist'),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Playlist options',
            onSelected: (value) {
              switch (value) {
                case 'rename':
                  _rename(context, ref, found);
                case 'image':
                  _changeImage(context, ref, found);
                case 'downloadAll':
                  _downloadAll(context, ref, tracks);
                case 'delete':
                  _delete(context, ref, found);
              }
            },
            itemBuilder: (context) => [
              if (!isImported)
                const PopupMenuItem(
                  value: 'rename',
                  child: Text('Rename'),
                ),
              if (!isImported)
                const PopupMenuItem(
                  value: 'image',
                  child: Text('Change image'),
                ),
              const PopupMenuItem(
                value: 'downloadAll',
                child: Text('Download all'),
              ),
              if (!isImported)
                const PopupMenuItem(
                  value: 'delete',
                  child: Text('Delete playlist'),
                ),
            ],
          ),
        ],
      ),
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
                    InkWell(
                      onTap: isImported
                          ? null
                          : () => _changeImage(context, ref, found),
                      borderRadius: BorderRadius.circular(medallionSize),
                      child: PlaylistArt(
                        imagePath: found.imagePath,
                        size: medallionSize,
                      ),
                    ),
                    const SizedBox(width: MuseSpacing.xl),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(found.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.headlineLarge),
                          const SizedBox(height: MuseSpacing.xs),
                          Text(
                            tracks.length == 1
                                ? '1 song'
                                : '${tracks.length} songs',
                            style: theme.textTheme.bodySmall,
                          ),
                          if (isPlayingSource) ...[
                            const SizedBox(height: MuseSpacing.xs),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                PlayingIndicator(playing: playing, size: 14),
                                const SizedBox(width: MuseSpacing.xs),
                                Text('Playing',
                                    style: theme.textTheme.labelSmall),
                              ],
                            ),
                          ],
                          if (isImported) ...[
                            const SizedBox(height: MuseSpacing.xs),
                            Text('Shared by $sharedByName',
                                style: theme.textTheme.bodySmall),
                          ] else ...[
                            const SizedBox(height: MuseSpacing.sm),
                            TextButton.icon(
                              onPressed: () => _rename(context, ref, found),
                              icon: const Icon(Icons.edit_rounded, size: 18),
                              label: const Text('Rename'),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: MuseSpacing.xl),
            GoldButton(
              label: 'Play',
              icon: Icons.play_arrow_rounded,
              expand: true,
              onPressed: tracks.isEmpty
                  ? null
                  : () => openTracks(context, tracks, tracks.first,
                      sourceId: found.id),
            ),
            const SizedBox(height: MuseSpacing.md),
            if (!isImported)
              OutlinedButton.icon(
                onPressed: () => _showAddTracks(context, ref, found, tracks),
                icon: const Icon(Icons.library_music_rounded, size: 18),
                label: const Text('Add songs'),
              ),
            const SizedBox(height: MuseSpacing.lg),
            const Divider(height: 1),
            const SizedBox(height: MuseSpacing.sm),
            if (tracksAsync.hasError && tracks.isEmpty)
              Padding(
                padding: const EdgeInsets.all(MuseSpacing.xl),
                child: Center(
                  child: Text(
                    'Could not load these songs right now.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              )
            else if (tracks.isEmpty)
              Padding(
                padding: const EdgeInsets.all(MuseSpacing.xl),
                child: Center(
                  child: Text(
                    'No songs yet. Add some from your library.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              )
            else
              for (final track in tracks)
                _PlaylistRow(
                  track: track,
                  isCurrent: track.id == currentId,
                  playing: playing,
                  onTap: () => openTracks(
                    context,
                    tracks,
                    track,
                    sourceId: found.id,
                  ),
                  onRemove: isImported
                      ? null
                      : () => notifier.removeTrack(found.id, track),
                ),
          ],
        ),
      ),
    );
  }

  Future<void> _rename(
    BuildContext context,
    WidgetRef ref,
    Playlist playlist,
  ) async {
    final name = await showPlaylistNameDialog(
      context,
      title: 'Rename playlist',
      initial: playlist.name,
    );
    if (name == null) return;
    await ref.read(playlistsProvider.notifier).rename(playlist.id, name);
  }

  Future<void> _changeImage(
    BuildContext context,
    WidgetRef ref,
    Playlist playlist,
  ) async {
    final path = await ref.read(pickPlaylistImageProvider)();
    if (path == null) return;
    await ref.read(playlistsProvider.notifier).setImage(playlist.id, path);
  }

  Future<void> _downloadAll(
    BuildContext context,
    WidgetRef ref,
    List<Track> tracks,
  ) async {
    for (final track in tracks.where((t) => t.isRemote)) {
      await downloadRemoteTrack(ref, track);
    }
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    Playlist playlist,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete "${playlist.name}"?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(playlistsProvider.notifier).delete(playlist.id);
    if (context.mounted) Navigator.of(context).pop();
  }

  Future<void> _showAddTracks(
    BuildContext context,
    WidgetRef ref,
    Playlist playlist,
    List<Track> current,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => AddTracksSheet(
        playlistId: playlist.id,
        existingIds: {for (final t in current) t.id},
      ),
    );
  }
}

class _PlaylistRow extends ConsumerWidget {
  const _PlaylistRow({
    required this.track,
    required this.isCurrent,
    required this.playing,
    required this.onTap,
    required this.onRemove,
  });

  final Track track;
  final bool isCurrent;
  final bool playing;
  final VoidCallback onTap;
  final VoidCallback? onRemove;

  String _unavailableLabel(Friend? friend) {
    if (!track.isRemote) return 'File missing';
    return 'Unavailable — ${friendDisplayName(friend, track.remoteOwner)} '
        'is offline';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final available =
        ref.watch(trackAvailabilityProvider(track.id)).value ?? true;
    final friends = ref.watch(friendsProvider).value ?? const <Friend>[];

    Friend? friend;
    if (track.isRemote) {
      for (final f in friends) {
        if (f.onion == track.remoteOwner) {
          friend = f;
          break;
        }
      }
    }

    final dimmed = !available;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      enabled: available,
      leading: Opacity(
        opacity: dimmed ? 0.4 : 1,
        child: AlbumArt(albumId: track.albumId, size: 40),
      ),
      title: Text(
        track.title,
        style: isCurrent
            ? theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.primary,
              )
            : theme.textTheme.titleSmall?.copyWith(
                color: dimmed ? theme.colorScheme.onSurfaceVariant : null,
              ),
      ),
      subtitle: Text(
        dimmed ? _unavailableLabel(friend) : track.artist,
        style: theme.textTheme.bodySmall,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (track.isRemote) ...[
            _RemoteDownloadButton(track: track),
            const SizedBox(width: MuseSpacing.xs),
          ],
          if (isCurrent && playing) ...[
            PlayingIndicator(playing: playing),
            const SizedBox(width: MuseSpacing.sm),
          ],
          if (onRemove != null)
            IconButton(
              tooltip: 'Remove from playlist',
              icon: const Icon(Icons.remove_circle_outline_rounded),
              onPressed: onRemove,
            ),
        ],
      ),
      onTap: available ? onTap : null,
    );
  }
}

/// Download / remove-download / in-progress indicator for a remote track's
/// cached bytes.
class _RemoteDownloadButton extends ConsumerWidget {
  const _RemoteDownloadButton({required this.track});

  final Track track;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cached = ref.watch(cacheStateProvider(track.id)).value ?? false;
    final progress = ref.watch(cacheProgressProvider(track.id)).value;

    if (cached) {
      return IconButton(
        tooltip: 'Remove download',
        visualDensity: VisualDensity.compact,
        icon: const Icon(Icons.download_done_rounded, size: 20),
        color: MuseColors.gold,
        onPressed: () => removeCachedTrack(ref, track.id),
      );
    }
    if (progress != null && progress > 0 && progress < 1) {
      return Padding(
        padding: const EdgeInsets.all(8),
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            value: progress,
            color: MuseColors.gold,
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
          ),
        ),
      );
    }
    return IconButton(
      tooltip: 'Download',
      visualDensity: VisualDensity.compact,
      icon: const Icon(Icons.download_rounded, size: 20),
      onPressed: () => downloadRemoteTrack(ref, track),
    );
  }
}

/// Bottom sheet listing library tracks not already in the playlist, with a
/// checkbox per row and an Add button for the selected ones.
class AddTracksSheet extends ConsumerStatefulWidget {
  const AddTracksSheet({
    super.key,
    required this.playlistId,
    required this.existingIds,
  });

  final String playlistId;
  final Set<String> existingIds;

  @override
  ConsumerState<AddTracksSheet> createState() => _AddTracksSheetState();
}

class _AddTracksSheetState extends ConsumerState<AddTracksSheet> {
  final Map<String, Track> _selected = {};

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final library = ref.watch(libraryProvider);
    final tracks =
        (library.value ?? const <Track>[])
            .where((t) => !widget.existingIds.contains(t.id))
            .toList();

    return SafeArea(
      child: SizedBox(
        height: 480,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                MuseSpacing.xl,
                MuseSpacing.lg,
                MuseSpacing.xl,
                MuseSpacing.md,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text('Add songs',
                        style: theme.textTheme.titleMedium),
                  ),
                  if (_selected.isNotEmpty)
                    Text('${_selected.length} selected',
                        style: theme.textTheme.labelSmall),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: tracks.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(MuseSpacing.xl),
                        child: Text(
                          'Nothing to add — all library songs are already '
                          'in this playlist.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: tracks.length,
                      itemBuilder: (context, i) {
                        final track = tracks[i];
                        final checked = _selected.containsKey(track.id);
                        return CheckboxListTile(
                          value: checked,
                          onChanged: (value) {
                            setState(() {
                              if (value == true) {
                                _selected[track.id] = track;
                              } else {
                                _selected.remove(track.id);
                              }
                            });
                          },
                          secondary: AlbumArt(
                            albumId: track.albumId,
                            size: 40,
                          ),
                          title: Text(track.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleSmall),
                          subtitle: Text(track.artist,
                              style: theme.textTheme.bodySmall),
                        );
                      },
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(MuseSpacing.xl),
              child: GoldButton(
                label: _selected.isEmpty
                    ? 'Add selected'
                    : 'Add ${_selected.length}',
                icon: Icons.add_rounded,
                expand: true,
                onPressed: _selected.isEmpty
                    ? null
                    : () async {
                        await ref
                            .read(playlistsProvider.notifier)
                            .addTracks(
                              widget.playlistId,
                              _selected.values.toList(),
                            );
                        if (context.mounted) Navigator.of(context).pop();
                      },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Playlist? _firstWhereOrNull(
  List<Playlist> playlists,
  bool Function(Playlist) test,
) {
  for (final playlist in playlists) {
    if (test(playlist)) return playlist;
  }
  return null;
}