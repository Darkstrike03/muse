import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'socket_reader.dart';

/// A tunnelled connection: the raw [socket] plus the [reader] that was used for
/// the handshake. The reader must be kept alive (and used) for all further I/O
/// on this connection, because a dart:io Socket stream can only be listened to
/// once.
class SocksTunnel {
  const SocksTunnel({required this.socket, required this.reader});

  final Socket socket;
  final SocketReader reader;
}

/// Establishes a TCP connection to [targetHost]:[targetPort] through a SOCKS5
/// proxy at [proxyHost]:[proxyPort] (e.g. a local Tor daemon's SocksPort).
///
/// Onion addresses are sent as SOCKS5 domain names with a `.onion` suffix
/// appended when missing.
Future<SocksTunnel> connectViaSocks5({
  required String proxyHost,
  required int proxyPort,
  required String targetHost,
  required int targetPort,
  String? username,
  String? password,
}) async {
  final socket = await Socket.connect(
    proxyHost,
    proxyPort,
    timeout: const Duration(seconds: 30),
  );
  final reader = SocketReader(socket);
  try {
    // Greeting: version 5, offering no-auth and (when credentials given)
    // username/password.
    final methods = <int>[0x00];
    if (username != null) methods.add(0x02);
    socket.add([0x05, methods.length, ...methods]);
    await socket.flush();

    final selection = await reader.read(2);
    if (selection[0] != 0x05) {
      throw const SocketException('proxy replied with a non-SOCKS5 version');
    }
    if (selection[1] == 0x02) {
      final uname = utf8.encode(username ?? '');
      final pass = utf8.encode(password ?? '');
      socket.add([0x01, uname.length, ...uname, pass.length, ...pass]);
      await socket.flush();
      final auth = await reader.read(2);
      if (auth[0] != 0x01 || auth[1] != 0x00) {
        throw const SocketException('SOCKS5 username/password auth failed');
      }
    } else if (selection[1] != 0x00) {
      throw const SocketException('SOCKS5 proxy requires an unknown auth method');
    }

    // CONNECT request.
    final domain = targetHost.endsWith('.onion') ? targetHost : '$targetHost.onion';
    final domainBytes = utf8.encode(domain);
    socket.add(<int>[
      0x05, // version
      0x01, // CONNECT
      0x00, // reserved
      0x03, // domain name
      domainBytes.length, ...domainBytes,
      targetPort >> 8, targetPort & 0xff,
    ]);
    await socket.flush();

    // Reply header: [ver, rep, rsv, atyp].
    final header = await reader.read(4);
    if (header[0] != 0x05) {
      throw const SocketException('proxy replied with a non-SOCKS5 version');
    }
    if (header[1] != 0x00) {
      throw SocketException(
        'SOCKS5 connect to $domain:$targetPort failed (reply ${header[1]})',
      );
    }
    final atyp = header[3];
    if (atyp == 0x01) {
      await reader.read(4 + 2); // IPv4 + port
    } else if (atyp == 0x03) {
      final length = (await reader.read(1))[0];
      await reader.read(length + 2); // domain + port
    } else if (atyp == 0x04) {
      await reader.read(16 + 2); // IPv6 + port
    } else {
      throw SocketException('SOCKS5 reply used unknown address type $atyp');
    }

    // No more control traffic expected: hand the connection to the caller with
    // the reader that will carry all subsequent I/O.
    return SocksTunnel(socket: socket, reader: reader);
  } catch (_) {
    reader.close();
    socket.destroy();
    rethrow;
  }
}