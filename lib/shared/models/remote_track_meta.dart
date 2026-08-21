/// Metadata of a single track as served by a friend's `/manifest` — the cache
/// row backing the `remote_tracks` table.
class RemoteTrackMeta {
  const RemoteTrackMeta({
    required this.trackId,
    required this.title,
    required this.artist,
    required this.albumId,
    this.albumTitle = '',
    this.durationMs = 0,
  });

  final String trackId;
  final String title;
  final String artist;
  final String albumId;
  final String albumTitle;
  final int durationMs;
}