import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:muse/core/networking/socket_reader.dart';

/// Minimal SOCKS5 proxy: accepts no-auth, forwards CONNECTs to a real target,
/// then pipes bytes. Records the requested host for assertions.
class FakeSocksProxy {
  FakeSocksProxy({this.requireAuth = false, this.forceTargetPort});

  final bool requireAuth;

  /// When set, CONNECTs are forwarded to this loopback port instead of the
  /// port in the request (handy for targets that live on an ephemeral port
  /// while the client asks for 80).
  final int? forceTargetPort;
  ServerSocket? _server;
  String? lastRequestedHost;
  int? lastRequestedPort;

  Future<int> start() async {
    _server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    _server!.listen(_handle);
    return _server!.port;
  }

  Future<void> close() async {
    await _server?.close();
  }

  Future<void> _handle(Socket socket) async {
    final reader = SocketReader(socket);
    try {
      final greeting = await reader.read(2);
      final methods = await reader.read(greeting[1]);
      if (requireAuth) {
        if (!methods.contains(0x02)) {
          socket.add([0x05, 0xff]);
          await socket.flush();
          return;
        }
        socket.add([0x05, 0x02]);
        await socket.flush();
        final auth = await reader.read(2);
        final uname = await reader.read(auth[1]);
        final passLen = (await reader.read(1))[0];
        final pass = await reader.read(passLen);
        final ok = utf8.decode(uname) == 'user' && utf8.decode(pass) == 'pass';
        socket.add([0x01, ok ? 0 : 1]);
        await socket.flush();
        if (!ok) return;
      } else {
        socket.add([0x05, 0x00]);
        await socket.flush();
      }

      final connect = await reader.read(4);
      int port;
      if (connect[3] == 0x03) {
        final length = (await reader.read(1))[0];
        final domain = utf8.decode(await reader.read(length));
        final portBytes = await reader.read(2);
        port = (portBytes[0] << 8) | portBytes[1];
        lastRequestedHost = domain;
        lastRequestedPort = port;
      } else {
        throw const SocketException('unexpected address type');
      }

      final target = await Socket.connect(
        InternetAddress.loopbackIPv4,
        forceTargetPort ?? port,
      );
      socket.add([0x05, 0x00, 0x00, 0x01, 0, 0, 0, 0, 0, 0]);
      await socket.flush();

      // client -> target: forward through the shared reader's subscription.
      unawaited(() async {
        try {
          while (true) {
            final chunk = await reader.readAvailable();
            if (chunk.isEmpty) break;
            target.add(chunk);
            await target.flush();
          }
        } catch (_) {
          // ignore
        }
        target.destroy();
      }());
      // target -> client: forward on the target's own listener.
      target.listen(
        (data) => socket.add(data),
        onDone: socket.destroy,
        onError: (_) => socket.destroy(),
      );
    } catch (_) {
      socket.destroy();
    }
  }
}

/// Minimal HTTP server that echoes the request's first line and Range header
/// inside the body, so tests can assert what the client actually sent.
class FakeHttpTarget {
  ServerSocket? _server;
  String? lastRequestLine;
  String? lastRange;

  Future<int> start() async {
    _server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    _server!.listen((socket) async {
      final reader = SocketReader(socket);
      try {
        final head = utf8.decode(
          await reader.readUntil([13, 10, 13, 10]),
          allowMalformed: true,
        );
        lastRequestLine = head.split('\r\n').first;
        final rangeHeader = head
            .split('\r\n')
            .where((l) => l.toLowerCase().startsWith('range:'))
            .join();
        lastRange = rangeHeader.isEmpty ? null : rangeHeader;
        final body = utf8.encode(
          'request=$lastRequestLine&range=${lastRange ?? 'none'}',
        );
        socket.add(utf8.encode('HTTP/1.1 200 OK\r\n'
            'Content-Type: text/plain\r\n'
            'Content-Length: ${body.length}\r\n'
            '\r\n'));
        socket.add(body);
        await socket.flush();
      } catch (_) {
        // ignore
      } finally {
        socket.destroy();
      }
    });
    return _server!.port;
  }

  Future<void> close() async {
    await _server?.close();
  }
}

/// Minimal HTTP server that serves a friend's `/manifest` JSON. Mutate
/// [manifest] between requests to simulate the friend's sharing changing.
class FakeManifestServer {
  FakeManifestServer({this.manifest});

  Map<String, dynamic>? manifest;
  ServerSocket? _server;
  String? lastPath;

  Future<int> start() async {
    _server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    _server!.listen((socket) async {
      final reader = SocketReader(socket);
      try {
        final head = utf8.decode(
          await reader.readUntil([13, 10, 13, 10]),
          allowMalformed: true,
        );
        lastPath = head.split('\r\n').first.split(' ').elementAt(1);
        final body = manifest == null ? const <int>[] : utf8.encode(jsonEncode(manifest));
        socket.add(utf8.encode('HTTP/1.1 ${manifest == null ? '404' : '200'} '
            '${manifest == null ? 'Not Found' : 'OK'}\r\n'
            'Content-Type: application/json\r\n'
            'Content-Length: ${body.length}\r\n'
            '\r\n'));
        socket.add(body);
        await socket.flush();
      } catch (_) {
        // ignore
      } finally {
        socket.destroy();
      }
    });
    return _server!.port;
  }

  Future<void> close() async {
    await _server?.close();
  }
}