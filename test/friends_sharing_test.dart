import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:muse/core/storage/muse_db.dart';
import 'package:muse/features/pairing/friends_provider.dart';
import 'package:muse/features/playlist/playlists_provider.dart';
import 'package:muse/features/stream/friends_reachability_provider.dart';
import 'package:muse/features/stream/sharing_provider.dart';
import 'package:muse/shared/models/playlist.dart';
import 'package:muse/shared/models/shared_scope.dart';

const _onion =
    'abcdefghijklmnopqrstuvwxyz234567abcdefghijklmnopqrstuvwxyz23';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  late MuseDb db;
  late ProviderContainer container;

  Future<void> useDb({Set<String> reachable = const {}}) async {
    db = await MuseDb.open(path: inMemoryDatabasePath);
    container = ProviderContainer(overrides: [
      museDbProvider.overrideWithValue(Future.value(db)),
      reachableFriendsProvider.overrideWithValue(reachable),
    ]);
    addTearDown(container.dispose);
    addTearDown(db.close);
    await container.read(friendsProvider.future);
    await container.read(sharingProvider.future);
  }

  test('friends add and remove', () async {
    await useDb();
    final notifier = container.read(friendsProvider.notifier);

    await notifier.add(_onion, 'Ari');
    var friends = container.read(friendsProvider).value!;
    expect(friends.length, 1);
    expect(friends.first.name, 'Ari');
    expect(friends.first.onion, _onion);

    await notifier.remove(_onion);
    expect(container.read(friendsProvider).value, isEmpty);
  });

  test('sharing config: shareAll + scopes toggle', () async {
    await useDb();
    final notifier = container.read(sharingProvider.notifier);

    expect(container.read(sharingProvider).value!.shareAll, isFalse);

    await notifier.setShareAll(true);
    expect(container.read(sharingProvider).value!.shareAll, isTrue);
    await notifier.setShareAll(false);

    await notifier.toggleScope(
      const SharedScope(
        type: ShareScopeType.playlist,
        id: 'pl1',
        label: 'Mix',
      ),
    );
    var scopes = container.read(sharingProvider).value!.scopes;
    expect(scopes.length, 1);
    expect(scopes.first.id, 'pl1');

    await notifier.toggleScope(
      const SharedScope(
        type: ShareScopeType.playlist,
        id: 'pl1',
        label: 'Mix',
      ),
    );
    expect(container.read(sharingProvider).value!.scopes, isEmpty);
  });

  test('remote track availability follows friend reachability', () async {
    await useDb(); // reachable set is empty → remote track unavailable

    await db.insertPlaylist(const Playlist(id: 'p1', name: 'Remote mix'));
    await db.addPlaylistTracks('p1', [
      PlaylistTrack(
        trackId: 'song1',
        title: 'B',
        artist: 'Friend',
        albumTitle: 'Remote',
        albumId: 'remote-album',
        durationMs: 0,
        ownerOnion: _onion,
      ),
    ]);

    final tracks =
        await container.read(playlistTracksProvider('p1').future);
    expect(tracks.length, 1);
    expect(tracks.first.isRemote, isTrue);
    expect(tracks.first.id, 'remote:$_onion:song1');

    final offline = await container
        .read(trackAvailabilityProvider(tracks.first.id).future);
    expect(offline, isFalse);

    // Friend comes online → same track becomes available.
    final onlineContainer = ProviderContainer(overrides: [
      museDbProvider.overrideWithValue(Future.value(db)),
      reachableFriendsProvider.overrideWithValue({_onion}),
    ]);
    addTearDown(onlineContainer.dispose);
    final online = await onlineContainer
        .read(trackAvailabilityProvider(tracks.first.id).future);
    expect(online, isTrue);
  });
}