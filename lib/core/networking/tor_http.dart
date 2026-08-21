import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'socket_reader.dart';

/// Result of an HTTP exchange carried over a raw socket (e.g. a SOCKS5 tunnel).
class HttpResponse {
  const HttpResponse({
    required this.statusCode,
    required this.headers,
    required this.body,
  });

  final int statusCode;

  /// Header names lower-cased for case-insensitive lookup.
  final Map<String, String> headers;

  final List<int> body;

  String get bodyText => utf8.decode(body, allowMalformed: true);
}

/// The head of a streamed HTTP response. [body] yields the payload in chunks
/// and completes when the declared length has been read or the connection
/// closes. The caller owns the socket (this helper never closes it).
class StreamedHttpResponse {
  const StreamedHttpResponse({
    required this.statusCode,
    required this.headers,
    required this.body,
  });

  final int statusCode;
  final Map<String, String> headers;
  final Stream<List<int>> body;
}

/// Minimal HTTP/1.1 client for fetching manifests and song bytes from a peer
/// over an already-established tunnel. No TLS, no redirects — peers are reached
/// through Tor, where TLS is unnecessary.
///
/// [reader] is the [SocketReader] from the SOCKS5 handshake; it owns the socket.
Future<HttpResponse> fetchOverSocket(
  SocketReader reader, {
  required String host,
  required String path,
  Map<String, String>? headers,
  List<int>? range,
}) async {
  final socket = reader.socket;
  final (statusCode, headerMap) = await _exchangeHead(
    socket,
    reader,
    host: host,
    path: path,
    headers: headers,
    rangeHeader: range == null ? null : 'bytes=${range.first}-${range.last}',
  );

  try {
    final contentLength = int.tryParse(headerMap['content-length'] ?? '');
    final body = contentLength == null
        ? await _readToEnd(reader)
        : await reader.read(contentLength);

    return HttpResponse(
      statusCode: statusCode,
      headers: headerMap,
      body: body,
    );
  } finally {
    reader.close();
    socket.destroy();
  }
}

/// Like [fetchOverSocket], but streams the payload instead of buffering it —
/// used for large song bodies. Does NOT close the socket: the caller keeps the
/// tunnel alive to read chunks, then destroys it when done or cancelled.
Future<StreamedHttpResponse> fetchOverSocketStreamed(
  SocketReader reader, {
  required String host,
  required String path,
  Map<String, String>? headers,
  String? rangeHeader,
}) async {
  final socket = reader.socket;
  final (statusCode, headerMap) = await _exchangeHead(
    socket,
    reader,
    host: host,
    path: path,
    headers: headers,
    rangeHeader: rangeHeader,
  );

  final contentLength = int.tryParse(headerMap['content-length'] ?? '');
  late final StreamController<List<int>> controller;

  Stream<List<int>> body() {
    controller = StreamController<List<int>>();
    unawaited(() async {
      try {
        var consumed = 0;
        while (contentLength == null || consumed < contentLength) {
          final chunk = await reader.readAvailable();
          if (chunk.isEmpty) break;
          consumed += chunk.length;
          if (controller.isClosed) return;
          controller.add(chunk);
        }
        await controller.close();
      } catch (error) {
        if (!controller.isClosed) {
          controller.addError(error);
          await controller.close();
        }
      }
    }());
    return controller.stream;
  }

  return StreamedHttpResponse(
    statusCode: statusCode,
    headers: headerMap,
    body: body(),
  );
}

Future<(int, Map<String, String>)> _exchangeHead(
  Socket socket,
  SocketReader reader, {
  required String host,
  required String path,
  Map<String, String>? headers,
  String? rangeHeader,
}) async {
  final requestHeaders = <String, String>{
    'Host': host,
    'Connection': 'close',
    'Range': ?rangeHeader,
    ...?headers,
  };
  final buffer = StringBuffer('GET $path HTTP/1.1\r\n');
  for (final entry in requestHeaders.entries) {
    buffer.write('${entry.key}: ${entry.value}\r\n');
  }
  buffer.write('\r\n');

  socket.add(utf8.encode(buffer.toString()));
  await socket.flush();

  final head = await reader.readUntil(_crlfCrlf);
  final headText = utf8.decode(head, allowMalformed: true);
  final lines = headText.split('\r\n');

  final statusLine = lines.first;
  final statusMatch =
      RegExp(r'^HTTP/1\.[01]\s+(\d{3})').firstMatch(statusLine);
  final statusCode = statusMatch == null ? 0 : int.parse(statusMatch.group(1)!);

  final headerMap = <String, String>{};
  for (final line in lines.skip(1)) {
    final colon = line.indexOf(':');
    if (colon <= 0) continue;
    headerMap[line.substring(0, colon).trim().toLowerCase()] =
        line.substring(colon + 1).trim();
  }

  return (statusCode, headerMap);
}

Future<List<int>> _readToEnd(SocketReader reader) async {
  final bytes = <int>[];
  try {
    while (true) {
      final chunk = await reader.read(1);
      if (chunk.isEmpty) break;
      bytes.addAll(chunk);
    }
  } on SocketException {
    // End of stream.
  }
  return bytes;
}

const _crlfCrlf = [13, 10, 13, 10];