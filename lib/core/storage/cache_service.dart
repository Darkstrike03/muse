import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../networking/remote_stream.dart';
import 'muse_db.dart';

/// Owns the byte cache: per-track files in [root] plus the `cache` table index
/// in [db]. Also keeps track of in-flight downloads so repeated requests for
/// the same track share one transfer.
class CacheService {
  CacheService(this._db, this._root);

  final MuseDb _db;
  final Directory _root;

  final Map<String, RemoteStream> _active = {};
  final Map<String, Future<void>> _persistQueue = {};

  /// Stable per-track file name (composite ids contain `:` and `/`).
  String _fileName(String trackId) =>
      base64Url.encode(utf8.encode(trackId)).replaceAll('=', '');

  File fileFor(String trackId) => File(p.join(_root.path, _fileName(trackId)));

  Future<CacheEntry?> entry(String trackId) => _db.getCacheEntry(trackId);

  Future<List<CacheEntry>> list() => _db.getCacheEntries();

  Future<int> totalBytes() => _db.cacheTotalBytes();

  /// The transfer currently writing [trackId], if any.
  RemoteStream? activeStream(String trackId) => _active[trackId];

  /// Starts (or returns the already-active) download of [remoteTrackId] from
  /// [onion] into the per-track cache file, resuming any partial file.
  Future<RemoteStream> streamTrack({
    required String trackId,
    required String onion,
    required String remoteTrackId,
    required int socksPort,
    int targetPort = 80,
    int minPlaybackBytes = 256 * 1024,
  }) async {
    final existing = _active[trackId];
    if (existing != null) return existing;

    final file = fileFor(trackId);
    final stream = await startRemoteStream(
      socksPort: socksPort,
      onion: onion,
      remoteTrackId: remoteTrackId,
      trackId: trackId,
      target: file,
      targetPort: targetPort,
      minPlaybackBytes: minPlaybackBytes,
      onBytes: (sizeBytes, complete) =>
          _persist(trackId, file.path, sizeBytes, complete),
    );
    _active[trackId] = stream;
    // `ready`/`done` are awaited by callers that care; mark both handled so a
    // failed transfer is never reported as an unhandled async error.
    stream.ready.catchError((_) {});
    stream.done
        .whenComplete(() => _active.remove(trackId))
        .catchError((_) {});
    return stream;
  }

  Future<void> markPlayed(String trackId) =>
      _db.touchCache(trackId, DateTime.now().millisecondsSinceEpoch);

  /// Removes the bytes (and cancels any in-flight download) for [trackId].
  Future<void> remove(String trackId) async {
    final active = _active.remove(trackId);
    if (active != null) await active.cancel().catchError((_) {});
    await _db.deleteCacheEntry(trackId);
    final file = fileFor(trackId);
    if (await file.exists()) await file.delete();
  }

  /// Writes progress to the DB. Writes are serialized per track so a late
  /// partial write can never overwrite the final "complete" one.
  void _persist(String trackId, String filePath, int sizeBytes, bool complete) {
    final prev = _persistQueue[trackId] ?? Future.value();
    final next = prev.then((_) => _db.upsertCacheEntry(
          CacheEntry(
            trackId: trackId,
            filePath: filePath,
            sizeBytes: sizeBytes,
            complete: complete,
          ),
        ));
    _persistQueue[trackId] = next;
  }
}