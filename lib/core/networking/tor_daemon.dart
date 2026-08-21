import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'tor_service.dart';

/// Thin wrapper around a daemon [Process] so the lifecycle can be tested
/// without a real Tor binary.
abstract class TorProcess {
  Stream<List<int>> get stdout;
  Stream<List<int>> get stderr;
  Future<int> get exitCode;
  void kill([ProcessSignal signal = ProcessSignal.sigterm]);
}

class _RealTorProcess implements TorProcess {
  _RealTorProcess(this._process);

  final Process _process;

  @override
  Stream<List<int>> get stdout => _process.stdout;

  @override
  Stream<List<int>> get stderr => _process.stderr;

  @override
  Future<int> get exitCode => _process.exitCode;

  @override
  void kill([ProcessSignal signal = ProcessSignal.sigterm]) {
    _process.kill(signal);
  }
}

/// Starts a daemon process for a given binary + arguments.
typedef TorProcessStarter =
    Future<TorProcess> Function(String executable, List<String> arguments);

Future<TorProcess> _realStart(String executable, List<String> arguments) async {
  final process = await Process.start(executable, arguments);
  return _RealTorProcess(process);
}

/// Finds and manages the bundled Tor daemon process.
///
/// Configures Tor to run a SOCKS proxy on [socksPort] and a hidden service
/// whose port 80 maps to [sharePort] on loopback (the ShareServer). The onion
/// address is read from the hidden service's `hostname` file.
class TorDaemon implements TorService {
  TorDaemon({
    required this.binaryPath,
    required this.dataDir,
    required this.sharePort,
    this.socksPort = 19050,
    this.hostnamePollInterval = const Duration(seconds: 1),
    this.hostnameTimeout = const Duration(seconds: 60),
    @visibleForTesting TorProcessStarter? processStarter,
  }) : _starter = processStarter ?? _realStart;

  final String binaryPath;
  final Directory dataDir;
  final int sharePort;

  /// See [TorService.socksPort].
  @override
  final int socksPort;

  final Duration hostnamePollInterval;
  final Duration hostnameTimeout;

  final TorProcessStarter _starter;

  TorProcess? _process;
  String? _onion;
  bool _stopping = false;

  /// Recent daemon log lines, for diagnostics.
  final List<String> log = [];

  @override
  bool get isRunning => _process != null;

  @override
  String? get onion => _onion;

  @override
  Future<String> onionAddress() async {
    final onion = _onion;
    if (onion != null) return onion;
    if (_process == null) {
      throw StateError('Tor is not running');
    }
    _onion = await _waitForHostname(_hiddenServiceDir);
    return _onion!;
  }

  @override
  Future<void> start() async {
    if (_process != null) return;
    _stopping = false;
    await dataDir.create(recursive: true);

    final torrc = await _writeTorrc();
    final process = await _starter(binaryPath, ['-f', torrc.path]);
    _process = process;
    unawaited(_monitor(process));

    _onion = await _waitForHostname(_hiddenServiceDir);
  }

  @override
  Future<void> stop() async {
    _stopping = true;
    final process = _process;
    _process = null;
    if (process == null) return;
    process.kill(ProcessSignal.sigterm);
    try {
      await process.exitCode.timeout(const Duration(seconds: 5));
    } on TimeoutException {
      process.kill(ProcessSignal.sigkill);
      await process.exitCode;
    }
    _onion = null;
  }

  Directory get _hiddenServiceDir =>
      Directory('${dataDir.path}${Platform.pathSeparator}hidden_service');

  Future<File> _writeTorrc() async {
    final path = dataDir.path.replaceAll('\\', '/');
    final torrc = File('$path/torrc');
    await torrc.writeAsString([
      'DataDirectory $path',
      'SocksPort $socksPort',
      'Log notice stdout',
      'HiddenServiceDir $path/hidden_service',
      'HiddenServicePort 80 127.0.0.1:$sharePort',
    ].join('\n'));
    return torrc;
  }

  Future<String> _waitForHostname(Directory hiddenServiceDir) async {
    final hostnameFile =
        File('${hiddenServiceDir.path}${Platform.pathSeparator}hostname');
    final deadline = DateTime.now().add(hostnameTimeout);
    while (DateTime.now().isBefore(deadline)) {
      if (_process == null) {
        throw StateError('Tor exited before publishing an onion address');
      }
      if (await hostnameFile.exists()) {
        final content = (await hostnameFile.readAsString()).trim();
        final onion = content
            .replaceAll('.onion', '')
            .replaceAll(RegExp(r'\s'), '');
        if (onion.length == 56) return onion;
      }
      await Future<void>.delayed(hostnamePollInterval);
    }
    throw StateError('Timed out waiting for Tor onion address');
  }

  Future<void> _monitor(TorProcess process) async {
    process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) => _appendLog(line));
    process.stderr
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) => _appendLog(line));
    final code = await process.exitCode;
    if (!_stopping && _process == process) {
      _process = null;
      _appendLog('Tor exited unexpectedly (code $code)');
    }
  }

  void _appendLog(String line) {
    log.add(line);
    if (log.length > 500) log.removeRange(0, log.length - 500);
  }
}