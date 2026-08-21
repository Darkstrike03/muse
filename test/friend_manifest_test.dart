import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:muse/features/stream/friend_manifest.dart';
import 'package:muse/shared/models/shared_scope.dart';

import 'support/fakes.dart';

const _onion = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

void main() {
  group('parseFriendManifest', () {
    test('parses scopes and tracks', () {
      final manifest = parseFriendManifest(jsonEncode({
        'app': 'muse',
        'version': 1,
        'name': 'Bob',
        'shareAll': false,
        'scopes': [
          {
            'type': 'playlist',
            'id': 'pl1',
            'label': 'Mix',
            'tracks': [
              {
                'id': '/a.mp3',
                'title': 'A',
                'artist': 'Art',
                'albumId': 'al1',
                'albumTitle': 'Album',
                'durationMs': 120000,
              },
              {'id': '/b.mp3', 'title': 'B', 'artist': 'Art2'},
            ],
          },
          {
            'type': 'album',
            'id': 'al1',
            'label': 'Album',
            'tracks': <Map<String, dynamic>>[],
          },
        ],
      }));

      expect(manifest.name, 'Bob');
      expect(manifest.shareAll, isFalse);
      expect(manifest.scopes.length, 2);

      final pl = manifest.scopes[0];
      expect(pl.type, ShareScopeType.playlist);
      expect(pl.id, 'pl1');
      expect(pl.label, 'Mix');
      expect(pl.tracks.length, 2);
      expect(pl.tracks[0].trackId, '/a.mp3');
      expect(pl.tracks[0].title, 'A');
      expect(pl.tracks[0].artist, 'Art');
      expect(pl.tracks[0].albumId, 'al1');
      expect(pl.tracks[0].albumTitle, 'Album');
      expect(pl.tracks[0].durationMs, 120000);
      expect(pl.tracks[1].artist, 'Art2');
      expect(pl.tracks[1].durationMs, 0);

      expect(manifest.scopes[1].type, ShareScopeType.album);
      expect(manifest.scopes[1].tracks, isEmpty);
    });

    test('reads the share-all flag', () {
      final manifest = parseFriendManifest(
        jsonEncode({'app': 'muse', 'shareAll': true, 'scopes': []}),
      );
      expect(manifest.shareAll, isTrue);
    });

    test('skips malformed scopes and tolerates missing fields', () {
      final manifest = parseFriendManifest(jsonEncode({
        'app': 'muse',
        'scopes': [
          'not-a-map',
          {'type': 'playlist', 'id': '', 'tracks': [42]},
          {
            'type': 'unknown',
            'id': 'x',
            'tracks': [
              {'id': '/t.mp3', 'title': 'T'},
            ],
          },
        ],
      }));

      expect(manifest.scopes.length, 1);
      expect(manifest.scopes[0].type, ShareScopeType.playlist);
      expect(manifest.scopes[0].id, 'x');
      expect(manifest.scopes[0].label, '');
      expect(manifest.scopes[0].tracks.length, 1);
      expect(manifest.scopes[0].tracks.first.title, 'T');
    });

    test('rejects a non-muse peer', () {
      expect(
        () => parseFriendManifest(jsonEncode({'app': 'spotify'})),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects invalid JSON', () {
      expect(
        () => parseFriendManifest('definitely not json'),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects an unexpected shape', () {
      expect(
        () => parseFriendManifest('[1, 2, 3]'),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('fetchFriendManifest', () {
    test('fetches and parses through the SOCKS proxy', () async {
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

      final proxy = FakeSocksProxy();
      final proxyPort = await proxy.start();
      addTearDown(proxy.close);

      final manifest = await fetchFriendManifest(
        socksPort: proxyPort,
        onion: _onion,
        targetPort: serverPort,
      );

      expect(proxy.lastRequestedHost, '$_onion.onion');
      expect(server.lastPath, '/manifest');
      expect(manifest.name, 'Bob');
      expect(manifest.scopes.single.tracks.single.title, 'A');
    });

    test('throws HttpException on a non-200 response', () async {
      final server = FakeManifestServer();
      final serverPort = await server.start();
      addTearDown(server.close);

      final proxy = FakeSocksProxy(forceTargetPort: serverPort);
      final proxyPort = await proxy.start();
      addTearDown(proxy.close);

      await expectLater(
        fetchFriendManifest(socksPort: proxyPort, onion: _onion),
        throwsA(isA<HttpException>()),
      );
    });
  });
}