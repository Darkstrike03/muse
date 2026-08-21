import '../../shared/models/shared_scope.dart';
import '../../shared/models/track.dart';

/// Supplies the metadata and bytes the share server serves, decoupled from
/// riverpod so the server logic is unit-testable. The provider wiring builds
/// one of these from live provider state; each field is read per-request so
/// sharing changes apply immediately.
class ShareResolver {
  const ShareResolver({
    required this.onion,
    required this.deviceName,
    required this.isShareAll,
    required this.sharedScopes,
    required this.allTracks,
    required this.scopeTracks,
    required this.trackById,
  });

  final String onion;
  final String deviceName;

  /// Whether "share all" is currently enabled.
  final bool Function() isShareAll;

  /// Explicitly shared scopes (playlists, albums, folders).
  final List<SharedScope> Function() sharedScopes;

  /// Every library track (used for the share-all manifest).
  final List<Track> Function() allTracks;

  /// The tracks of a specific scope.
  final List<Track> Function(SharedScope scope) scopeTracks;

  /// Resolves a track by its local id (file path).
  final Track? Function(String id) trackById;
}

/// Whether [trackId] is currently covered by this device's sharing config.
bool isSharedTrack(ShareResolver resolver, String trackId) {
  if (resolver.isShareAll()) return true;
  return resolver.sharedScopes().any(
        (scope) => resolver.scopeTracks(scope).any((t) => t.id == trackId),
      );
}

Map<String, Object?> trackJson(Track track) => {
      'id': track.id,
      'title': track.title,
      'artist': track.artist,
      'albumId': track.albumId,
      'albumTitle': track.albumTitle,
      'durationMs': track.duration.inMilliseconds,
    };