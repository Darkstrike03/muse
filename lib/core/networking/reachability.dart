import 'dart:io';

import 'socks5_client.dart';
import 'tor_http.dart';

/// Opens a tunnel to a friend's onion service and probes its `/health`
/// endpoint. Returns true when the friend is online and serving.
Future<bool> probeFriend({
  required int socksPort,
  required String onion,
  String proxyHost = '127.0.0.1',
}) async {
  SocksTunnel? tunnel;
  try {
    tunnel = await connectViaSocks5(
      proxyHost: proxyHost,
      proxyPort: socksPort,
      targetHost: onion,
      targetPort: 80,
    );
    final response = await fetchOverSocket(
      tunnel.reader,
      host: '$onion.onion',
      path: '/health',
    );
    return response.statusCode == 200;
  } on SocketException {
    return false;
  } finally {
    tunnel?.socket.destroy();
  }
}