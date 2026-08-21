import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/muse_colors.dart';
import '../../core/theme/muse_spacing.dart';
import '../../shared/models/friend.dart';
import '../pairing/friends_provider.dart';
import '../playback/playback_controller.dart';
import '../stream/cache_provider.dart';

/// Opens the quality inspector — what the user is actually hearing: the
/// decoder's audio format/sample rate/channels plus the playback source.
void showQualitySheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    builder: (_) => const QualitySheet(),
  );
}

class QualitySheet extends ConsumerWidget {
  const QualitySheet({super.key});

  String _fmt(Duration d) {
    final m = d.inMinutes;
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final current =
        ref.watch(playbackControllerProvider.select((s) => s.current));
    final params =
        ref.watch(playbackControllerProvider.select((s) => s.audioParams));
    final duration =
        ref.watch(playbackControllerProvider.select((s) => s.duration));
    final cacheProgress =
        ref.watch(playbackControllerProvider.select((s) => s.cacheProgress));
    final friends = ref.watch(friendsProvider).value ?? const <Friend>[];

    final isCached =
        current == null ? false : (ref.watch(cacheStateProvider(current.id)).value ?? false);

    String? sourceLabel;
    if (current != null) {
      if (current.isRemote) {
        if (isCached) {
          sourceLabel = 'From cache';
        } else {
          Friend? friend;
          for (final f in friends) {
            if (f.onion == current.remoteOwner) {
              friend = f;
              break;
            }
          }
          sourceLabel =
              'Streaming from ${friendDisplayName(friend, current.remoteOwner)}';
        }
      } else {
        sourceLabel = 'Local file';
      }
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: MuseSpacing.md,
          horizontal: MuseSpacing.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Playback quality', style: theme.textTheme.titleMedium),
            if (current != null) ...[
              const SizedBox(height: MuseSpacing.xs),
              Text(
                current.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: MuseSpacing.md),
            const Divider(height: 1),
            _row(theme, 'Format', params?.format ?? '—'),
            _row(theme, 'Sample rate',
                params?.sampleRate != null ? '${params!.sampleRate} Hz' : '—'),
            _row(
              theme,
              'Channels',
              params?.channelCount != null
                  ? '${params!.channelCount}'
                  : (params?.channels?.isNotEmpty == true
                      ? params!.channels!
                      : '—'),
            ),
            _row(theme, 'Source', sourceLabel ?? '—'),
            if (current != null &&
                current.isRemote &&
                !isCached &&
                cacheProgress != null &&
                cacheProgress < 1)
              _row(theme, 'Cache', '${(cacheProgress * 100).round()}%'),
            _row(theme, 'Duration', current == null ? '—' : _fmt(duration)),
          ],
        ),
      ),
    );
  }

  Widget _row(ThemeData theme, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: MuseSpacing.sm),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: theme.textTheme.bodySmall),
          Text(
            value,
            style: theme.textTheme.titleSmall?.copyWith(
              color: MuseColors.gold,
            ),
          ),
        ],
      ),
    );
  }
}