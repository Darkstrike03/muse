import 'package:flutter/services.dart';

import 'tor_service.dart';

/// Tor on Android, backed by the Guardian Project `tor-android` service.
///
/// The native side writes a torrc (hidden service on [sharePort]), runs the
/// TorService inside a foreground service and reports the onion address plus
/// the SOCKS port back through the `muse/tor` method channel.
class AndroidTorService implements TorService {
  AndroidTorService({
    this.sharePort = 42800,
    MethodChannel? channel,
  }) : _channel = channel ?? const MethodChannel('muse/tor');

  /// Local port the hidden service forwards port 80 to (the ShareServer).
  final int sharePort;

  final MethodChannel _channel;

  String? _onion;
  int? _socksPort;

  @override
  bool get isRunning => _onion != null;

  @override
  int get socksPort => _socksPort ?? 0;

  @override
  String? get onion => _onion;

  @override
  Future<String> onionAddress() async {
    final onion = _onion;
    if (onion != null) return onion;
    throw StateError('Tor is not running');
  }

  @override
  Future<void> start() async {
    final result = await _channel.invokeMapMethod<String, Object>('start', {
      'sharePort': sharePort,
    });
    final onion = (result?['onion'] as String?)?.trim();
    final socksPort = result?['socksPort'] as int?;
    if (onion == null ||
        onion.replaceAll('.onion', '').length != 56 ||
        socksPort == null ||
        socksPort <= 0) {
      throw StateError('Tor failed to start on this device');
    }
    _onion = onion.replaceAll('.onion', '');
    _socksPort = socksPort;
  }

  @override
  Future<void> stop() async {
    _onion = null;
    _socksPort = null;
    await _channel.invokeMethod('stop');
  }
}