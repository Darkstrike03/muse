/// What a device shares with its friends: either everything (shareAll) or a
/// specific list of scopes (playlists, albums/folders).
class SharingConfig {
  const SharingConfig({this.shareAll = false, this.scopes = const []});

  final bool shareAll;
  final List<SharedScope> scopes;

  SharingConfig copyWith({bool? shareAll, List<SharedScope>? scopes}) {
    return SharingConfig(
      shareAll: shareAll ?? this.shareAll,
      scopes: scopes ?? this.scopes,
    );
  }
}

enum ShareScopeType { playlist, album, folder }

class SharedScope {
  const SharedScope({
    required this.type,
    required this.id,
    this.label = '',
  });

  final ShareScopeType type;
  final String id;
  final String label;

  String get typeKey => type.name;

  static ShareScopeType typeFromKey(String key) {
    return ShareScopeType.values.firstWhere(
      (t) => t.name == key,
      orElse: () => ShareScopeType.playlist,
    );
  }
}
