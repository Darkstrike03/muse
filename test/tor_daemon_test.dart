import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:muse/core/networking/tor_daemon.dart';

final String _onion = 'a' * 56;

class _FakeTorProcess implements TorProcess {
  final _exit = Completer<int>();

  @override
  Stream<List<int>> get stdout => Stream<List<int>>.empty();

  @override
  Stream<List<int>> get stderr => Stream<List<int>>.empty();

  @override
  Future<int> get exitCode => _exit.future;

  @override
  void kill([ProcessSignal signal = ProcessSignal.sigterm]) {
    if (!_exit.isCompleted) _exit.complete(signal == ProcessSignal.sigkill ? 137 : 0);
  }
}

void main() {
  late Directory dataDir;

  setUp(() {
    dataDir = Directory.systemTemp.createTempSync('muse_tor_test');
  });

  tearDown(() {
    if (dataDir.existsSync()) dataDir.deleteSync(recursive: true);
  });

  TorDaemon buildDaemon({TorProcessStarter? starter}) {
    return TorDaemon(
      binaryPath: 'tor',
      dataDir: dataDir,
      sharePort: 42800,
      socksPort: 19050,
      hostnamePollInterval: const Duration(milliseconds: 5),
      hostnameTimeout: const Duration(seconds: 3),
      processStarter: starter,
    );
  }

  test('writes torrc and publishes the onion address from hostname file',
      () async {
    final fake = _FakeTorProcess();
    late List<String> args;
    final daemon = buildDaemon(starter: (exe, a) async {
      args = a;
      // Simulate Tor publishing its address after startup.
      final hs = Directory('${dataDir.path}${Platform.pathSeparator}hidden_service');
      await hs.create(recursive: true);
      await File('${hs.path}${Platform.pathSeparator}hostname')
          .writeAsString('$_onion.onion\n');
      return fake;
    });

    await daemon.start();

    expect(args, hasLength(2));
    expect(args[0], '-f');
    final torrc = File(args[1]);
    expect(await torrc.exists(), isTrue);
    final content = await torrc.readAsString();
    expect(content, contains('SocksPort 19050'));
    expect(content, contains('HiddenServicePort 80 127.0.0.1:42800'));

    expect(daemon.isRunning, isTrue);
    expect(await daemon.onionAddress(), _onion);

    await daemon.stop();
    expect(daemon.isRunning, isFalse);
  });

  test('start is idempotent', () async {
    var starts = 0;
    final daemon = buildDaemon(starter: (exe, a) async {
      starts++;
      final hs = Directory('${dataDir.path}${Platform.pathSeparator}hidden_service');
      await hs.create(recursive: true);
      await File('${hs.path}${Platform.pathSeparator}hostname')
          .writeAsString('$_onion.onion\n');
      return _FakeTorProcess();
    });

    await daemon.start();
    await daemon.start();
    expect(starts, 1);
    await daemon.stop();
  });

  test('throws when Tor exits before publishing an address', () async {
    final daemon = buildDaemon(starter: (exe, a) async {
      final fake = _FakeTorProcess();
      // No hostname file is ever written.
      return fake;
    });

    await expectLater(daemon.start(), throwsStateError);
  });
}