import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../stream/tor_controller_provider.dart';

/// The device's stable identity: the real Tor onion address once the daemon is
/// running, otherwise a locally generated placeholder with the same shape
/// (56 base32 chars) so pairing/QR flows work even before Tor is up.
final deviceIdProvider = FutureProvider<String>((ref) async {
  final tor = ref.watch(torControllerProvider).value;
  final realOnion = tor?.onion;
  if (realOnion != null && realOnion.isNotEmpty) return realOnion;

  final prefs = await SharedPreferences.getInstance();
  final existing = prefs.getString('device_id');
  if (existing != null && existing.isNotEmpty) return existing;
  final id = _generateOnionLikeId();
  await prefs.setString('device_id', id);
  return id;
});

/// The user-facing handle shown to friends (analogous to a name on a profile).
final deviceNameProvider =
    AsyncNotifierProvider<DeviceName, String>(DeviceName.new);

class DeviceName extends AsyncNotifier<String> {
  static const _key = 'device_name';

  @override
  Future<String> build() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_key) ?? 'My Muse';
  }

  Future<void> rename(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, trimmed);
    state = AsyncData(trimmed);
  }
}

String _generateOnionLikeId() {
  const alphabet = 'abcdefghijklmnopqrstuvwxyz234567'; // base32
  final random = Random.secure();
  return List.generate(56, (_) => alphabet[random.nextInt(alphabet.length)])
      .join();
}