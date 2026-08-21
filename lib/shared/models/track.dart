/// A single playable track in the local library.
///
/// Local tracks carry [filePath]. Remote tracks (streamed from a friend) leave
/// [filePath] null, use [remoteOwner] (the friend's onion address) and
/// [remoteTrackId] (the track id as known on that device), and have a composite
/// [id] of the form `remote:<onion>:<trackId>`.
class Track {
  const Track({
    required this.id,
    required this.title,
    required this.artist,
    required this.albumId,
    this.albumTitle = '',
    this.filePath,
    this.duration = const Duration(seconds: 0),
    this.remoteOwner,
    this.remoteTrackId,
  });

  final String id;
  final String title;
  final String artist;

  /// Grouping key for the album this track belongs to. Untagged tracks are
  /// grouped by their source folder path; tagged tracks by the album name.
  final String albumId;

  /// Human-readable album title (tag value or folder basename).
  final String albumTitle;

  final String? filePath;
  final Duration duration;

  /// Onion address of the friend this track is streamed from, when remote.
  final String? remoteOwner;

  /// The track's id as known on the owner device, when remote.
  final String? remoteTrackId;

  bool get isRemote => remoteOwner != null;
}
