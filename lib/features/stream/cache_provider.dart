import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../core/storage/cache_service.dart';
import '../../core/storage/muse_db.dart';
import '../../shared/models/track.dart';
import 'tor_controller_provider.dart';

/// The app-support cache directory, created on first access.
final cacheDirectoryProvider = Provider<Future<Directory>>((ref) async {
  final support = await getApplicationSupportDirectory();
  final dir = Directory(p.join(support.path, 'cache'));
  await dir.create(recursive: true);
  return dir;
});

/// The byte cache (files + SQLite index) for remote tracks.
final cacheServiceProvider = Provider<Future<CacheService>>((ref) async {
  final db = await ref.watch(museDbProvider);
  final dir = await ref.watch(cacheDirectoryProvider);
  return CacheService(db, dir);
});

/// Whether a track's bytes are fully cached (offline-playable).
final cacheStateProvider = FutureProvider.family<bool, String>((ref, id) async {
  final db = await ref.watch(museDbProvider);
  final entry = await db.getCacheEntry(id);
  return entry?.complete ?? false;
});

/// Live cache progress (0..1, or null when unknown) for a track. Streams the
/// active download's progress while one runs; otherwise reflects the stored
/// entry (1.0 when complete, null when absent).
final cacheProgressProvider =
    StreamProvider.family<double?, String>((ref, id) async* {
  final service = await ref.watch(cacheServiceProvider);
  final active = service.activeStream(id);
  if (active != null) {
    yield active.currentProgress;
    await for (final value in active.progress) {
      yield value;
    }
  } else {
    final entry = await service.entry(id);
    yield entry == null ? null : (entry.complete ? 1.0 : null);
  }
});

/// Starts (or joins) a background download of [track] into the cache. Requires
/// Tor to be running (the track is greyed out otherwise). Refreshes cache
/// providers when the transfer finishes.
Future<void> downloadRemoteTrack(WidgetRef ref, Track track) async {
  final onion = track.remoteOwner;
  final remoteTrackId = track.remoteTrackId ?? track.id;
  final tor = ref.read(torControllerProvider).value;
  if (onion == null || remoteTrackId.isEmpty || tor == null) return;

  final service = await ref.read(cacheServiceProvider);
  await service.streamTrack(
    trackId: track.id,
    onion: onion,
    remoteTrackId: remoteTrackId,
    socksPort: tor.socksPort,
  );
  ref.invalidate(cacheProgressProvider(track.id));

  final active = service.activeStream(track.id);
  if (active != null) {
    active.done
        .whenComplete(() {
          ref.invalidate(cacheProgressProvider(track.id));
          ref.invalidate(cacheStateProvider(track.id));
        })
        .catchError((_) {});
  }
}

/// Deletes the cached bytes for a remote track and refreshes cache providers.
Future<void> removeCachedTrack(WidgetRef ref, String trackId) async {
  final service = await ref.read(cacheServiceProvider);
  await service.remove(trackId);
  ref.invalidate(cacheProgressProvider(trackId));
  ref.invalidate(cacheStateProvider(trackId));
}