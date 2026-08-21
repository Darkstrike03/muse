import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:muse/core/networking/tor_service.dart';
import 'package:muse/core/storage/muse_db.dart';
import 'package:muse/features/stream/friend_sync_provider.dart';
import 'package:muse/features/stream/friends_reachability_provider.dart';
import 'package:muse/features/stream/tor_controller_provider.dart';
import 'package:muse/shared/models/remote_track_meta.dart';
import 'package:muse/shared/models/shared_scope.dart';

import 'support/fakes.dart';

const _onion = 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

class _FakeTorService implements TorService {
  _FakeTorService(this.socksPort);

  @override
  final int socksPort;

  @override
  bool get isRunning => true;

  @override
  String? get onion => _onion;

  @override
  Future<String> onionAddress() async => _onion;

  @override
  Future<void> start() async {}

  @override
  Future<void> stop() async {}
}

class _StaticTor extends TorController {
  _StaticTor(this.socksPort);

  final int socksPort;

  @override
  Future<TorService?> build() async => _FakeTorService(socksPort);
}

void main() {
  sqfliteFfiInit();

  late MuseDb db;

  setUp(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    SharedPreferences.setMockInitialValues({});
    db = await MuseDb.open(path: inMemoryDatabasePath);
  });

  tearDown(() => db.close());

  group('remote content storage', () {
    test('imports a playlist with denormalized remote tracks', () async {
      await db.insertFriend(_onion, 'Bob');
      await db.importRemotePlaylist(
        id: 'remote:$_onion:playlist:pl1',
        ownerOnion: _onion,
        name: 'Bob · Mix',
        tracks: [
          PlaylistTrack(
            trackId: '/a.mp3',
            title: 'A',
            artist: 'Art',
            albumTitle: 'Album',
            albumId: 'al1',
            durationMs: 1000,
            ownerOnion: _onion,
          ),
        ],
      );

      final playlists = await db.getPlaylists();
      expect(playlists.length, 1);
      expect(playlists.first.id, 'remote:$_onion:playlist:pl1');
      expect(playlists.first.name, 'Bob · Mix');
      expect(playlists.first.ownerOnion, _onion);
      expect(playlists.first.isRemote, isTrue);

      final tracks = await db.getPlaylistTracks('remote:$_onion:playlist:pl1');
      expect(tracks.length, 1);
      expect(tracks.first.trackId, '/a.mp3');
      expect(tracks.first.isLocal, isFalse);
      expect(tracks.first.ownerOnion, _onion);
      expect(tracks.first.albumTitle, 'Album');
    });

    test('re-import replaces membership', () async {
      await db.insertFriend(_onion, 'Bob');
      const id = 'remote:$_onion:playlist:pl1';
      await db.importRemotePlaylist(
        id: id,
        ownerOnion: _onion,
        name: 'Bob · Mix',
        tracks: [
          PlaylistTrack(
              trackId: '/a.mp3',
              title: 'A',
              artist: 'Art',
              albumTitle: 'Album',
              albumId: 'al1',
              durationMs: 1,
              ownerOnion: _onion),
        ],
      );
      await db.importRemotePlaylist(
        id: id,
        ownerOnion: _onion,
        name: 'Bob · Mix',
        tracks: [
          PlaylistTrack(
              trackId: '/a.mp3',
              title: 'A',
              artist: 'Art',
              albumTitle: 'Album',
              albumId: 'al1',
              durationMs: 1,
              ownerOnion: _onion),
          PlaylistTrack(
              trackId: '/b.mp3',
              title: 'B',
              artist: 'Art',
              albumTitle: 'Album',
              albumId: 'al1',
              durationMs: 2,
              ownerOnion: _onion),
        ],
      );

      final tracks = await db.getPlaylistTracks(id);
      expect(tracks.map((t) => t.trackId), ['/a.mp3', '/b.mp3']);
    });

    test('prune drops vanished scopes and keeps the rest', () async {
      await db.insertFriend(_onion, 'Bob');
      await db.importRemotePlaylist(
        id: 'remote:$_onion:playlist:pl1',
        ownerOnion: _onion,
        name: 'Bob · Mix',
        tracks: [
          PlaylistTrack(
              trackId: '/a.mp3',
              title: 'A',
              artist: 'Art',
              albumTitle: 'Album',
              albumId: 'al1',
              durationMs: 1,
              ownerOnion: _onion),
        ],
      );
      await db.importRemotePlaylist(
        id: 'remote:$_onion:playlist:pl2',
        ownerOnion: _onion,
        name: 'Bob · Chill',
        tracks: [
          PlaylistTrack(
              trackId: '/b.mp3',
              title: 'B',
              artist: 'Art',
              albumTitle: 'Album',
              albumId: 'al1',
              durationMs: 2,
              ownerOnion: _onion),
        ],
      );
      await db.upsertRemoteManifest(
          ownerOnion: _onion,
          scopeType: ShareScopeType.playlist,
          scopeId: 'pl1');
      await db.upsertRemoteManifest(
          ownerOnion: _onion,
          scopeType: ShareScopeType.playlist,
          scopeId: 'pl2');
      await db.upsertRemoteTracks(_onion, [
        RemoteTrackMeta(trackId: '/a.mp3', title: 'A', artist: 'Art', albumId: 'al1'),
        RemoteTrackMeta(trackId: '/b.mp3', title: 'B', artist: 'Art', albumId: 'al1'),
      ]);

      // pl2 vanished from the friend's sharing.
      await db.pruneRemoteContent(
        ownerOnion: _onion,
        keepPlaylistIds: {'remote:$_onion:playlist:pl1'},
        keepTrackIds: {'/a.mp3'},
        keepScopes: {(ShareScopeType.playlist, 'pl1')},
      );

      final playlists = await db.getPlaylists();
      expect(playlists.map((p) => p.id),
          ['remote:$_onion:playlist:pl1']);
      expect(
        await db.getPlaylistTracks('remote:$_onion:playlist:pl2'),
        isEmpty,
      );
    });

    test('removeFriendContent wipes everything imported from a friend', () async {
      await db.insertFriend(_onion, 'Bob');
      await db.importRemotePlaylist(
        id: 'remote:$_onion:playlist:pl1',
        ownerOnion: _onion,
        name: 'Bob · Mix',
        tracks: [
          PlaylistTrack(
              trackId: '/a.mp3',
              title: 'A',
              artist: 'Art',
              albumTitle: 'Album',
              albumId: 'al1',
              durationMs: 1,
              ownerOnion: _onion),
        ],
      );
      await db.upsertRemoteManifest(
          ownerOnion: _onion,
          scopeType: ShareScopeType.playlist,
          scopeId: 'pl1');
      await db.upsertRemoteTracks(_onion, [
        RemoteTrackMeta(trackId: '/a.mp3', title: 'A', artist: 'Art', albumId: 'al1'),
      ]);

      await db.removeFriendContent(_onion);

      expect(await db.getPlaylists(), isEmpty);
      expect(
        await db.getPlaylistTracks('remote:$_onion:playlist:pl1'),
        isEmpty,
      );
      // removeFriendContent only clears imported content; the caller
      // (Friends.remove) also deletes the friend record itself.
      expect((await db.getFriends()).length, 1);
    });
  });

  group('FriendSync provider', () {
    test('imports a reachable friend and prunes after they stop sharing',
        () async {
      await db.insertFriend(_onion, 'Bob');

      final server = FakeManifestServer(manifest: {
        'app': 'muse',
        'name': 'Bob',
        'shareAll': false,
        'scopes': [
          {
            'type': 'playlist',
            'id': 'pl1',
            'label': 'Mix',
            'tracks': [
              {'id': '/a.mp3', 'title': 'A'},
            ],
          },
        ],
      });
      final serverPort = await server.start();
      addTearDown(server.close);

      final proxy = FakeSocksProxy(forceTargetPort: serverPort);
      final proxyPort = await proxy.start();
      addTearDown(proxy.close);

      final container = ProviderContainer(
        overrides: [
          museDbProvider.overrideWithValue(Future.value(db)),
          torControllerProvider.overrideWith(() => _StaticTor(proxyPort)),
          reachableFriendsProvider.overrideWithValue({_onion}),
        ],
      );
      addTearDown(container.dispose);

      await container.read(friendSyncProvider.future);

      final playlists = await db.getPlaylists();
      expect(playlists.length, 1);
      expect(playlists.first.name, 'Bob · Mix');
      expect(playlists.first.ownerOnion, _onion);
      expect(playlists.first.isRemote, isTrue);

      // Bob stops sharing: refresh drops the imported playlist and its rows.
      server.manifest = {
        'app': 'muse',
        'name': 'Bob',
        'shareAll': false,
        'scopes': <Map<String, dynamic>>[],
      };
      await container.read(friendSyncProvider.notifier).refresh();

      expect(await db.getPlaylists(), isEmpty);
      expect(
        await db.getPlaylistTracks('remote:$_onion:playlist:pl1'),
        isEmpty,
      );
    });

    test('leaves last-known content when the manifest fetch fails', () async {
      await db.insertFriend(_onion, 'Bob');
      await db.importRemotePlaylist(
        id: 'remote:$_onion:playlist:pl1',
        ownerOnion: _onion,
        name: 'Bob · Mix',
        tracks: [
          PlaylistTrack(
              trackId: '/a.mp3',
              title: 'A',
              artist: 'Art',
              albumTitle: 'Album',
              albumId: 'al1',
              durationMs: 1,
              ownerOnion: _onion),
        ],
      );

      // Reachable, but nothing is actually listening (fetch throws).
      final proxy = FakeSocksProxy();
      final proxyPort = await proxy.start();
      addTearDown(proxy.close);

      final container = ProviderContainer(
        overrides: [
          museDbProvider.overrideWithValue(Future.value(db)),
          torControllerProvider.overrideWith(() => _StaticTor(proxyPort)),
          reachableFriendsProvider.overrideWithValue({_onion}),
        ],
      );
      addTearDown(container.dispose);

      await container.read(friendSyncProvider.future);

      final playlists = await db.getPlaylists();
      expect(playlists.length, 1);
      expect(playlists.first.name, 'Bob · Mix');
    });
  });
}