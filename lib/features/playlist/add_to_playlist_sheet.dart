import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/muse_colors.dart';
import '../../core/theme/muse_spacing.dart';
import '../../shared/models/playlist.dart';
import '../../shared/models/track.dart';
import 'playlist_art.dart';
import 'playlist_dialogs.dart';
import 'playlists_provider.dart';

/// Bottom sheet to add a single track to one of the user's playlists.
/// Pops with the name of the playlist the track was added to, or null.
Future<String?> showAddToPlaylistSheet(
  BuildContext context,
  Track track,
) async {
  final result = await showModalBottomSheet<String>(
    context: context,
    builder: (_) => AddToPlaylistSheet(track: track),
  );
  if (result != null && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Added to "$result"')),
    );
  }
  return result;
}

/// Lists the user's playlists; tapping one adds [track] and closes.
/// Playlists that already contain the track are marked and disabled.
class AddToPlaylistSheet extends ConsumerStatefulWidget {
  const AddToPlaylistSheet({super.key, required this.track});

  final Track track;

  @override
  ConsumerState<AddToPlaylistSheet> createState() => _AddToPlaylistSheetState();
}

class _AddToPlaylistSheetState extends ConsumerState<AddToPlaylistSheet> {
  String get _trackKey => widget.track.isRemote
      ? (widget.track.remoteTrackId ?? widget.track.id)
      : (widget.track.filePath ?? widget.track.id);

  Future<void> _addTo(Playlist playlist) async {
    await ref
        .read(playlistsProvider.notifier)
        .addTracks(playlist.id, [widget.track]);
    if (mounted) Navigator.of(context).pop(playlist.name);
  }

  Future<void> _createAndAdd() async {
    final name = await showPlaylistNameDialog(context);
    if (name == null) return;
    final playlist = await ref.read(playlistsProvider.notifier).create(name);
    if (playlist == null) return;
    await ref
        .read(playlistsProvider.notifier)
        .addTracks(playlist.id, [widget.track]);
    if (mounted) Navigator.of(context).pop(playlist.name);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final playlists = ref.watch(playlistsProvider).value ?? const [];

    return SafeArea(
      child: SizedBox(
        height: 420,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                MuseSpacing.xl,
                MuseSpacing.lg,
                MuseSpacing.xl,
                MuseSpacing.md,
              ),
              child: Text('Add to playlist',
                  style: theme.textTheme.titleMedium),
            ),
            const Divider(height: 1),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: MuseSpacing.xl,
              ),
              leading: const Icon(Icons.add_rounded),
              title: Text('New playlist',
                  style: theme.textTheme.titleSmall),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: _createAndAdd,
            ),
            const Divider(height: 1),
            Expanded(
              child: playlists.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(MuseSpacing.xl),
                        child: Text(
                          'No playlists yet — create one to save this song.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: playlists.length,
                      itemBuilder: (context, i) {
                        final playlist = playlists[i];
                        final contains = playlist.trackIds
                            .contains(_trackKey);
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: MuseSpacing.xl,
                          ),
                          leading: PlaylistArt(
                            imagePath: playlist.imagePath,
                            size: 40,
                          ),
                          title: Text(
                            playlist.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleSmall,
                          ),
                          trailing: contains
                              ? Icon(
                                  Icons.check_circle_rounded,
                                  color: MuseColors.gold,
                                )
                              : const Icon(Icons.add_rounded),
                          enabled: !contains,
                          onTap: () => _addTo(playlist),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}