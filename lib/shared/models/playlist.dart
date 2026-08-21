/// A playlist. Local playlists are created by the user; imported playlists are
/// mirror copies of a friend's shared scopes (identified by [ownerOnion]).
/// Tracks are referenced by [Track.id] (file path, or `remote:<onion>:<id>`)
/// and resolved against the library at view time.
class Playlist {
  const Playlist({
    required this.id,
    required this.name,
    this.imagePath,
    this.trackIds = const [],
    this.ownerOnion,
  });

  factory Playlist.fromJson(Map<String, dynamic> json) {
    return Playlist(
      id: json['id'] as String,
      name: json['name'] as String,
      imagePath: json['imagePath'] as String?,
      trackIds: (json['trackIds'] as List<dynamic>? ?? const [])
          .cast<String>(),
    );
  }

  final String id;
  final String name;
  final String? imagePath;
  final List<String> trackIds;

  /// The friend's onion address when this playlist mirrors one of their
  /// shared scopes; null for playlists the user created locally.
  final String? ownerOnion;

  bool get isRemote => ownerOnion != null;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'imagePath': imagePath,
        'trackIds': trackIds,
      };

  Playlist copyWith({
    String? name,
    String? imagePath,
    List<String>? trackIds,
  }) {
    return Playlist(
      id: id,
      name: name ?? this.name,
      imagePath: imagePath ?? this.imagePath,
      trackIds: trackIds ?? this.trackIds,
      ownerOnion: ownerOnion,
    );
  }
}