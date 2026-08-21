import 'dart:async';
import 'dart:io';

import 'socks5_client.dart';
import 'tor_http.dart';

/// A live download of one remote track into a growing cache file.
///
/// The file [filePath] is written as bytes arrive, so a media player can open
/// it before the download finishes (the cache *is* the buffer). [ready]
/// completes once at least [minPlaybackBytes] are on disk (or the download
/// finishes first); [done] completes when the song is fully downloaded or the
/// connection ends. [progress] emits the fraction downloaded (or null when the
/// total size is unknown). [cancel] tears the session down, keeping partial
/// data so a later resume can continue from where it stopped.
class RemoteStream {
  RemoteStream._({
    required this.trackId,
    required this.filePath,
    required this.minPlaybackBytes,
    required this.progress,
    required this.ready,
    required this.done,
    required this.cancel,
    required double? Function() progressValue,
  }) : _progressValue = progressValue;

  final String trackId;
  final String filePath;
  final int minPlaybackBytes;

  final double? Function() _progressValue;

  /// Latest emitted fraction (0..1); null until any bytes have landed.
  double? get currentProgress => _progressValue();

  /// Broadcast: multiple consumers (the player, download buttons) can listen.
  final Stream<double?> progress;

  /// Completes (or errors) once enough bytes are on disk to start playback.
  final Future<void> ready;

  /// Completes when the file is fully cached; errors when the transfer fails
  /// or is cancelled mid-way.
  final Future<void> done;

  final Future<void> Function() cancel;
}

/// Mutable progress cell shared between the stream's getter and the download
/// loop, so `emit` doesn't need a reference to the not-yet-created stream.
class _Progress {
  _Progress(this.value);

  double? value;
}

/// Starts downloading [remoteTrackId] from [onion] (through the SOCKS5 proxy at
/// [proxyHost]:[socksPort]) into [target], resuming any existing partial file.
/// Returns immediately; the transfer runs in the background and reports through
/// the returned stream's [RemoteStream.progress]/[RemoteStream.ready]/
/// [RemoteStream.done].
///
/// [onBytes] fires as bytes land (throttled internally) so the caller can
/// persist progress; the final call reports the completed size.
///
/// [tunnelOverride] is a test seam: an already-established tunnel is used
/// instead of opening a fresh SOCKS5 connection.
Future<RemoteStream> startRemoteStream({
  required int socksPort,
  required String onion,
  required String remoteTrackId,
  required String trackId,
  required File target,
  required int minPlaybackBytes,
  void Function(int sizeBytes, bool complete)? onBytes,
  String proxyHost = '127.0.0.1',
  int targetPort = 80,
  SocksTunnel? tunnelOverride,
}) async {
  final progressController = StreamController<double?>.broadcast();
  final readyCompleter = Completer<void>();
  final doneCompleter = Completer<void>();

  var finished = false;
  var cancelled = false;
  SocksTunnel? tunnel;
  IOSink? sink;
  final progress = _Progress(0.0);
  Future<void>? runFuture;

  void emit(double value) {
    progress.value = value;
    if (!progressController.isClosed) progressController.add(value);
  }

  void finish([Object? error]) {
    if (finished) return;
    finished = true;
    if (error != null && !cancelled) {
      if (!doneCompleter.isCompleted) doneCompleter.completeError(error);
      if (!readyCompleter.isCompleted) readyCompleter.completeError(error);
    } else {
      if (!doneCompleter.isCompleted) doneCompleter.complete();
      if (!readyCompleter.isCompleted) readyCompleter.complete();
    }
    if (!progressController.isClosed) progressController.close();
  }

  late final RemoteStream stream;
  stream = RemoteStream._(
    trackId: trackId,
    filePath: target.path,
    minPlaybackBytes: minPlaybackBytes,
    progressValue: () => progress.value,
    progress: progressController.stream,
    ready: readyCompleter.future,
    done: doneCompleter.future,
    cancel: () async {
      if (finished) return;
      cancelled = true;
      tunnel?.socket.destroy();
      try {
        await doneCompleter.future;
      } catch (_) {
        // Cancellation is intentional; swallow the resulting socket error.
      }
      final pending = runFuture;
      if (pending != null) await pending.catchError((_) {});
    },
  );

  Future<void> cleanup() async {
    try {
      await sink?.close();
    } catch (_) {
      // ignore
    }
    sink = null;
    tunnel?.socket.destroy();
    tunnel = null;
  }

  Future<void> run() async {
    try {
      final t = tunnelOverride ??
          await connectViaSocks5(
            proxyHost: proxyHost,
            proxyPort: socksPort,
            targetHost: onion,
            targetPort: targetPort,
          );
      tunnel = t;

      final existingSize = await target.length().catchError((_) => 0);
      final resumeFrom = existingSize > 0 ? existingSize : 0;

      final response = await fetchOverSocketStreamed(
        t.reader,
        host: '$onion.onion',
        path: '/song/${Uri.encodeComponent(remoteTrackId)}',
        rangeHeader: resumeFrom > 0 ? 'bytes=$resumeFrom-' : null,
      );
      if (response.statusCode != 200 && response.statusCode != 206) {
        throw HttpException(
          'song request for $remoteTrackId failed '
          '(status ${response.statusCode})',
        );
      }

      final startOffset = response.statusCode == 200 ? 0 : resumeFrom;

      int? total;
      final contentRange = response.headers['content-range'];
      if (contentRange != null) {
        final match =
            RegExp(r'^bytes \d+-\d+/(\d+)$').firstMatch(contentRange);
        if (match != null) total = int.parse(match.group(1)!);
      } else if (response.statusCode == 200) {
        total = int.tryParse(response.headers['content-length'] ?? '');
      }

      final s = target.openWrite(
        mode: startOffset > 0 ? FileMode.append : FileMode.write,
      );
      sink = s;

      var written = startOffset;
      var lastReported = startOffset;

      await for (final chunk in response.body) {
        s.add(chunk);
        await s.flush();
        written += chunk.length;

        if (written - lastReported >= 256 * 1024) {
          lastReported = written;
          if (total != null && total > 0) {
            emit((written / total).clamp(0.0, 1.0));
          }
          onBytes?.call(written, false);
        }
        if (!readyCompleter.isCompleted &&
            written - startOffset >= minPlaybackBytes) {
          readyCompleter.complete();
        }
        if (total != null && written >= total) break;
      }

      await s.close();
      sink = null;

      if (total != null && written < total) {
        throw const SocketException('download interrupted before completion');
      }
      emit(total == null || total <= 0
          ? 1.0
          : (written / total).clamp(0.0, 1.0));
      onBytes?.call(written, true);
      finish();
    } catch (error) {
      finish(error);
    } finally {
      await cleanup();
    }
  }

  runFuture = run();
  return stream;
}