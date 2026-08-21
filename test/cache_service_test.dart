import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:muse/core/networking/remote_stream.dart';
import 'package:muse/core/storage/cache_service.dart';
import 'package:muse/core/storage/muse_db.dart';
import 'package:muse/features/stream/share_resolver.dart';
import 'package:muse/features/stream/share_server.dart';
import 'package:muse/shared/models/track.dart';

import 'support/fakes.dart';

/// Exercises the full local pipeline for the real ShareServer (the sharer)
/// behind the FakeSocksProxy (the SOCKS tunnel Tor provides) into the
/// CacheService (the listener's byte cache). No Tor, but every network hop is
/// real.
void main() {
  late Directory tempDir;
  late Directory cacheDir;
  late MuseDb db;
  late CacheService cache;
  late ShareServer server;
  late FakeSocksProxy proxy;
  late int proxyPort;
  late File songFile;
  late Track track;

  const onion = 'abcdefghijklmnopqrstuvwxyz234567abcdefghijklmnopqrstuvwxyz23';
  const compositeId =
      'remote:abcdefghijklmnopqrstuvwxyz234567abcdefghijklmnopqrstuvwxyz23:'
      'path/to/tune.mp3';

  setUp(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    SharedPreferences.setMockInitialValues({});

    tempDir = await Directory.systemTemp.createTemp('muse_cache_test');
    cacheDir = Directory('${tempDir.path}${Platform.pathSeparator}cache');
    await cacheDir.create();
    db = await MuseDb.open(path: inMemoryDatabasePath);
    cache = CacheService(db, cacheDir);

    songFile = File('${tempDir.path}${Platform.pathSeparator}song.mp3');
    await songFile.writeAsBytes(List.generate(1024 * 1024, (i) => i % 256));
    track = Track(
      id: songFile.path,
      title: 'Tune',
      artist: 'Artist',
      albumId: 'album1',
      albumTitle: 'Album',
      filePath: songFile.path,
      duration: const Duration(seconds: 60),
    );

    final resolver = ShareResolver(
      onion: onion,
      deviceName: 'My Muse',
      isShareAll: () => true,
      sharedScopes: () => const [],
      allTracks: () => [track],
      scopeTracks: (_) => const [],
      trackById: (id) => id == track.id ? track : null,
    );
    server = await ShareServer.start(port: 0, resolver: resolver);

    proxy = FakeSocksProxy();
    proxyPort = await proxy.start();
  });

  tearDown(() async {
    await proxy.close();
    await server.close();
    await db.close();
    await tempDir.delete(recursive: true);
  });

  Future<RemoteStream> download() => cache.streamTrack(
        trackId: compositeId,
        onion: onion,
        remoteTrackId: track.id,
        socksPort: proxyPort,
        targetPort: server.port,
      );

  test('streams a full song through the proxy into a complete cache file',
      () async {
    final stream = await download();
    final progress = <double?>[];
    final sub = stream.progress.listen(progress.add);
    await stream.done;
    await sub.cancel();

    final file = cache.fileFor(compositeId);
    expect(await file.exists(), isTrue);
    final bytes = await file.readAsBytes();
    expect(bytes.length, songFile.lengthSync());
    expect(bytes, equals(await songFile.readAsBytes()));

    final entry = await cache.entry(compositeId);
    expect(entry, isNotNull);
    expect(entry!.complete, isTrue);
    expect(entry.sizeBytes, songFile.lengthSync());
    expect(progress.last, 1.0);
    expect(proxy.lastRequestedHost, '$onion.onion');
    expect(proxy.lastRequestedPort, server.port);
  });

  test('ready resolves once the first chunk is on disk', () async {
    final stream = await download();
    await stream.ready; // must not hang or error
    final file = cache.fileFor(compositeId);
    expect(await file.exists(), isTrue);
    await stream.done;
  });

  test('resumes from an existing partial file with a byte range', () async {
    const partial = 128 * 1024;
    final file = cache.fileFor(compositeId);
    await file.writeAsBytes(List.generate(partial, (i) => i % 256));
    await db.upsertCacheEntry(
      const CacheEntry(
        trackId: compositeId,
        filePath: '',
        sizeBytes: partial,
        complete: false,
      ),
    );

    final stream = await download();
    await stream.done;

    final bytes = await file.readAsBytes();
    expect(bytes.length, songFile.lengthSync());
    expect(bytes, equals(await songFile.readAsBytes()));

    final entry = await cache.entry(compositeId);
    expect(entry!.complete, isTrue);
    expect(entry.sizeBytes, songFile.lengthSync());
  });

  test('a forbidden track surfaces as a stream error', () async {
    final stream = await cache.streamTrack(
      trackId: compositeId,
      onion: onion,
      remoteTrackId: 'not-shared',
      socksPort: proxyPort,
      targetPort: server.port,
    );
    await expectLater(stream.done, throwsA(isA<HttpException>()));
  });

  test('remove cancels an in-flight download and deletes the bytes', () async {
    final stream = await download();
    await cache.remove(compositeId);

    expect(await cache.entry(compositeId), isNull);
    expect(await cache.fileFor(compositeId).exists(), isFalse);
    await expectLater(stream.done, completes);
  });

  test('repeated streamTrack returns the same active download', () async {
    final first = await download();
    final second = await download();
    expect(identical(first, second), isTrue);
    await first.done;
  });
}