import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:muse/core/networking/socks5_client.dart';
import 'package:muse/core/networking/tor_http.dart';

import 'support/fakes.dart';

void main() {
  final onion = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
  const host = '127.0.0.1';

  test('connects through a no-auth SOCKS5 proxy and fetches HTTP', () async {
    final http = FakeHttpTarget();
    final httpPort = await http.start();
    addTearDown(http.close);

    final proxy = FakeSocksProxy();
    final proxyPort = await proxy.start();
    addTearDown(proxy.close);

    final tunnel = await connectViaSocks5(
      proxyHost: host,
      proxyPort: proxyPort,
      targetHost: onion,
      targetPort: httpPort,
    );
    addTearDown(tunnel.socket.destroy);

    final response = await fetchOverSocket(
      tunnel.reader,
      host: '$onion.onion',
      path: '/manifest',
    );

    expect(response.statusCode, 200);
    expect(response.bodyText, contains('GET /manifest'));
    expect(proxy.lastRequestedHost, '$onion.onion');
    expect(proxy.lastRequestedPort, httpPort);
  });

  test('forwards a byte-range header', () async {
    final http = FakeHttpTarget();
    final httpPort = await http.start();
    addTearDown(http.close);

    final proxy = FakeSocksProxy();
    final proxyPort = await proxy.start();
    addTearDown(proxy.close);

    final tunnel = await connectViaSocks5(
      proxyHost: host,
      proxyPort: proxyPort,
      targetHost: onion,
      targetPort: httpPort,
    );
    addTearDown(tunnel.socket.destroy);

    final response = await fetchOverSocket(
      tunnel.reader,
      host: '$onion.onion',
      path: '/song/song1',
      range: [0, 1023],
    );

    expect(http.lastRange, 'Range: bytes=0-1023');
    expect(response.bodyText, contains('range=Range: bytes=0-1023'));
  });

  test('performs username/password auth when requested', () async {
    final http = FakeHttpTarget();
    final httpPort = await http.start();
    addTearDown(http.close);

    final proxy = FakeSocksProxy(requireAuth: true);
    final proxyPort = await proxy.start();
    addTearDown(proxy.close);

    final tunnel = await connectViaSocks5(
      proxyHost: host,
      proxyPort: proxyPort,
      targetHost: onion,
      targetPort: httpPort,
      username: 'user',
      password: 'pass',
    );
    addTearDown(tunnel.socket.destroy);

    final response = await fetchOverSocket(
      tunnel.reader,
      host: '$onion.onion',
      path: '/health',
    );
    expect(response.statusCode, 200);
  });

test('rejects a refused connection', () async {
    final proxy = FakeSocksProxy();
    final proxyPort = await proxy.start();
    addTearDown(proxy.close);

    await expectLater(
      connectViaSocks5(
        proxyHost: host,
        proxyPort: proxyPort,
        targetHost: onion,
        targetPort: 1, // nothing listening
      ),
      throwsA(isA<SocketException>()),
    );
  });

  test('throws when the proxy is unreachable', () async {
    await expectLater(
      connectViaSocks5(
        proxyHost: host,
        proxyPort: 1,
        targetHost: onion,
        targetPort: 80,
      ),
      throwsA(isA<SocketException>()),
    );
  });
}
