import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/muse_colors.dart';
import '../../core/theme/muse_spacing.dart';
import '../../core/widgets/playing_indicator.dart';
import '../../core/widgets/section_heading.dart';
import '../../shared/models/track.dart';
import '../library/album_art.dart';
import '../playback/playback_controller.dart';

/// "Up Next" queue list shared by the player's portrait scroll section and its
/// landscape side-by-side pane. Driven by the shared playback controller;
/// tapping a row plays that track.
class UpNextList extends ConsumerWidget {
  const UpNextList({super.key, this.ownScroll = false});

  /// When true the list fills its parent and scrolls itself (landscape pane).
  /// When false it shrink-wraps inside a parent scroller (portrait section).
  final bool ownScroll;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queue = ref.watch(playbackControllerProvider.select((s) => s.queue));
    final currentTrackId =
        ref.watch(playbackControllerProvider.select(
          (s) => s.current?.id,
        ));
    final playing =
        ref.watch(playbackControllerProvider.select((s) => s.playing));

    final heading = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(
          height: 1,
          thickness: 1,
          color: MuseColors.goldHairline,
        ),
        const SizedBox(height: MuseSpacing.lg),
        const SectionHeading(title: 'Up Next'),
        const SizedBox(height: MuseSpacing.lg),
      ],
    );

    if (queue.isEmpty) {
      final empty = Padding(
        padding: const EdgeInsets.all(MuseSpacing.xl),
        child: Center(
          child: Text(
            'Nothing queued yet. Pick a song to start.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      );
      if (ownScroll) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [heading, Expanded(child: empty)],
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [heading, empty],
      );
    }

    final list = ListView.separated(
      shrinkWrap: !ownScroll,
      physics: ownScroll ? null : const NeverScrollableScrollPhysics(),
      itemCount: queue.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, i) => _QueueRow(
        track: queue[i],
        isCurrent: queue[i].id == currentTrackId,
        playing: playing,
      ),
    );

    if (ownScroll) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [heading, Expanded(child: list)],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [heading, list],
    );
  }
}

class _QueueRow extends StatelessWidget {
  const _QueueRow({
    required this.track,
    required this.isCurrent,
    required this.playing,
  });

  final Track track;
  final bool isCurrent;
  final bool playing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
      trailing: isCurrent ? PlayingIndicator(playing: playing) : null,
      onTap: () => openPlayer(context, track),
    );
  }
}

/// Bottom sheet (portrait player only) with the full play queue: drag rows to
/// reorder, tap a row's menu to remove it. Driven by the shared controller.
class QueueSheet extends ConsumerWidget {
  const QueueSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final queue = ref.watch(playbackControllerProvider.select((s) => s.queue));
    final currentId =
        ref.watch(playbackControllerProvider.select((s) => s.current?.id));
    final playing =
        ref.watch(playbackControllerProvider.select((s) => s.playing));
    final notifier = ref.read(playbackControllerProvider.notifier);

    return SafeArea(
      child: SizedBox(
        height: 480,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                MuseSpacing.xl,
                MuseSpacing.lg,
                MuseSpacing.xl,
                MuseSpacing.md,
              ),
              child: Text('Up Next', style: theme.textTheme.titleMedium),
            ),
            const Divider(height: 1),
            Expanded(
              child: queue.isEmpty
                  ? Center(
                      child: Text('Queue is empty.',
                          style: theme.textTheme.bodySmall),
                    )
                  : ReorderableListView.builder(
                      padding: EdgeInsets.zero,
                      itemCount: queue.length,
                      onReorder: notifier.moveQueueItem,
                      itemBuilder: (context, index) {
                        final track = queue[index];
                        return _QueueSheetRow(
                          key: ValueKey(track.id),
                          track: track,
                          isCurrent: track.id == currentId,
                          playing: playing,
                          onSelect: () {
                            Navigator.of(context).pop();
                            notifier.playQueueIndex(index);
                          },
                          onRemove: () => _confirmRemove(
                            context,
                            ref,
                            track,
                            index,
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmRemove(
    BuildContext context,
    WidgetRef ref,
    Track track,
    int index,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: MuseSpacing.xl,
              ),
              leading: const Icon(Icons.close_rounded),
              title: Text('Remove from queue',
                  style: Theme.of(sheetContext).textTheme.titleSmall),
              onTap: () {
                Navigator.of(sheetContext).pop();
                ref
                    .read(playbackControllerProvider.notifier)
                    .removeQueueItem(index);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _QueueSheetRow extends StatelessWidget {
  const _QueueSheetRow({
    super.key,
    required this.track,
    required this.isCurrent,
    required this.playing,
    required this.onSelect,
    required this.onRemove,
  });

  final Track track;
  final bool isCurrent;
  final bool playing;
  final VoidCallback onSelect;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: MuseSpacing.xl,
      ),
      leading: AlbumArt(albumId: track.albumId, size: 40),
      title: Text(
        track.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: isCurrent
            ? theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.primary,
              )
            : theme.textTheme.titleSmall,
      ),
      subtitle: Text(
        track.artist,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodySmall,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isCurrent) ...[
            PlayingIndicator(playing: playing),
            const SizedBox(width: MuseSpacing.sm),
          ],
          IconButton(
            tooltip: 'More',
            icon: const Icon(Icons.menu_rounded),
            onPressed: onRemove,
          ),
        ],
      ),
      onTap: onSelect,
    );
  }
}