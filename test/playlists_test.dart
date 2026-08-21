import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:muse/core/storage/muse_db.dart';
import 'package:muse/features/playlist/playlists_provider.dart';
import 'package:muse/shared/models/playlist.dart';
import 'package:muse/shared/models/track.dart';

Track _track(String id) => Track(
      id: id,
      title: 'Song',
      artist: 'Artist',
      albumId: 'album',
      albumTitle: 'Album',
      filePath: id,
      duration: const Duration(seconds: 10),
    );

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

  Future<void> useDb([String? path]) async {
    db = await MuseDb.open(path: path ?? inMemoryDatabasePath);
    container = ProviderContainer(overrides: [
      museDbProvider.overrideWithValue(Future.value(db)),
    ]);
    addTearDown(container.dispose);
    addTearDown(db.close);
    await container.read(playlistsProvider.future);
  }

  test('create adds a playlist', () async {
    await useDb();
    final notifier = container.read(playlistsProvider.notifier);

    final created = await notifier.create('Road trip');
    expect(created, isNotNull);
    expect(created!.name, 'Road trip');
    expect(created.trackIds, isEmpty);

    final list = container.read(playlistsProvider).value!;
    expect(list.length, 1);
    expect(list.first.name, 'Road trip');
  });

  test('create ignores blank names', () async {
    await useDb();
    final notifier = container.read(playlistsProvider.notifier);

    expect(await notifier.create('   '), isNull);
    expect(container.read(playlistsProvider).value, isEmpty);
  });

  test('rename, setImage, addTracks (deduped), removeTrack, delete', () async {
    await useDb();
    final notifier = container.read(playlistsProvider.notifier);

    final created = await notifier.create('Mixed');
    final id = created!.id;

    await notifier.setImage(id, r'C:\img\cover.png');
    await notifier.addTracks(id, [_track('a'), _track('b'), _track('a')]);
    await notifier.rename(id, 'Renamed');

    var playlist = container.read(playlistsProvider).value!.first;
    expect(playlist.imagePath, r'C:\img\cover.png');
    expect(playlist.trackIds, ['a', 'b']);
    expect(playlist.name, 'Renamed');

    await notifier.removeTrack(id, _track('a'));
    playlist = container.read(playlistsProvider).value!.first;
    expect(playlist.trackIds, ['b']);

    await notifier.delete(id);
    expect(container.read(playlistsProvider).value, isEmpty);
  });

  test('playlists persist across restarts (file-backed)', () async {
    final dir = await Directory.systemTemp.createTemp('muse_db_test_');
    addTearDown(() => dir.delete(recursive: true));
    final path = p.join(dir.path, 'muse.db');

    var first = await MuseDb.open(path: path);
    await first.insertPlaylist(const Playlist(id: 'p1', name: 'Persist me'));
    await first.addPlaylistTracks('p1', [
      PlaylistTrack(
        trackId: 'x',
        title: 'Song',
        artist: 'Artist',
        albumTitle: 'Album',
        albumId: 'album',
        durationMs: 10000,
      ),
    ]);
    await first.close();

    final second = await MuseDb.open(path: path);
    addTearDown(second.close);
    final playlists = await second.getPlaylists();
    expect(playlists.length, 1);
    expect(playlists.first.name, 'Persist me');
    expect(playlists.first.trackIds, ['x']);
  });

  test('legacy JSON playlists migrate to SQLite once', () async {
    SharedPreferences.setMockInitialValues({
      'playlists': jsonEncode([
        {'id': 'legacy', 'name': 'Old', 'imagePath': null, 'trackIds': ['a', 'b']},
      ]),
    });

    await useDb();
    final list = container.read(playlistsProvider).value!;
    expect(list.length, 1);
    expect(list.first.name, 'Old');
    expect(list.first.trackIds, ['a', 'b']);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('playlists'), isNull);
  });
}