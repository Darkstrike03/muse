import 'dart:convert';
import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;

import '../../shared/models/shared_scope.dart';
import '../../shared/models/track.dart';
import 'share_resolver.dart';

/// Port the local share server listens on. It must match the target of the Tor
/// daemon's `HiddenServicePort 80`, so it is fixed rather than ephemeral.
const int shareServerPort = 42800;

/// The local HTTP server exposed to friends through a Tor onion service.
///
/// Bound to 127.0.0.1; the Tor daemon's `HiddenServicePort 80` maps an onion
/// address onto it. Routes:
///
///   GET /health                 → liveness + identity
///   GET /manifest               → everything currently shared
///   GET `/manifest/<type>/<id>` → one scope (playlist/album/folder/all)
///   GET `/song/<id>`            → song bytes, HTTP Range supported
class ShareServer {
  ShareServer._(this._server);

  final HttpServer _server;

  int get port => _server.port;

  static Future<ShareServer> start({
    required int port,
    required ShareResolver resolver,
  }) async {
    final router = Router()
      ..get('/health', (Request request) => _health(resolver))
      ..get('/manifest', (Request request) => _manifest(resolver))
      ..get('/manifest/<scopeType>/<id>',
          (Request request, String scopeType, String id) {
        return _scopeManifest(resolver, scopeType, _decode(id));
      })
      ..get('/song/<id>', (Request request, String id) {
        return _song(request, resolver, _decode(id));
      });
    final handler = const Pipeline().addHandler(router.call);
    final server =
        await shelf_io.serve(handler, InternetAddress.loopbackIPv4, port);
    return ShareServer._(server);
  }

  Future<void> close() => _server.close(force: true);

  static Response _health(ShareResolver resolver) {
    return _json({
      'ok': true,
      'app': 'muse',
      'name': resolver.deviceName,
      'onion': resolver.onion,
    });
  }

  static Response _manifest(ShareResolver resolver) {
    final shareAll = resolver.isShareAll();
    final scopes = <Map<String, Object?>>[];
    if (shareAll) {
      scopes.add(_scopeJson(
        const SharedScope(
          type: ShareScopeType.folder,
          id: '__all__',
          label: 'Entire library',
        ),
        resolver.allTracks(),
      ));
    }
    for (final scope in resolver.sharedScopes()) {
      scopes.add(_scopeJson(scope, resolver.scopeTracks(scope)));
    }
    return _json({
      'app': 'muse',
      'version': 1,
      'onion': resolver.onion,
      'name': resolver.deviceName,
      'shareAll': shareAll,
      'scopes': scopes,
    });
  }

  static Response _scopeManifest(
    ShareResolver resolver,
    String scopeType,
    String id,
  ) {
    final shareAll = resolver.isShareAll();
    if (scopeType == 'all') {
      if (!shareAll) return _forbidden('not shared');
      return _json(_scopeJson(
        const SharedScope(
          type: ShareScopeType.folder,
          id: '__all__',
          label: 'Entire library',
        ),
        resolver.allTracks(),
      ));
    }
    final type = SharedScope.typeFromKey(scopeType);
    SharedScope? scope;
    for (final candidate in resolver.sharedScopes()) {
      if (candidate.type == type && candidate.id == id) {
        scope = candidate;
        break;
      }
    }
    if (scope == null && !shareAll) return _forbidden('scope not shared');
    final target = scope ??
        SharedScope(
          type: type,
          id: id,
          label: type.name,
        );
    return _json(_scopeJson(target, resolver.scopeTracks(target)));
  }

  static Map<String, Object?> _scopeJson(SharedScope scope, List<Track> tracks) {
    return {
      'type': scope.typeKey,
      'id': scope.id,
      'label': scope.label,
      'tracks': [for (final t in tracks) trackJson(t)],
    };
  }

  static Response _song(Request request, ShareResolver resolver, String id) {
    if (!isSharedTrack(resolver, id)) return _forbidden('track not shared');
    final track = resolver.trackById(id);
    final filePath = track?.filePath;
    if (filePath == null) return Response.notFound('unknown track');
    final file = File(filePath);
    if (!file.existsSync()) return Response.notFound('file missing');

    final size = file.lengthSync();
    final range = _parseRange(request.headers['range'], size);
    if (range == null) {
      return Response.ok(
        file.openRead(),
        headers: {
          'content-length': '$size',
          'accept-ranges': 'bytes',
          'content-type': 'application/octet-stream',
        },
      );
    }
    final (start, end) = range;
    final length = end - start + 1;
    return Response(
      206,
      body: file.openRead(start, end + 1),
      headers: {
        'content-length': '$length',
        'content-range': 'bytes $start-$end/$size',
        'accept-ranges': 'bytes',
        'content-type': 'application/octet-stream',
      },
    );
  }

  static Response _json(Map<String, Object?> body) {
    return Response.ok(
      jsonEncode(body),
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
  }

  static Response _forbidden(String reason) {
    return Response(403, body: jsonEncode({'error': reason}));
  }

  static String _decode(String segment) => Uri.decodeComponent(segment);

  static (int, int)? _parseRange(String? header, int size) {
    if (header == null || size <= 0) return null;
    final match = RegExp(r'^bytes=(\d*)-(\d*)$').firstMatch(header.trim());
    if (match == null) return null;
    final startStr = match.group(1)!;
    final endStr = match.group(2)!;
    if (startStr.isEmpty) {
      // Suffix range: last N bytes.
      final suffix = int.parse(endStr);
      final start = size - suffix;
      return start < 0 ? (0, size - 1) : (start, size - 1);
    }
    var start = int.parse(startStr);
    if (start >= size) return null;
    var end = endStr.isEmpty ? size - 1 : int.parse(endStr);
    if (end >= size) end = size - 1;
    return (start, end);
  }
}