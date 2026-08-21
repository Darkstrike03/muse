import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/storage/muse_db.dart';
import '../../shared/models/playlist.dart';
import '../../shared/models/track.dart';
import '../library/library_provider.dart';
import '../stream/cache_provider.dart';
import '../stream/friends_reachability_provider.dart';

/// Seam around the platform image picker so the playlist UI is testable
/// (image_picker is a platform channel and can't run in tests).
final pickPlaylistImageProvider = Provider<Future<String?> Function()>(
  (ref) => () async {
    final file = await ImagePicker().pickImage(source: ImageSource.gallery);
    return file?.path;
  },
);

/// User playlists, persisted in SQLite. Membership metadata is denormalized
/// so playlists stay fully readable when a friend's device is offline.
final playlistsProvider =
    AsyncNotifierProvider<Playlists, List<Playlist>>(Playlists.new);

class Playlists extends AsyncNotifier<List<Playlist>> {
  @override
  Future<List<Playlist>> build() async {
    final db = await ref.watch(museDbProvider);
    return db.getPlaylists();
  }

  Future<Playlist?> create(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return null;
    final id = 'pl_${DateTime.now().microsecondsSinceEpoch}';
    final playlist = Playlist(id: id, name: trimmed);
    final db = await ref.read(museDbProvider);
    await db.insertPlaylist(playlist);
    await _reload();
    return playlist;
  }

  Future<void> delete(String id) async {
    final db = await ref.read(museDbProvider);
    await db.deletePlaylist(id);
    await _reload();
  }

  Future<void> rename(String id, String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    final db = await ref.read(museDbProvider);
    await db.renamePlaylist(id, trimmed);
    await _reload();
  }

  Future<void> setImage(String id, String? path) async {
    final db = await ref.read(museDbProvider);
    await db.setPlaylistImage(id, path);
    await _reload();
  }

  /// Appends [tracks] to a playlist. Duplicate tracks are skipped.
  Future<void> addTracks(String id, List<Track> tracks) async {
    final db = await ref.read(museDbProvider);
    await db.addPlaylistTracks(
      id,
      [for (final t in tracks) PlaylistTrack.fromTrack(t)],
    );
    await _reload();
  }

  /// Removes a track (local or remote) from a playlist.
  Future<void> removeTrack(String id, Track track) async {
    final db = await ref.read(museDbProvider);
    final row = PlaylistTrack.fromTrack(track);
    await db.removePlaylistTrack(id, row.trackId);
    await _reload();
  }

  Future<void> _reload() async {
    final db = await ref.read(museDbProvider);
    state = AsyncData(await db.getPlaylists());
  }
}

/// The [Track]s of a playlist, resolved from stored rows in playlist order.
/// Local rows resolve against the library; remote rows become remote tracks.
final playlistTracksProvider =
    FutureProvider.family<List<Track>, String>((ref, playlistId) async {
  final db = await ref.watch(museDbProvider);
  final rows = await db.getPlaylistTracks(playlistId);

  // Remote rows are fully denormalized, so only playlists containing local
  // tracks need the library scan — a slow or failed scan can't blank out an
  // imported playlist.
  Map<String, Track> byId = const {};
  if (rows.any((row) => row.isLocal)) {
    final library = await ref.watch(libraryProvider.future);
    byId = {for (final t in library) t.id: t};
  }

  final tracks = <Track>[];
  for (final row in rows) {
    final track = _trackFromRow(row, byId);
    if (track != null) tracks.add(track);
  }
  return tracks;
});

Track? _trackFromRow(PlaylistTrack row, Map<String, Track> libraryById) {
  if (row.isLocal) {
    final local = libraryById[row.trackId];
    if (local != null) return local;
    if (row.title.isEmpty) return null; // legacy/unknown id: skip
    return Track(
      id: row.trackId,
      title: row.title,
      artist: row.artist,
      albumId: row.albumId.isEmpty ? row.trackId : row.albumId,
      albumTitle: row.albumTitle,
      filePath: row.trackId,
      duration: Duration(milliseconds: row.durationMs),
    );
  }
  final owner = row.ownerOnion ?? '';
  final fullId = 'remote:$owner:${row.trackId}';
  return Track(
    id: fullId,
    title: row.title,
    artist: row.artist,
    albumId: row.albumId.isEmpty ? fullId : row.albumId,
    albumTitle: row.albumTitle,
    duration: Duration(milliseconds: row.durationMs),
    remoteOwner: owner,
    remoteTrackId: row.trackId,
  );
}

/// Whether a track can currently be played. Local tracks check the file on
/// disk; remote tracks are available when their owner is reachable or the
/// track is fully cached. Unavailable tracks are greyed out in the UI.
final trackAvailabilityProvider =
    FutureProvider.family<bool, String>((ref, id) async {
  if (id.startsWith('remote:')) {
    final parts = id.split(':');
    final onion = parts.length >= 3 ? parts[1] : null;
    if (onion != null && ref.watch(reachableFriendsProvider).contains(onion)) {
      return true;
    }
    return ref.watch(cacheStateProvider(id).future);
  }
  if (id.isEmpty) return false;
  return File(id).existsSync();
});
