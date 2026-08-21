import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/storage/muse_db.dart';
import '../../shared/models/shared_scope.dart';

/// What this device shares with its friends. Opt-in: nothing is shared until
/// the user toggles "share all" or adds an explicit scope.
final sharingProvider =
    AsyncNotifierProvider<Sharing, SharingConfig>(Sharing.new);

class Sharing extends AsyncNotifier<SharingConfig> {
  @override
  Future<SharingConfig> build() async {
    final db = await ref.watch(museDbProvider);
    final shareAll = await db.getShareAll();
    final scopes = await db.getSharedScopes();
    return SharingConfig(shareAll: shareAll, scopes: scopes);
  }

  Future<void> setShareAll(bool value) async {
    final db = await ref.read(museDbProvider);
    await db.setShareAll(value);
    await _reload();
  }

  Future<void> addScope(SharedScope scope) async {
    final db = await ref.read(museDbProvider);
    await db.insertSharedScope(scope);
    await _reload();
  }

  Future<void> removeScope(ShareScopeType type, String id) async {
    final db = await ref.read(museDbProvider);
    await db.deleteSharedScope(type, id);
    await _reload();
  }

  Future<void> toggleScope(SharedScope scope) async {
    final current = state.value;
    final exists = current?.scopes.any(
      (s) => s.type == scope.type && s.id == scope.id,
    ) ??
        false;
    if (exists) {
      await removeScope(scope.type, scope.id);
    } else {
      await addScope(scope);
    }
  }

  Future<void> _reload() async {
    final db = await ref.read(museDbProvider);
    final shareAll = await db.getShareAll();
    final scopes = await db.getSharedScopes();
    state = AsyncData(SharingConfig(shareAll: shareAll, scopes: scopes));
  }
}

/// Whether a specific scope is currently shared (explicitly, or via share-all).
bool isScopeShared(SharingConfig? config, ShareScopeType type, String id) {
  if (config == null) return false;
  if (config.shareAll) return true;
  return config.scopes.any((s) => s.type == type && s.id == id);
}