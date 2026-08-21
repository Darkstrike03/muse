import 'dart:convert';
import 'dart:io';

import '../../core/networking/socks5_client.dart';
import '../../core/networking/tor_http.dart';
import '../../shared/models/remote_track_meta.dart';
import '../../shared/models/shared_scope.dart';

/// Everything a friend currently shares, parsed from their `/manifest`.
class FriendManifest {
  const FriendManifest({
    required this.name,
    required this.shareAll,
    required this.scopes,
  });

  final String name;
  final bool shareAll;
  final List<FriendScope> scopes;
}

/// One shared scope (playlist/album/folder/entire-library) with its tracks.
class FriendScope {
  const FriendScope({
    required this.type,
    required this.id,
    required this.label,
    required this.tracks,
  });

  final ShareScopeType type;
  final String id;
  final String label;
  final List<RemoteTrackMeta> tracks;
}

/// Parses the JSON body of a friend's `/manifest`. Lenient about missing
/// fields so a partially-shared library still imports.
FriendManifest parseFriendManifest(String body) {
  final Object? decoded;
  try {
    decoded = jsonDecode(body);
  } on FormatException {
    throw const FormatException('Friend manifest is not valid JSON');
  }
  if (decoded is! Map<String, dynamic>) {
    throw const FormatException('Friend manifest has an unexpected shape');
  }
  if (decoded['app'] != 'muse') {
    throw FormatException('Not a Muse peer (${decoded['app']})');
  }

  final scopes = <FriendScope>[];
  for (final entry in (decoded['scopes'] as List<dynamic>? ?? const [])) {
    if (entry is! Map<String, dynamic>) continue;
    final type = SharedScope.typeFromKey(entry['type'] as String? ?? '');
    final id = entry['id'] as String? ?? '';
    if (id.isEmpty) continue;
    scopes.add(FriendScope(
      type: type,
      id: id,
      label: entry['label'] as String? ?? '',
      tracks: [
        for (final track in (entry['tracks'] as List<dynamic>? ?? const []))
          _trackMeta(track),
      ],
    ));
  }

  return FriendManifest(
    name: decoded['name'] as String? ?? '',
    shareAll: decoded['shareAll'] as bool? ?? false,
    scopes: scopes,
  );
}

RemoteTrackMeta _trackMeta(dynamic value) {
  if (value is! Map<String, dynamic>) {
    return const RemoteTrackMeta(
      trackId: '',
      title: '',
      artist: '',
      albumId: '',
    );
  }
  return RemoteTrackMeta(
    trackId: value['id'] as String? ?? '',
    title: value['title'] as String? ?? '',
    artist: value['artist'] as String? ?? '',
    albumId: value['albumId'] as String? ?? '',
    albumTitle: value['albumTitle'] as String? ?? '',
    durationMs: (value['durationMs'] as num?)?.toInt() ?? 0,
  );
}

/// Fetches and parses a friend's `/manifest` through the local Tor SOCKS
/// proxy, mirroring [probeFriend]'s tunnel setup.
Future<FriendManifest> fetchFriendManifest({
  required int socksPort,
  required String onion,
  String proxyHost = '127.0.0.1',
  int targetPort = 80,
}) async {
  SocksTunnel? tunnel;
  try {
    tunnel = await connectViaSocks5(
      proxyHost: proxyHost,
      proxyPort: socksPort,
      targetHost: onion,
      targetPort: targetPort,
    );
    final response = await fetchOverSocket(
      tunnel.reader,
      host: '$onion.onion',
      path: '/manifest',
    );
    if (response.statusCode != 200) {
      throw HttpException(
        'Manifest request failed (HTTP ${response.statusCode})',
      );
    }
    return parseFriendManifest(response.bodyText);
  } finally {
    tunnel?.socket.destroy();
  }
}