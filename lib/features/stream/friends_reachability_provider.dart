import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/networking/reachability.dart';
import '../pairing/friends_provider.dart';
import 'tor_controller_provider.dart';

/// The set of friend onion addresses currently reachable through Tor. Probed
/// on demand and every 30 seconds while watched (the Stream tab watches it).
final friendsReachabilityProvider =
    AsyncNotifierProvider<FriendsReachability, Set<String>>(
  FriendsReachability.new,
);

class FriendsReachability extends AsyncNotifier<Set<String>> {
  Timer? _timer;
  Future<void>? _inFlight;

  @override
  Future<Set<String>> build() async {
    ref.onDispose(() => _timer?.cancel());
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _refresh());
    ref.listen(friendsProvider, (_, _) => _refresh());
    ref.listen(torControllerProvider, (_, _) => _refresh());
    return _refresh();
  }

  Future<Set<String>> _refresh() async {
    final pending = _inFlight;
    if (pending != null) {
      await pending;
      return state.value ?? const {};
    }
    final future = _probe();
    _inFlight = future;
    try {
      return await future;
    } finally {
      _inFlight = null;
    }
  }

  Future<Set<String>> _probe() async {
    final tor = ref.read(torControllerProvider).value;
    final friends = ref.read(friendsProvider).value ?? const [];
    final reachable = <String>{};
    if (tor != null && friends.isNotEmpty) {
      for (final friend in friends) {
        final online =
            await probeFriend(socksPort: tor.socksPort, onion: friend.onion);
        if (online) reachable.add(friend.onion);
      }
    }
    state = AsyncData(reachable);
    return reachable;
  }
}

/// The set of friend onion addresses currently reachable. Derived from
/// [friendsReachabilityProvider] so the rest of the app (e.g. the availability
/// greying) reads one stable source; defaults to empty before the first probe.
final reachableFriendsProvider = Provider<Set<String>>(
  (ref) => ref.watch(friendsReachabilityProvider).value ?? const {},
);