import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/muse_colors.dart';
import '../../core/theme/muse_spacing.dart';
import '../../core/widgets/section_heading.dart';
import '../../shared/models/shared_scope.dart';
import '../library/library_provider.dart';
import '../pairing/friends_provider.dart';
import '../pairing/identity_provider.dart';
import '../pairing/pairing_sheet.dart';
import '../playlist/playlists_provider.dart';
import 'friends_reachability_provider.dart';
import 'friend_sync_provider.dart';
import 'share_server_provider.dart';
import 'sharing_provider.dart';
import 'tor_controller_provider.dart';

/// Stream — the sharer's control center: Tor status, this device's identity,
/// the opt-in "share all" switch, and per-playlist / per-album sharing toggles.
/// Watching this screen keeps the Tor daemon, share server and friend
/// reachability probe alive.
class StreamScreen extends ConsumerWidget {
  const StreamScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final sharing = ref.watch(sharingProvider).value;
    final notifier = ref.read(sharingProvider.notifier);
    final deviceId = ref.watch(deviceIdProvider).value ?? '…';
    final shortId = deviceId.length > 12 ? '${deviceId.substring(0, 12)}…' : deviceId;
    final deviceName = ref.watch(deviceNameProvider).value ?? 'My Muse';
    final playlists = ref.watch(playlistsProvider).value ?? const [];
    final albums = ref.watch(libraryAlbumsProvider);
    ref.watch(friendSyncProvider);

    return ListView(
      padding: const EdgeInsets.symmetric(
        horizontal: MuseSpacing.page,
        vertical: MuseSpacing.lg,
      ),
      children: [
        const SectionHeading(title: 'Stream'),
        const SizedBox(height: MuseSpacing.lg),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(MuseSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: MuseColors.cardSurface,
                      child: Text(
                        deviceName.isEmpty
                            ? 'M'
                            : deviceName[0].toUpperCase(),
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: MuseColors.gold,
                        ),
                      ),
                    ),
                    const SizedBox(width: MuseSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(deviceName,
                              style: theme.textTheme.titleSmall),
                          Text(
                            shortId,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: MuseSpacing.md),
                OutlinedButton.icon(
                  onPressed: () => showMyCodeSheet(context),
                  icon: const Icon(Icons.qr_code_2_rounded, size: 18),
                  label: const Text('Share my code'),
                ),
                const SizedBox(height: MuseSpacing.sm),
                Text(
                  'Friends can stream anything you share. Nothing is '
                  'shared until you turn it on.',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: MuseSpacing.lg),
        _TorStatusCard(),
        const SizedBox(height: MuseSpacing.xl),
        Card(
          child: SwitchListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: MuseSpacing.lg,
              vertical: MuseSpacing.sm,
            ),
            secondary: const Icon(Icons.wifi_tethering_rounded),
            title: Text('Share all my songs',
                style: theme.textTheme.titleMedium),
            subtitle: Text(
              'Every song in your library becomes streamable.',
              style: theme.textTheme.bodySmall,
            ),
            value: sharing?.shareAll ?? false,
            onChanged: notifier.setShareAll,
          ),
        ),
        const SizedBox(height: MuseSpacing.xxl),
        Text('Shared playlists', style: theme.textTheme.titleLarge),
        const SizedBox(height: MuseSpacing.md),
        if (playlists.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: MuseSpacing.sm),
            child: Text(
              'Create playlists to share them with your friends.',
              style: theme.textTheme.bodySmall,
            ),
          )
        else
          Card(
            child: Column(
              children: [
                for (var i = 0; i < playlists.length; i++) ...[
                  if (i > 0) const Divider(height: 1),
                  SwitchListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: MuseSpacing.lg,
                    ),
                    title: Text(playlists[i].name,
                        style: theme.textTheme.titleSmall),
                    value: isScopeShared(
                      sharing,
                      ShareScopeType.playlist,
                      playlists[i].id,
                    ),
                    onChanged: (_) => notifier.toggleScope(
                      SharedScope(
                        type: ShareScopeType.playlist,
                        id: playlists[i].id,
                        label: playlists[i].name,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        const SizedBox(height: MuseSpacing.xxl),
        Text('Shared albums', style: theme.textTheme.titleLarge),
        const SizedBox(height: MuseSpacing.md),
        if (albums.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: MuseSpacing.sm),
            child: Text(
              'Add a music folder to share its albums.',
              style: theme.textTheme.bodySmall,
            ),
          )
        else
          Card(
            child: Column(
              children: [
                for (var i = 0; i < albums.length; i++) ...[
                  if (i > 0) const Divider(height: 1),
                  SwitchListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: MuseSpacing.lg,
                    ),
                    title: Text(
                      albums[i].title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall,
                    ),
                    value: isScopeShared(
                      sharing,
                      ShareScopeType.album,
                      albums[i].id,
                    ),
                    onChanged: (_) => notifier.toggleScope(
                      SharedScope(
                        type: ShareScopeType.album,
                        id: albums[i].id,
                        label: albums[i].title,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

/// Tor daemon + share-server status. Watching this card keeps the daemon and
/// reachability probe alive while the Stream tab is open.
class _TorStatusCard extends ConsumerWidget {
  const _TorStatusCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final tor = ref.watch(torControllerProvider);
    final server = ref.watch(shareServerStateProvider);
    final online =
        ref.watch(friendsReachabilityProvider).value ?? const <String>{};
    final friends = ref.watch(friendsProvider).value ?? const [];
    final syncing = ref.watch(friendSyncProvider).isLoading;

    final notifier = ref.read(torControllerProvider.notifier);

    final String statusLabel;
    final Color statusColor;
    if (tor.isLoading) {
      statusLabel = 'Starting Tor…';
      statusColor = theme.colorScheme.onSurfaceVariant;
    } else if (tor.hasError) {
      statusLabel = 'Tor not running — ${_errorMessage(tor.error ?? 'unknown')}';
      statusColor = theme.colorScheme.error;
    } else if (tor.value != null) {
      final onion = tor.value!.onion;
      statusLabel = onion == null
          ? 'Tor online'
          : 'Tor online — ${onion.substring(0, 12)}…';
      statusColor = MuseColors.gold;
    } else {
      statusLabel = 'Tor offline';
      statusColor = theme.colorScheme.onSurfaceVariant;
    }

    final serverPort = server.value?.port;
    final shareLabel = serverPort == null
        ? 'Share server not running'
        : 'Share server on 127.0.0.1:$serverPort';
    final onlineLabel = online.isEmpty
        ? '${friends.length} friend${friends.length == 1 ? '' : 's'}'
        : '${online.length} of ${friends.length} friend${friends.length == 1 ? '' : 's'} online';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(MuseSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  tor.value != null
                      ? Icons.lock_rounded
                      : Icons.lock_outline_rounded,
                  color: tor.value != null ? MuseColors.gold : null,
                  size: 20,
                ),
                const SizedBox(width: MuseSpacing.sm),
                Expanded(
                  child: Text(
                    statusLabel,
                    style: theme.textTheme.titleSmall
                        ?.copyWith(color: statusColor),
                  ),
                ),
                Switch(
                  value: tor.value != null,
                  onChanged: (_) {
                    if (tor.value != null) {
                      notifier.stop();
                    } else {
                      notifier.start();
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: MuseSpacing.sm),
            Text(shareLabel, style: theme.textTheme.bodySmall),
            const SizedBox(height: MuseSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: Text(onlineLabel, style: theme.textTheme.bodySmall),
                ),
                IconButton(
                  tooltip: 'Refresh friends',
                  visualDensity: VisualDensity.compact,
                  icon: syncing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: MuseColors.gold,
                          ),
                        )
                      : const Icon(Icons.sync_rounded, size: 18),
                  onPressed: syncing
                      ? null
                      : () => ref.read(friendSyncProvider.notifier).refresh(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _errorMessage(Object error) {
    final message = error.toString();
    return message.length > 80 ? '${message.substring(0, 77)}…' : message;
  }
}