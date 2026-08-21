import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/muse_colors.dart';
import '../../core/theme/muse_spacing.dart';
import '../../core/widgets/medallion_art.dart';
import '../../core/widgets/muse_hero_frame.dart';
import '../../shared/models/track.dart';
import '../library/album_art.dart';
import '../playback/playback_controller.dart';
import '../playlist/add_to_playlist_sheet.dart';
import 'quality_sheet.dart';
import 'queue_section.dart';

/// Now playing — the main hero/anchor screen. Pediment and columns allowed
/// here. The player fills the screen; scrolling up reveals the Up Next queue.
/// In landscape the player and queue sit side by side.
class NowPlayingScreen extends ConsumerStatefulWidget {
  const NowPlayingScreen({super.key, this.trackId});

  /// Id of the track to show. The shared controller is the source of truth
  /// once a track is playing.
  final String? trackId;

  @override
  ConsumerState<NowPlayingScreen> createState() => _NowPlayingScreenState();
}

class _NowPlayingScreenState extends ConsumerState<NowPlayingScreen> {
  /// Returns to the previous screen (the shell tab the player was opened
  /// from). Falls back to Home if there is nothing to pop.
  void _goBack() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(MusePaths.home);
    }
  }

  /// Portrait-only queue sheet: reorderable Up Next list with per-row remove.
  Future<void> _openQueueSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (_) => const QueueSheet(),
    );
  }

  /// Options menu for the current track.
  Future<void> _openMenuSheet(Track track) async {
    final screenContext = context;
    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => _PlayerMenuSheet(
        track: track,
        onGoToAlbum: () {
          Navigator.of(sheetContext).pop();
          if (screenContext.mounted) {
            screenContext.push(MusePaths.albumFor(track.albumId));
          }
        },
        onGoToArtist: () {
          Navigator.of(sheetContext).pop();
          if (screenContext.mounted) {
            screenContext.push(MusePaths.artistFor(track.artist));
          }
        },
        onAddToPlaylist: () {
          Navigator.of(sheetContext).pop();
          if (screenContext.mounted) {
            showAddToPlaylistSheet(screenContext, track);
          }
        },
        onShowQuality: () {
          Navigator.of(sheetContext).pop();
          if (screenContext.mounted) {
            showQualitySheet(screenContext);
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Select the slowly-changing slices so position ticks don't rebuild the
    // whole hero; _Progress subscribes to position/duration itself.
    final summary = ref.watch(playbackControllerProvider.select(
      (s) => (
        track: s.current,
        playing: s.playing,
        shuffle: s.shuffle,
        repeat: s.repeat,
      ),
    ));
    final track = summary.track;
    final notifier = ref.read(playbackControllerProvider.notifier);

    if (track == null) {
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const MedallionArt(size: 96),
                const SizedBox(height: MuseSpacing.lg),
                Text('Nothing playing',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: MuseSpacing.sm),
                Text('Pick a song from your library',
                    style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: OrientationBuilder(
        builder: (context, orientation) {
          final isLandscape = orientation == Orientation.landscape;

          final player = _PlayerPane(
            track: track,
            portrait: !isLandscape,
            playing: summary.playing,
            shuffle: summary.shuffle,
            repeat: summary.repeat,
            onTogglePlay: notifier.togglePlay,
            onToggleShuffle: notifier.toggleShuffle,
            onToggleRepeat: notifier.toggleRepeat,
            onPrevious: notifier.previous,
            onNext: notifier.next,
            showQueue: !isLandscape,
            onMenu: () => _openMenuSheet(track),
            onQueue: _openQueueSheet,
          );

          final Widget content = isLandscape
              ? LayoutBuilder(
                  builder: (context, constraints) {
                    final paneWidth = constraints.maxWidth / 2;
                    final pedimentWidth =
                        (paneWidth - 2 * (18 + MuseSpacing.md))
                            .clamp(120.0, double.infinity);
                    return Row(
                      children: [
                        Expanded(
                          child: MuseHeroFrame(
                            pedimentWidth: pedimentWidth,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: MuseSpacing.xl,
                              ),
                              child: player,
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: MuseSpacing.xl,
                          ),
                          child: const VerticalDivider(
                            width: 1,
                            color: MuseColors.goldHairline,
                          ),
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: MuseSpacing.xl,
                            ),
                            child: UpNextList(ownScroll: true),
                          ),
                        ),
                      ],
                    );
                  },
                )
              : MuseHeroFrame(
                  columnsTopInset: MuseSpacing.xl + 20 + 25,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: MuseSpacing.xl,
                    ),
                    child: player,
                  ),
                );

          return Stack(
            children: [
              Positioned.fill(
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.only(
                      top: _PlayerTopBar.height + 8,
                    ),
                    child: content,
                  ),
                ),
              ),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  bottom: false,
                  child: _PlayerTopBar(onBack: _goBack),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Minimal back affordance for the player. No hairline, no extra buttons.
class _PlayerTopBar extends StatelessWidget {
  const _PlayerTopBar({required this.onBack});

  static const double height = 48;

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Align(
        alignment: Alignment.centerLeft,
        child: Padding(
          padding: const EdgeInsets.only(left: MuseSpacing.sm),
          child: IconButton(
            onPressed: onBack,
            tooltip: 'Back',
            icon: const Icon(
              Icons.chevron_left_rounded,
              color: MuseColors.gold,
            ),
          ),
        ),
      ),
    );
  }
}

/// The player UI: medallion, title, artist, transport, progress.
///
/// Portrait: a large, top-anchored album circle (twice the previous size)
/// with a small gap under the pediment; the title/artist/controls/timeline
/// form a fixed block below. Landscape: a smaller centered circle.
class _PlayerPane extends StatelessWidget {
  const _PlayerPane({
    required this.track,
    required this.portrait,
    required this.playing,
    required this.shuffle,
    required this.repeat,
    required this.onTogglePlay,
    required this.onToggleShuffle,
    required this.onToggleRepeat,
    required this.onPrevious,
    required this.onNext,
    required this.showQueue,
    required this.onMenu,
    required this.onQueue,
  });

  final Track track;
  final bool portrait;
  final bool playing;
  final bool shuffle;
  final bool repeat;
  final VoidCallback onTogglePlay;
  final VoidCallback onToggleShuffle;
  final VoidCallback onToggleRepeat;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final bool showQueue;
  final VoidCallback onMenu;
  final VoidCallback onQueue;

  Widget _infoBlock(ThemeData theme) {
    return Column(
      children: [
        Text(
          track.title,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.headlineSmall,
        ),
        const SizedBox(height: MuseSpacing.sm),
        Text(
          track.artist,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: MuseSpacing.xl),
        _Transport(
          playing: playing,
          shuffle: shuffle,
          repeat: repeat,
          onTogglePlay: onTogglePlay,
          onToggleShuffle: onToggleShuffle,
          onToggleRepeat: onToggleRepeat,
          onPrevious: onPrevious,
          onNext: onNext,
          showQueue: showQueue,
          onMenu: onMenu,
          onQueue: onQueue,
        ),
        const SizedBox(height: MuseSpacing.sm),
        const _Progress(),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (!portrait) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final medallionSize = math
              .min(constraints.maxWidth * 0.42, constraints.maxHeight * 0.5)
              .clamp(96.0, 200.0);
          return Column(
            children: [
              const Spacer(),
              AlbumArt(albumId: track.albumId, size: medallionSize),
              const SizedBox(height: MuseSpacing.xxl),
              _infoBlock(theme),
              const Spacer(),
            ],
          );
        },
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;
        const reserved = 232.0; // info block + circle-to-title gap estimate
        final medallionSize = math
            .min(width, (height - reserved).clamp(0.0, double.infinity))
            .clamp(96.0, 420.0);
        return FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: width,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AlbumArt(albumId: track.albumId, size: medallionSize),
                const SizedBox(height: MuseSpacing.lg),
                _infoBlock(theme),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Seekable timeline. Watches the controller's position/duration directly so
/// only this widget rebuilds on every tick; dragging seeks the shared player.
class _Progress extends ConsumerWidget {
  const _Progress();

  String _fmt(Duration d) {
    final m = d.inMinutes;
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final position = ref.watch(
      playbackControllerProvider.select((s) => s.position),
    );
    final duration = ref.watch(
      playbackControllerProvider.select((s) => s.duration),
    );
    final notifier = ref.read(playbackControllerProvider.notifier);
    final value = duration.inMilliseconds == 0
        ? 0.0
        : position.inMilliseconds / duration.inMilliseconds;
    return Column(
      children: [
        Slider(
          value: value.clamp(0.0, 1.0),
          onChanged: (v) => notifier.seek(duration * v),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: MuseSpacing.sm),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_fmt(position), style: theme.textTheme.labelSmall),
              Text(_fmt(duration), style: theme.textTheme.labelSmall),
            ],
          ),
        ),
      ],
    );
  }
}

class _Transport extends StatelessWidget {
  const _Transport({
    required this.playing,
    required this.shuffle,
    required this.repeat,
    required this.onTogglePlay,
    required this.onToggleShuffle,
    required this.onToggleRepeat,
    required this.onPrevious,
    required this.onNext,
    required this.showQueue,
    required this.onMenu,
    required this.onQueue,
  });

  final bool playing;
  final bool shuffle;
  final bool repeat;
  final VoidCallback onTogglePlay;
  final VoidCallback onToggleShuffle;
  final VoidCallback onToggleRepeat;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  /// When false (landscape) the queue icon is hidden — the queue is already
  /// visible beside the player.
  final bool showQueue;
  final VoidCallback onMenu;
  final VoidCallback onQueue;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final activeColor = MuseColors.gold;
    final idleColor = theme.colorScheme.onSurfaceVariant;
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            onPressed: onMenu,
            tooltip: 'Menu',
            icon: const Icon(Icons.menu_rounded),
            color: idleColor,
          ),
          const SizedBox(width: MuseSpacing.lg),
          IconButton(
            onPressed: onToggleShuffle,
            tooltip: 'Shuffle',
            icon: const Icon(Icons.shuffle_rounded),
            color: shuffle ? activeColor : idleColor,
          ),
          const SizedBox(width: MuseSpacing.lg),
          IconButton(
            onPressed: onPrevious,
            tooltip: 'Previous',
            iconSize: 30,
            icon: const Icon(Icons.skip_previous_rounded),
          ),
          const SizedBox(width: MuseSpacing.lg),
          IconButton(
            onPressed: onTogglePlay,
            tooltip: playing ? 'Pause' : 'Play',
            iconSize: 44,
            icon: Icon(
              playing
                  ? Icons.pause_circle_filled_rounded
                  : Icons.play_circle_filled_rounded,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(width: MuseSpacing.lg),
          IconButton(
            onPressed: onNext,
            tooltip: 'Next',
            iconSize: 30,
            icon: const Icon(Icons.skip_next_rounded),
          ),
          const SizedBox(width: MuseSpacing.lg),
          IconButton(
            onPressed: onToggleRepeat,
            tooltip: 'Repeat',
            icon: const Icon(Icons.repeat_rounded),
            color: repeat ? activeColor : idleColor,
          ),
          if (showQueue) ...[
            const SizedBox(width: MuseSpacing.lg),
            IconButton(
              onPressed: onQueue,
              tooltip: 'Queue',
              icon: const Icon(Icons.queue_music_rounded),
              color: idleColor,
            ),
          ],
        ],
      ),
    );
  }
}

/// Bottom sheet from the player's hamburger: quick navigation to the current
/// track's album/artist, add-to-playlist, plus shuffle/repeat toggles.
class _PlayerMenuSheet extends ConsumerWidget {
  const _PlayerMenuSheet({
    required this.track,
    required this.onGoToAlbum,
    required this.onGoToArtist,
    required this.onAddToPlaylist,
    required this.onShowQuality,
  });

  final Track track;
  final VoidCallback onGoToAlbum;
  final VoidCallback onGoToArtist;
  final VoidCallback onAddToPlaylist;
  final VoidCallback onShowQuality;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final shuffle =
        ref.watch(playbackControllerProvider.select((s) => s.shuffle));
    final repeat =
        ref.watch(playbackControllerProvider.select((s) => s.repeat));
    final notifier = ref.read(playbackControllerProvider.notifier);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: MuseSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: MuseSpacing.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Now playing', style: theme.textTheme.titleMedium),
                  const SizedBox(height: MuseSpacing.xs),
                  Text(
                    track.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: MuseSpacing.md),
            const Divider(height: 1),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: MuseSpacing.xl,
              ),
              leading: const Icon(Icons.album_rounded),
              title: Text('Go to Album', style: theme.textTheme.titleSmall),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: onGoToAlbum,
            ),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: MuseSpacing.xl,
              ),
              leading: const Icon(Icons.person_rounded),
              title: Text('Go to Artist', style: theme.textTheme.titleSmall),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: onGoToArtist,
            ),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: MuseSpacing.xl,
              ),
              leading: const Icon(Icons.playlist_add_rounded),
              title: Text('Add to playlist',
                  style: theme.textTheme.titleSmall),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: onAddToPlaylist,
            ),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: MuseSpacing.xl,
              ),
              leading: const Icon(Icons.tune_rounded),
              title: Text('Playback quality',
                  style: theme.textTheme.titleSmall),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: onShowQuality,
            ),
            const Divider(height: 1),
            SwitchListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: MuseSpacing.xl,
              ),
              secondary: const Icon(Icons.shuffle_rounded),
              title: Text('Shuffle', style: theme.textTheme.titleSmall),
              value: shuffle,
              onChanged: (_) => notifier.toggleShuffle(),
            ),
            SwitchListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: MuseSpacing.xl,
              ),
              secondary: const Icon(Icons.repeat_rounded),
              title: Text('Repeat', style: theme.textTheme.titleSmall),
              value: repeat,
              onChanged: (_) => notifier.toggleRepeat(),
            ),
          ],
        ),
      ),
    );
  }
}