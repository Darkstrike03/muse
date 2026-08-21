import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/storage/muse_db.dart';
import '../../shared/models/friend.dart';
import '../playlist/playlists_provider.dart';

/// The friend list — the app's only discovery surface. Friends are added by
/// scanning/typing a device code; there is no public directory.
final friendsProvider =
    AsyncNotifierProvider<Friends, List<Friend>>(Friends.new);

class Friends extends AsyncNotifier<List<Friend>> {
  @override
  Future<List<Friend>> build() async {
    final db = await ref.watch(museDbProvider);
    return db.getFriends();
  }

  Future<void> add(String onion, String name) async {
    final trimmedName = name.trim().isEmpty ? 'Friend' : name.trim();
    final db = await ref.read(museDbProvider);
    await db.insertFriend(onion, trimmedName);
    await _reload();
  }

  Future<void> remove(String onion) async {
    final db = await ref.read(museDbProvider);
    await db.deleteFriend(onion);
    await db.removeFriendContent(onion);
    ref.invalidate(playlistsProvider);
    await _reload();
  }

  Future<String?> nameFor(String? onion) async {
    if (onion == null) return null;
    final db = await ref.read(museDbProvider);
    return (await db.getFriend(onion))?.name;
  }

  Future<void> _reload() async {
    final db = await ref.read(museDbProvider);
    state = AsyncData(await db.getFriends());
  }
}

/// Maps onion → display name for the current friend list. Falls back to the
/// onion's short form when a friend isn't known (shouldn't normally happen).
String friendDisplayName(Friend? friend, String? onion) {
  if (friend != null) return friend.name;
  if (onion == null || onion.isEmpty) return 'Unknown';
  return onion.length > 12
      ? '${onion.substring(0, 6)}…${onion.substring(onion.length - 4)}'
      : onion;
}