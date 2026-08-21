import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/networking/android_tor_service.dart';
import '../../core/networking/tor_daemon.dart';
import '../../core/networking/tor_runtime.dart';
import '../../core/networking/tor_service.dart';
import 'share_server.dart';

/// Owns the Tor lifecycle. `null` state means Tor is not running.
///
/// On Android, Tor runs through the Guardian `tor-android` foreground service;
/// on other platforms it requires a bundled binary (see `tool/setup_tor.ps1`).
final torControllerProvider =
    AsyncNotifierProvider<TorController, TorService?>(TorController.new);

class TorController extends AsyncNotifier<TorService?> {
  @override
  Future<TorService?> build() async => null;

  Future<void> start() async {
    if (state.value != null) return;
    state = const AsyncLoading();
    try {
      final TorService service;
      if (Platform.isAndroid) {
        service = AndroidTorService(sharePort: shareServerPort);
      } else {
        final binary = await findTorBinary();
        if (binary == null) {
          throw StateError(
            'Tor binary not found. Run tool/setup_tor.ps1 or set MUSE_TOR_DIR.',
          );
        }
        final support = await getApplicationSupportDirectory();
        final dataDir =
            Directory('${support.path}${Platform.pathSeparator}tor_data');
        service = TorDaemon(
          binaryPath: binary,
          dataDir: dataDir,
          sharePort: shareServerPort,
        );
      }
      await service.start();
      state = AsyncData(service);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  Future<void> stop() async {
    final service = state.value;
    if (service == null) return;
    await service.stop();
    state = AsyncData(null);
  }
}