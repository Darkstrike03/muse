import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../shared/models/friend.dart';
import '../../shared/models/playlist.dart';
import '../../shared/models/remote_track_meta.dart';
import '../../shared/models/shared_scope.dart';
import '../../shared/models/track.dart';

/// Single SQLite store for everything that must survive a friend going
/// offline: playlists (with denormalized track metadata), friends, sharing
/// config, and (later) remote manifests + the byte-cache index.
///
/// The schema is created in [open] and migrated there; providers expose the
/// domain operations. Tests open the store on an in-memory database.
class MuseDb {
  MuseDb(this._db);

  static const _version = 2;

  final Database _db;

  static Future<MuseDb> open({String? path}) async {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
    final dbPath = path ?? await _defaultPath();
    final db = await databaseFactory.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: _version,
        onConfigure: _onConfigure,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
      ),
    );
    final muse = MuseDb(db);
    await muse._migrateLegacyPlaylists();
    return muse;
  }

  static Future<String> _defaultPath() async {
    final dir = await getApplicationSupportDirectory();
    final dbDir = Directory(p.join(dir.path, 'db'));
    await dbDir.create(recursive: true);
    return p.join(dbDir.path, 'muse.db');
  }

  static Future<void> _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
  }

  static Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE playlists (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        image_path TEXT,
        owner_onion TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE playlist_tracks (
        playlist_id TEXT NOT NULL REFERENCES playlists(id) ON DELETE CASCADE,
        position INTEGER NOT NULL,
        track_id TEXT NOT NULL,
        title TEXT NOT NULL DEFAULT '',
        artist TEXT NOT NULL DEFAULT '',
        album_title TEXT NOT NULL DEFAULT '',
        album_id TEXT NOT NULL DEFAULT '',
        duration_ms INTEGER NOT NULL DEFAULT 0,
        owner_onion TEXT,
        is_local INTEGER NOT NULL DEFAULT 1,
        PRIMARY KEY (playlist_id, position)
      )
    ''');
    await db.execute('''
      CREATE TABLE friends (
        onion TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        added_at INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE sharing_config (
        id INTEGER PRIMARY KEY CHECK (id = 1),
        share_all INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute('''
      CREATE TABLE shared_scopes (
        scope_type TEXT NOT NULL,
        scope_id TEXT NOT NULL,
        label TEXT NOT NULL DEFAULT '',
        PRIMARY KEY (scope_type, scope_id)
      )
    ''');
    await db.execute('''
      CREATE TABLE remote_manifests (
        owner_onion TEXT NOT NULL,
        scope_type TEXT NOT NULL,
        scope_id TEXT NOT NULL,
        fetched_at INTEGER NOT NULL,
        PRIMARY KEY (owner_onion, scope_type, scope_id)
      )
    ''');
    await db.execute('''
      CREATE TABLE remote_tracks (
        owner_onion TEXT NOT NULL,
        track_id TEXT NOT NULL,
        title TEXT NOT NULL DEFAULT '',
        artist TEXT NOT NULL DEFAULT '',
        album_title TEXT NOT NULL DEFAULT '',
        album_id TEXT NOT NULL DEFAULT '',
        duration_ms INTEGER NOT NULL DEFAULT 0,
        PRIMARY KEY (owner_onion, track_id)
      )
    ''');
    await db.execute('''
      CREATE TABLE cache (
        track_id TEXT PRIMARY KEY,
        file_path TEXT NOT NULL,
        size_bytes INTEGER NOT NULL DEFAULT 0,
        complete INTEGER NOT NULL DEFAULT 0,
        last_played_at INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute(
      'INSERT OR IGNORE INTO sharing_config (id, share_all) VALUES (1, 0)',
    );
  }

  static Future<void> _onUpgrade(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    // Version 2: playlists gained an owner_onion column so playlists imported
    // from a friend's shared scope are distinguishable from local ones.
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE playlists ADD COLUMN owner_onion TEXT');
    }
  }

  /// Moves the pre-SQLite JSON playlists into the relational store exactly
  /// once, then deletes the old key.
  Future<void> _migrateLegacyPlaylists() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('playlists');
    if (raw == null) return;
    final decoded = jsonDecode(raw) as List<dynamic>;
    for (final entry in decoded) {
      final json = entry as Map<String, dynamic>;
      await insertPlaylist(
        Playlist(
          id: json['id'] as String,
          name: json['name'] as String,
          imagePath: json['imagePath'] as String?,
        ),
      );
      final trackIds = (json['trackIds'] as List<dynamic>? ?? const [])
          .cast<String>();
      await addPlaylistTracks(
        json['id'] as String,
        [
          for (final id in trackIds)
            PlaylistTrack(
              trackId: id,
              title: '',
              artist: '',
              albumTitle: '',
              albumId: '',
              durationMs: 0,
              ownerOnion: null,
            ),
        ],
      );
    }
    await prefs.remove('playlists');
  }

  Future<void> close() => _db.close();

  // ── Playlists ────────────────────────────────────────────────────────────

  Future<List<Playlist>> getPlaylists() async {
    final rows = await _db.query('playlists', orderBy: 'name COLLATE NOCASE');
    final playlists = <Playlist>[];
    for (final row in rows) {
      playlists.add(await _playlistFromRow(row));
    }
    return playlists;
  }

  Future<Playlist?> getPlaylist(String id) async {
    final rows = await _db.query('playlists', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return _playlistFromRow(rows.first);
  }

  Future<void> insertPlaylist(Playlist playlist) async {
    await _db.insert('playlists', {
      'id': playlist.id,
      'name': playlist.name,
      'image_path': playlist.imagePath,
      'owner_onion': playlist.ownerOnion,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> renamePlaylist(String id, String name) async {
    await _db.update(
      'playlists',
      {'name': name},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> setPlaylistImage(String id, String? imagePath) async {
    await _db.update(
      'playlists',
      {'image_path': imagePath},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deletePlaylist(String id) async {
    await _db.delete('playlists', where: 'id = ?', whereArgs: [id]);
  }

  /// Appends [tracks] to a playlist. Duplicate track ids are skipped.
  Future<void> addPlaylistTracks(
    String playlistId,
    List<PlaylistTrack> tracks,
  ) async {
    if (tracks.isEmpty) return;
    final existingRows = await _db.query(
      'playlist_tracks',
      where: 'playlist_id = ?',
      whereArgs: [playlistId],
      columns: ['track_id'],
    );
    final existing = existingRows
        .map((row) => row['track_id'] as String)
        .toSet();
    final seen = {...existing};

    var position = await _nextPosition(playlistId);
    final batch = _db.batch();
    for (final track in tracks) {
      if (!seen.add(track.trackId)) continue;
      batch.insert('playlist_tracks', {
        'playlist_id': playlistId,
        'position': position,
        'track_id': track.trackId,
        'title': track.title,
        'artist': track.artist,
        'album_title': track.albumTitle,
        'album_id': track.albumId,
        'duration_ms': track.durationMs,
        'owner_onion': track.ownerOnion,
        'is_local': track.ownerOnion == null ? 1 : 0,
      });
      position += 1;
    }
    await batch.commit(noResult: true);
  }

  Future<void> removePlaylistTrack(String playlistId, String trackId) async {
    final removed = await _db.delete(
      'playlist_tracks',
      where: 'playlist_id = ? AND track_id = ?',
      whereArgs: [playlistId, trackId],
    );
    if (removed == 0) return;
    await _renumber(playlistId);
  }

  Future<List<PlaylistTrack>> getPlaylistTracks(String playlistId) async {
    final rows = await _db.query(
      'playlist_tracks',
      where: 'playlist_id = ?',
      whereArgs: [playlistId],
      orderBy: 'position ASC',
    );
    return [
      for (final row in rows)
        PlaylistTrack(
          trackId: row['track_id'] as String,
          title: row['title'] as String? ?? '',
          artist: row['artist'] as String? ?? '',
          albumTitle: row['album_title'] as String? ?? '',
          albumId: row['album_id'] as String? ?? '',
          durationMs: row['duration_ms'] as int? ?? 0,
          ownerOnion: row['owner_onion'] as String?,
        ),
    ];
  }

  Future<Playlist> _playlistFromRow(Map<String, Object?> row) async {
    final tracks = await getPlaylistTracks(row['id'] as String);
    return Playlist(
      id: row['id'] as String,
      name: row['name'] as String,
      imagePath: row['image_path'] as String?,
      ownerOnion: row['owner_onion'] as String?,
      trackIds: [for (final t in tracks) t.trackId],
    );
  }

  Future<int> _nextPosition(String playlistId) async {
    final rows = await _db.rawQuery(
      'SELECT COALESCE(MAX(position), -1) + 1 AS next '
      'FROM playlist_tracks WHERE playlist_id = ?',
      [playlistId],
    );
    return rows.first['next'] as int? ?? 0;
  }

  Future<void> _renumber(String playlistId) async {
    final rows = await _db.query(
      'playlist_tracks',
      where: 'playlist_id = ?',
      whereArgs: [playlistId],
      orderBy: 'position ASC',
    );
    final batch = _db.batch();
    for (var i = 0; i < rows.length; i++) {
      batch.update(
        'playlist_tracks',
        {'position': i},
        where: 'playlist_id = ? AND track_id = ?',
        whereArgs: [playlistId, rows[i]['track_id']],
      );
    }
    await batch.commit(noResult: true);
  }

  // ── Friends ──────────────────────────────────────────────────────────────

  Future<List<Friend>> getFriends() async {
    final rows = await _db.query('friends', orderBy: 'name COLLATE NOCASE');
    return [
      for (final row in rows)
        Friend(onion: row['onion'] as String, name: row['name'] as String),
    ];
  }

  Future<Friend?> getFriend(String onion) async {
    final rows = await _db.query('friends', where: 'onion = ?', whereArgs: [onion]);
    if (rows.isEmpty) return null;
    return Friend(
      onion: rows.first['onion'] as String,
      name: rows.first['name'] as String,
    );
  }

  Future<void> insertFriend(String onion, String name) async {
    await _db.insert('friends', {
      'onion': onion,
      'name': name,
      'added_at': DateTime.now().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deleteFriend(String onion) async {
    await _db.delete('friends', where: 'onion = ?', whereArgs: [onion]);
  }

  // ── Sharing config ───────────────────────────────────────────────────────

  Future<bool> getShareAll() async {
    final rows = await _db.query('sharing_config', where: 'id = 1');
    return (rows.first['share_all'] as int? ?? 0) == 1;
  }

  Future<void> setShareAll(bool value) async {
    await _db.update(
      'sharing_config',
      {'share_all': value ? 1 : 0},
      where: 'id = 1',
    );
  }

  Future<List<SharedScope>> getSharedScopes() async {
    final rows = await _db.query('shared_scopes');
    return [
      for (final row in rows)
        SharedScope(
          type: SharedScope.typeFromKey(row['scope_type'] as String),
          id: row['scope_id'] as String,
          label: row['label'] as String? ?? '',
        ),
    ];
  }

  Future<void> insertSharedScope(SharedScope scope) async {
    await _db.insert('shared_scopes', {
      'scope_type': scope.typeKey,
      'scope_id': scope.id,
      'label': scope.label,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deleteSharedScope(ShareScopeType type, String id) async {
    await _db.delete(
      'shared_scopes',
      where: 'scope_type = ? AND scope_id = ?',
      whereArgs: [type.name, id],
    );
  }

  // ── Cache index (which remote tracks have bytes on disk) ─────────────────

  Future<CacheEntry?> getCacheEntry(String trackId) async {
    final rows =
        await _db.query('cache', where: 'track_id = ?', whereArgs: [trackId]);
    return rows.isEmpty ? null : _cacheEntryFromRow(rows.first);
  }

  Future<List<CacheEntry>> getCacheEntries() async {
    final rows = await _db.query('cache', orderBy: 'track_id');
    return [for (final row in rows) _cacheEntryFromRow(row)];
  }

  Future<void> upsertCacheEntry(CacheEntry entry) async {
    await _db.insert('cache', {
      'track_id': entry.trackId,
      'file_path': entry.filePath,
      'size_bytes': entry.sizeBytes,
      'complete': entry.complete ? 1 : 0,
      'last_played_at': entry.lastPlayedAt,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> touchCache(String trackId, int lastPlayedAt) async {
    await _db.update(
      'cache',
      {'last_played_at': lastPlayedAt},
      where: 'track_id = ?',
      whereArgs: [trackId],
    );
  }

  Future<void> deleteCacheEntry(String trackId) async {
    await _db.delete('cache', where: 'track_id = ?', whereArgs: [trackId]);
  }

  Future<int> cacheTotalBytes() async {
    final rows = await _db
        .rawQuery('SELECT COALESCE(SUM(size_bytes), 0) AS total FROM cache');
    return (rows.first['total'] as int?) ?? 0;
  }

  CacheEntry _cacheEntryFromRow(Map<String, Object?> row) => CacheEntry(
        trackId: row['track_id'] as String,
        filePath: row['file_path'] as String,
        sizeBytes: row['size_bytes'] as int? ?? 0,
        complete: (row['complete'] as int? ?? 0) == 1,
        lastPlayedAt: row['last_played_at'] as int? ?? 0,
      );

  // ── Remote content (playlists imported from a friend's manifest) ─────────

  /// Records that [ownerOnion]'s [scope] was fetched just now.
  Future<void> upsertRemoteManifest({
    required String ownerOnion,
    required ShareScopeType scopeType,
    required String scopeId,
  }) async {
    await _db.insert('remote_manifests', {
      'owner_onion': ownerOnion,
      'scope_type': scopeType.name,
      'scope_id': scopeId,
      'fetched_at': DateTime.now().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Creates (or replaces) a playlist mirroring a friend's shared scope and
  /// sets its membership to exactly [tracks] in order.
  Future<void> importRemotePlaylist({
    required String id,
    required String ownerOnion,
    required String name,
    required List<PlaylistTrack> tracks,
  }) async {
    await _db.transaction((txn) async {
      await txn.insert('playlists', {
        'id': id,
        'name': name,
        'image_path': null,
        'owner_onion': ownerOnion,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      await txn.delete(
        'playlist_tracks',
        where: 'playlist_id = ?',
        whereArgs: [id],
      );
      if (tracks.isNotEmpty) {
        final batch = txn.batch();
        for (var i = 0; i < tracks.length; i++) {
          final track = tracks[i];
          batch.insert('playlist_tracks', {
            'playlist_id': id,
            'position': i,
            'track_id': track.trackId,
            'title': track.title,
            'artist': track.artist,
            'album_title': track.albumTitle,
            'album_id': track.albumId,
            'duration_ms': track.durationMs,
            'owner_onion': ownerOnion,
            'is_local': 0,
          });
        }
        await batch.commit(noResult: true);
      }
    });
  }

  /// Caches the metadata of [tracks] (the `remote_tracks` table).
  Future<void> upsertRemoteTracks(
    String ownerOnion,
    List<RemoteTrackMeta> tracks,
  ) async {
    if (tracks.isEmpty) return;
    final batch = _db.batch();
    for (final track in tracks) {
      batch.insert('remote_tracks', {
        'owner_onion': ownerOnion,
        'track_id': track.trackId,
        'title': track.title,
        'artist': track.artist,
        'album_title': track.albumTitle,
        'album_id': track.albumId,
        'duration_ms': track.durationMs,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  /// After syncing [ownerOnion], drops remote content the friend no longer
  /// shares: playlists/playlist-tracks whose scope vanished, manifest records
  /// for missing scopes, and cached track metadata no longer referenced.
  Future<void> pruneRemoteContent({
    required String ownerOnion,
    required Set<String> keepPlaylistIds,
    required Set<String> keepTrackIds,
    required Set<(ShareScopeType, String)> keepScopes,
  }) async {
    await _db.transaction((txn) async {
      final playlists = await txn.query(
        'playlists',
        where: 'owner_onion = ?',
        whereArgs: [ownerOnion],
        columns: ['id'],
      );
      for (final row in playlists) {
        final id = row['id'] as String;
        if (!keepPlaylistIds.contains(id)) {
          await txn.delete(
            'playlist_tracks',
            where: 'playlist_id = ?',
            whereArgs: [id],
          );
          await txn.delete('playlists', where: 'id = ?', whereArgs: [id]);
        }
      }

      final manifests = await txn.query(
        'remote_manifests',
        where: 'owner_onion = ?',
        whereArgs: [ownerOnion],
        columns: ['scope_type', 'scope_id'],
      );
      for (final row in manifests) {
        final scope = (
          SharedScope.typeFromKey(row['scope_type'] as String),
          row['scope_id'] as String,
        );
        if (!keepScopes.contains(scope)) {
          await txn.delete(
            'remote_manifests',
            where: 'owner_onion = ? AND scope_type = ? AND scope_id = ?',
            whereArgs: [ownerOnion, scope.$1.name, scope.$2],
          );
        }
      }

      if (keepTrackIds.isEmpty) {
        await txn.delete(
          'remote_tracks',
          where: 'owner_onion = ?',
          whereArgs: [ownerOnion],
        );
      } else {
        final placeholders = List.filled(keepTrackIds.length, '?').join(',');
        await txn.delete(
          'remote_tracks',
          where: 'owner_onion = ? AND track_id NOT IN ($placeholders)',
          whereArgs: [ownerOnion, ...keepTrackIds],
        );
      }
    });
  }

  /// Deletes everything imported from [ownerOnion] (used when a friend is
  /// removed). Playlist tracks cascade via the foreign key.
  Future<void> removeFriendContent(String ownerOnion) async {
    await _db.transaction((txn) async {
      final playlists = await txn.query(
        'playlists',
        where: 'owner_onion = ?',
        whereArgs: [ownerOnion],
        columns: ['id'],
      );
      for (final row in playlists) {
        await txn.delete(
          'playlist_tracks',
          where: 'playlist_id = ?',
          whereArgs: [row['id'] as String],
        );
      }
      await txn.delete(
        'playlists',
        where: 'owner_onion = ?',
        whereArgs: [ownerOnion],
      );
      await txn.delete(
        'remote_manifests',
        where: 'owner_onion = ?',
        whereArgs: [ownerOnion],
      );
      await txn.delete(
        'remote_tracks',
        where: 'owner_onion = ?',
        whereArgs: [ownerOnion],
      );
    });
  }
}

/// One cached remote track. [filePath] points into the app-support cache dir;
/// [complete] means the whole song is on disk and offline-playable.
class CacheEntry {
  const CacheEntry({
    required this.trackId,
    required this.filePath,
    required this.sizeBytes,
    required this.complete,
    this.lastPlayedAt = 0,
  });

  final String trackId;
  final String filePath;
  final int sizeBytes;
  final bool complete;
  final int lastPlayedAt;
}

/// One stored playlist-track row. Metadata is denormalized so playlists render
/// even when the owning device is unreachable.
class PlaylistTrack {
  const PlaylistTrack({
    required this.trackId,
    required this.title,
    required this.artist,
    required this.albumTitle,
    required this.albumId,
    required this.durationMs,
    this.ownerOnion,
  });

  final String trackId;
  final String title;
  final String artist;
  final String albumTitle;
  final String albumId;
  final int durationMs;

  /// Null for local tracks; the friend's onion for remote tracks.
  final String? ownerOnion;

  bool get isLocal => ownerOnion == null;

  static PlaylistTrack fromTrack(Track track) {
    final remote = track.remoteOwner != null;
    return PlaylistTrack(
      trackId: remote
          ? (track.remoteTrackId ?? track.id)
          : (track.filePath ?? track.id),
      title: track.title,
      artist: track.artist,
      albumTitle: track.albumTitle,
      albumId: track.albumId,
      durationMs: track.duration.inMilliseconds,
      ownerOnion: track.remoteOwner,
    );
  }
}

/// The app's single SQLite database handle. Overridden in tests with an
/// in-memory database via [MuseDb.open(path: inMemoryDatabasePath)].
final museDbProvider = Provider<Future<MuseDb>>((ref) => MuseDb.open());
