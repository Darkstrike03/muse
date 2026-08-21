import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/storage/muse_db.dart';
import '../../shared/models/friend.dart';
import '../../shared/models/remote_track_meta.dart';
import '../../shared/models/shared_scope.dart';
import '../pairing/friends_provider.dart';
import '../playlist/playlists_provider.dart';
import 'friend_manifest.dart';
import 'friends_reachability_provider.dart';
import 'tor_controller_provider.dart';

/// Keeps every reachable friend's shared scopes imported as playlists.
///
/// Syncs automatically while watched (the Stream tab watches it), on
/// reachability changes, and on demand via [FriendSync.refresh]. Friends who
/// are offline keep their last-known playlists — availability greys them out.
final friendSyncProvider = AsyncNotifierProvider<FriendSync, int>(
  FriendSync.new,
);

class FriendSync extends AsyncNotifier<int> {
  Timer? _timer;
  Future<void>? _inFlight;

  @override
  Future<int> build() async {
    ref.onDispose(() => _timer?.cancel());
    _timer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => unawaited(_syncAll()),
    );
    ref.listen(reachableFriendsProvider, (_, _) => unawaited(_syncAll()));
    ref.listen(torControllerProvider, (_, _) => unawaited(_syncAll()));
    return _syncAll();
  }

  /// Explicit refresh, e.g. from the Stream tab button. Shows loading state.
  Future<void> refresh() async {
    if (_inFlight != null) return;
    state = const AsyncLoading();
    try {
      state = AsyncData(await _syncAll());
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  Future<int> _syncAll() async {
    final pending = _inFlight;
    if (pending != null) {
      await pending;
      return state.value ?? 0;
    }
    final future = _run();
    _inFlight = future;
    try {
      return await future;
    } finally {
      _inFlight = null;
    }
  }

  Future<int> _run() async {
    final tor = await ref.read(torControllerProvider.future);
    final reachable = ref.read(reachableFriendsProvider);
    final friends = await ref.read(friendsProvider.future);
    if (tor == null || reachable.isEmpty || friends.isEmpty) return 0;

    final db = await ref.read(museDbProvider);
    var synced = 0;
    final changed = <String>[];
    for (final friend in friends) {
      if (!reachable.contains(friend.onion)) continue;
      try {
        final manifest = await fetchFriendManifest(
          socksPort: tor.socksPort,
          onion: friend.onion,
        );
        final ids = await _import(db, friend, manifest);
        changed.addAll(ids);
        synced += 1;
      } catch (_) {
        // /health answered but /manifest failed: keep last-known content.
      }
    }

    if (synced > 0) {
      ref.invalidate(playlistsProvider);
      for (final id in changed) {
        ref.invalidate(playlistTracksProvider(id));
      }
    }
    return synced;
  }

  /// Imports [manifest] and returns the imported playlist ids.
  Future<List<String>> _import(
    MuseDb db,
    Friend friend,
    FriendManifest manifest,
  ) async {
    final keepPlaylistIds = <String>{};
    final keepTrackIds = <String>{};
    final keepScopes = <(ShareScopeType, String)>{};
    final allTracks = <RemoteTrackMeta>[];

    for (final scope in manifest.scopes) {
      final playlistId = 'remote:${friend.onion}:${scope.type.name}:${scope.id}';
      keepPlaylistIds.add(playlistId);
      keepScopes.add((scope.type, scope.id));

      await db.upsertRemoteManifest(
        ownerOnion: friend.onion,
        scopeType: scope.type,
        scopeId: scope.id,
      );
      await db.importRemotePlaylist(
        id: playlistId,
        ownerOnion: friend.onion,
        name: '${friend.name} · '
            '${scope.label.isEmpty ? scope.type.name : scope.label}',
        tracks: [
          for (final track in scope.tracks)
            PlaylistTrack(
              trackId: track.trackId,
              title: track.title,
              artist: track.artist,
              albumTitle: track.albumTitle,
              albumId: track.albumId,
              durationMs: track.durationMs,
              ownerOnion: friend.onion,
            ),
        ],
      );

      for (final track in scope.tracks) {
        keepTrackIds.add(track.trackId);
        allTracks.add(track);
      }
    }

    await db.upsertRemoteTracks(friend.onion, allTracks);
    await db.pruneRemoteContent(
      ownerOnion: friend.onion,
      keepPlaylistIds: keepPlaylistIds,
      keepTrackIds: keepTrackIds,
      keepScopes: keepScopes,
    );
    return keepPlaylistIds.toList();
  }
}