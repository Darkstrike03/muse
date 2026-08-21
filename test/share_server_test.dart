import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:muse/features/stream/share_resolver.dart';
import 'package:muse/features/stream/share_server.dart';
import 'package:muse/shared/models/shared_scope.dart';
import 'package:muse/shared/models/track.dart';

Future<Map<String, Object?>> _getJson(String url) async {
  final client = HttpClient();
  final request = await client.getUrl(Uri.parse(url));
  final response = await request.close();
  final body = await response.transform(utf8.decoder).join();
  return {
    'status': response.statusCode,
    'body': jsonDecode(body) as Map<String, Object?>,
    'headers': response.headers,
  };
}

void main() {
  late Directory tempDir;
  late File songFile;
  late Track track;
  const onion = 'abcdefghijklmnopqrstuvwxyz234567abcdefghijklmnopqrstuvwxyz23';
  const sharedPlaylist = SharedScope(
    type: ShareScopeType.playlist,
    id: 'pl1',
    label: 'Mix',
  );

  late ShareServer server;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('muse_share_test');
    songFile = File('${tempDir.path}${Platform.pathSeparator}song.mp3');
    await songFile.writeAsBytes(List.generate(1024, (i) => i % 256));
    track = Track(
      id: songFile.path,
      title: 'Tune',
      artist: 'Artist',
      albumId: 'album1',
      albumTitle: 'Album',
      filePath: songFile.path,
      duration: const Duration(milliseconds: 3000),
    );

    final resolver = ShareResolver(
      onion: onion,
      deviceName: 'My Muse',
      isShareAll: () => false,
      sharedScopes: () => [sharedPlaylist],
      allTracks: () => [track],
      scopeTracks: (scope) =>
          scope.type == ShareScopeType.playlist && scope.id == 'pl1'
              ? [track]
              : const [],
      trackById: (id) => id == track.id ? track : null,
    );

    server = await ShareServer.start(port: 0, resolver: resolver);
  });

  tearDown(() async {
    await server.close();
    await tempDir.delete(recursive: true);
  });

  test('health reports identity', () async {
    final result = await _getJson('http://127.0.0.1:${server.port}/health');
    expect(result['status'], 200);
    final body = result['body']! as Map<String, Object?>;
    expect(body['ok'], isTrue);
    expect(body['onion'], onion);
    expect(body['name'], 'My Muse');
  });

  test('manifest lists explicitly shared scopes with tracks', () async {
    final result = await _getJson('http://127.0.0.1:${server.port}/manifest');
    expect(result['status'], 200);
    final body = result['body']! as Map<String, Object?>;
    expect(body['shareAll'], isFalse);
    final scopes = body['scopes']! as List;
    expect(scopes.length, 1);
    final scope = scopes.first as Map<String, Object?>;
    expect(scope['type'], 'playlist');
    expect(scope['id'], 'pl1');
    final tracks = scope['tracks']! as List;
    expect(tracks.length, 1);
    final first = tracks.first as Map<String, Object?>;
    expect(first['title'], 'Tune');
    expect(first['id'], track.id);
  });

  test('single-scope manifest endpoint works', () async {
    final result =
        await _getJson('http://127.0.0.1:${server.port}/manifest/playlist/pl1');
    expect(result['status'], 200);
    final tracks =
        (result['body']! as Map<String, Object?>)['tracks']! as List;
    expect(tracks.length, 1);
  });

  test('unshared scope is forbidden', () async {
    final result =
        await _getJson('http://127.0.0.1:${server.port}/manifest/playlist/nope');
    expect(result['status'], 403);
  });

  test('song serves full bytes with range support', () async {
    final client = HttpClient();
    final request =
        await client.getUrl(Uri.parse('http://127.0.0.1:${server.port}/song/${Uri.encodeComponent(track.id)}'));
    final response = await request.close();
    final bytes = await response.fold<List<int>>(
      <int>[],
      (acc, chunk) => acc..addAll(chunk),
    );
    expect(response.statusCode, 200);
    expect(bytes.length, 1024);
    expect(response.headers.value('accept-ranges'), 'bytes');
    expect(response.headers.value('content-length'), '1024');
  });

  test('song honors a byte range', () async {
    final client = HttpClient();
    final request = await client
        .getUrl(Uri.parse('http://127.0.0.1:${server.port}/song/${Uri.encodeComponent(track.id)}'));
    request.headers.set('range', 'bytes=100-199');
    final response = await request.close();
    final bytes = await response.fold<List<int>>(
      <int>[],
      (acc, chunk) => acc..addAll(chunk),
    );
    expect(response.statusCode, 206);
    expect(bytes.length, 100);
    expect(response.headers.value('content-range'), 'bytes 100-199/1024');
    expect(bytes.first, 100 % 256);
  });

  test('unshared track is forbidden, unknown track is 404', () async {
    final client = HttpClient();

    final forbidden = await client
        .getUrl(Uri.parse('http://127.0.0.1:${server.port}/song/not-shared'));
    final forbiddenResponse = await forbidden.close();
    expect(forbiddenResponse.statusCode, 403);

    // Share-all off: an unlisted track id is forbidden, but the shared track is fine.
    final unknown = await client
        .getUrl(Uri.parse('http://127.0.0.1:${server.port}/song/does-not-exist.mp3'));
    final unknownResponse = await unknown.close();
    expect(unknownResponse.statusCode, 403);
  });
}