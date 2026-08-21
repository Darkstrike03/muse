import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart' hide Track;
import 'package:meta/meta.dart';

import '../../core/networking/remote_stream.dart';
import '../../shared/models/track.dart';
import '../library/library_provider.dart';
import '../stream/cache_provider.dart';
import '../stream/tor_controller_provider.dart';

/// Snapshot of the shared player state. Rebuilt on every position tick, so
/// widgets should `select()` the slices they care about.
class PlaybackState {
  const PlaybackState({
    this.queue = const [],
    this.currentIndex = -1,
    this.playing = false,
    this.shuffle = false,
    this.repeat = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.audioParams,
    this.sourceId,
    this.cacheProgress,
  });

  final List<Track> queue;
  final int currentIndex;
  final bool playing;
  final bool shuffle;
  final bool repeat;
  final Duration position;
  final Duration duration;

  /// Audio format reported by the decoder (codec/format, sample rate,
  /// channels). Feeds the quality inspector.
  final AudioParams? audioParams;

  /// The id of the context the current queue came from — a playlist id when
  /// the queue is scoped to a playlist, otherwise null (library-wide queue).
  final String? sourceId;

  /// Cache progress (0..1) of the currently streaming remote track; null when
  /// not streaming. Feeds the quality inspector's cache row.
  final double? cacheProgress;

  Track? get current =>
      (currentIndex >= 0 && currentIndex < queue.length)
          ? queue[currentIndex]
          : null;

  PlaybackState copyWith({
    List<Track>? queue,
    int? currentIndex,
    bool? playing,
    bool? shuffle,
    bool? repeat,
    Duration? position,
    Duration? duration,
    AudioParams? audioParams,
    Object? sourceId = _unset,
    Object? cacheProgress = _unset,
  }) {
    return PlaybackState(
      queue: queue ?? this.queue,
      currentIndex: currentIndex ?? this.currentIndex,
      playing: playing ?? this.playing,
      shuffle: shuffle ?? this.shuffle,
      repeat: repeat ?? this.repeat,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      audioParams: audioParams ?? this.audioParams,
      sourceId: identical(sourceId, _unset)
          ? this.sourceId
          : sourceId as String?,
      cacheProgress: identical(cacheProgress, _unset)
          ? this.cacheProgress
          : cacheProgress as double?,
    );
  }

  static const _unset = Object();
}

/// Single shared playback controller. Every surface (Home card, Now Playing,
/// queue, list rows) reads and drives this one player, so they stay in sync.
final playbackControllerProvider =
    NotifierProvider<PlaybackController, PlaybackState>(
  PlaybackController.new,
);

class PlaybackController extends Notifier<PlaybackState> {
  final Random _random = Random();

  // Lazily created: only touched once this notifier's build() runs, so tests
  // can subclass and skip the real engine.
  late final Player _player = Player();
  final List<StreamSubscription<dynamic>> _subs = [];

  /// The queue's order before shuffle was enabled, so shuffle can be undone.
  List<Track>? _savedQueue;

  /// Incremented by every playback request. Loads from older generations are
  /// discarded at each await, so the last tap always wins the player — without
  /// this, a slow remote load (SOCKS tunnel + buffering) finishing late would
  /// override a newer selection.
  int _generation = 0;

  /// The generation whose media is currently loaded in the player; lets
  /// [_onCompleted] ignore completions from superseded media.
  int _loadedGeneration = -1;

  /// Progress listener of the active remote stream, cancelled when another
  /// load supersedes it.
  StreamSubscription<double?>? _progressSub;

  @override
  PlaybackState build() {
    _subs
      ..add(_player.stream.position.listen(_onPosition))
      ..add(_player.stream.duration.listen(_onDuration))
      ..add(_player.stream.playing.listen(_onPlaying))
      ..add(_player.stream.audioParams.listen(_onAudioParams))
      ..add(_player.stream.completed.listen((_) => _onCompleted()));
    ref.onDispose(() {
      for (final sub in _subs) {
        sub.cancel();
      }
      _progressSub?.cancel();
      _player.dispose();
    });
    return const PlaybackState();
  }

  void _onPosition(Duration position) {
    if (ref.mounted) state = state.copyWith(position: position);
  }

  void _onDuration(Duration duration) {
    if (ref.mounted) state = state.copyWith(duration: duration);
  }

  void _onPlaying(bool playing) {
    if (ref.mounted) state = state.copyWith(playing: playing);
  }

  void _onAudioParams(AudioParams params) {
    if (ref.mounted) state = state.copyWith(audioParams: params);
  }

  void _onCompleted() {
    if (!ref.mounted) return;
    // Completions from superseded media fire while switching tracks; they
    // must not advance the queue.
    if (_loadedGeneration != _generation) return;
    if (shouldAutoAdvance(position: state.position, duration: state.duration)) {
      next();
      return;
    }
    // The stream died mid-song (e.g. the friend dropped off Tor): stop here
    // rather than silently jumping to the next track.
    state = state.copyWith(playing: false);
    _player.pause();
  }

  /// Whether a completed event means the song actually finished (as opposed to
  /// a remote stream dying early and hitting EOF). Public for tests.
  @visibleForTesting
  static bool shouldAutoAdvance({
    required Duration position,
    required Duration duration,
  }) {
    return duration <= Duration.zero ||
        position + const Duration(seconds: 2) >= duration;
  }

  /// Plays [track], building the queue from the library when possible so the
  /// queue view reflects the whole collection. When shuffle is on, the queue is
  /// shuffled from [track] so the visible order matches what will actually play.
  Future<void> play(Track track) async {
    final gen = ++_generation;
    var queue = await _queueFor(track);
    if (gen != _generation || !ref.mounted) return;
    final index = queue.indexWhere((t) => t.id == track.id);
    final idx = index < 0 ? 0 : index;
    final shuffled = state.shuffle && queue.length > 1;
    if (shuffled) {
      _savedQueue = queue;
      queue = _shuffleWithCurrent(queue, idx);
    }
    state = state.copyWith(
      queue: queue,
      currentIndex: shuffled ? 0 : idx,
      playing: true,
      position: Duration.zero,
      duration: track.duration,
      sourceId: null,
    );
    await commitPlayback(track, gen);
  }

  /// Plays [track] from an explicit ordered list (e.g. a playlist), setting
  /// the queue to exactly those tracks. Honors shuffle like [play].
  /// [sourceId] records where the queue came from (e.g. the playlist id).
  Future<void> playTracks(
    List<Track> tracks,
    Track track, {
    String? sourceId,
  }) async {
    if (tracks.isEmpty) return;
    final gen = ++_generation;
    var queue = tracks;
    final index = queue.indexWhere((t) => t.id == track.id);
    final idx = index < 0 ? 0 : index;
    final shuffled = state.shuffle && queue.length > 1;
    if (shuffled) {
      _savedQueue = queue;
      queue = _shuffleWithCurrent(queue, idx);
    }
    state = state.copyWith(
      queue: queue,
      currentIndex: shuffled ? 0 : idx,
      playing: true,
      position: Duration.zero,
      duration: track.duration,
      sourceId: sourceId,
    );
    await commitPlayback(track, gen);
  }

  Future<void> togglePlay() async {
    final s = state;
    if (s.current == null) {
      final library = await ref.read(libraryProvider.future);
      if (library.isNotEmpty) return play(library.first);
      return;
    }
    if (s.playing) {
      _player.pause();
    } else {
      _player.play();
    }
  }

  Future<void> next() async {
    final s = state;
    if (s.queue.isEmpty) return;
    var index = s.currentIndex + 1;
    if (index >= s.queue.length) {
      if (!s.repeat) {
        _player.pause();
        return;
      }
      index = 0;
    }
    await _goTo(index);
  }

  Future<void> previous() async {
    final s = state;
    if (s.queue.isEmpty) return;
    var index = s.currentIndex - 1;
    if (index < 0) {
      index = s.repeat ? s.queue.length - 1 : 0;
    }
    await _goTo(index);
  }

  Future<void> seek(Duration position) => _player.seek(position);

  /// Shuffle reorders the actual queue so the visible "Up Next" order is the
  /// real play order. Turning it on keeps the current track first and shuffles
  /// the rest; turning it off restores the pre-shuffle order.
  void toggleShuffle() {
    final s = state;
    if (s.shuffle) {
      final saved = _savedQueue;
      _savedQueue = null;
      if (saved != null && saved.isNotEmpty) {
        final currentId = s.current?.id;
        final index = currentId == null
            ? 0
            : saved.indexWhere((t) => t.id == currentId);
        state = state.copyWith(
          queue: saved,
          currentIndex: index < 0 ? 0 : index,
          shuffle: false,
        );
      } else {
        state = state.copyWith(shuffle: false);
      }
      return;
    }

    _savedQueue = s.queue;
    if (s.queue.length > 1 && s.currentIndex >= 0) {
      state = state.copyWith(
        queue: _shuffleWithCurrent(s.queue, s.currentIndex),
        currentIndex: 0,
        shuffle: true,
      );
    } else {
      state = state.copyWith(shuffle: true);
    }
  }

  void toggleRepeat() => state = state.copyWith(repeat: !state.repeat);

  /// Plays the track at [index] in the current queue without rebuilding it,
  /// preserving any shuffle or manual reorder the user made.
  Future<void> playQueueIndex(int index) async {
    final s = state;
    if (index < 0 || index >= s.queue.length) return;
    await _goTo(index);
  }

  /// Reorders the queue. [oldIndex]/[newIndex] follow the ReorderableListView
  /// convention (newIndex is pre-adjustment). The current track keeps its
  /// position when moved, and index shifts are tracked when other rows move.
  void moveQueueItem(int oldIndex, int newIndex) {
    final queue = [...state.queue];
    if (oldIndex < 0 || oldIndex >= queue.length) return;
    if (newIndex > oldIndex) newIndex -= 1;
    final track = queue.removeAt(oldIndex);
    queue.insert(newIndex, track);

    var currentIndex = state.currentIndex;
    if (oldIndex == currentIndex) {
      currentIndex = newIndex;
    } else if (oldIndex < currentIndex && newIndex >= currentIndex) {
      currentIndex -= 1;
    } else if (oldIndex > currentIndex && newIndex <= currentIndex) {
      currentIndex += 1;
    }
    state = state.copyWith(queue: queue, currentIndex: currentIndex);
  }

  /// Removes a track from the queue. Removing the current track skips to the
  /// next one; removing the last remaining track stops playback.
  Future<void> removeQueueItem(int index) async {
    if (index < 0 || index >= state.queue.length) return;
    final queue = [...state.queue]..removeAt(index);

    if (queue.isEmpty) {
      state = state.copyWith(
        queue: const [],
        currentIndex: -1,
        playing: false,
        position: Duration.zero,
        duration: Duration.zero,
        sourceId: null,
        cacheProgress: null,
      );
      _player.stop();
      return;
    }

    if (index == state.currentIndex) {
      final nextIndex = index.clamp(0, queue.length - 1);
      final next = queue[nextIndex];
      state = state.copyWith(
        queue: queue,
        currentIndex: nextIndex,
        playing: true,
        position: Duration.zero,
        duration: next.duration,
      );
      await commitPlayback(next, ++_generation);
      return;
    }

    final currentIndex = index < state.currentIndex
        ? state.currentIndex - 1
        : state.currentIndex;
    state = state.copyWith(queue: queue, currentIndex: currentIndex);
  }

  Future<List<Track>> _queueFor(Track track) async {
    final library = await ref.read(libraryProvider.future);
    if (library.any((t) => t.id == track.id)) return library;
    return [track];
  }

  Future<void> _goTo(int index) async {
    final gen = ++_generation;
    final track = state.queue[index];
    state = state.copyWith(
      currentIndex: index,
      playing: true,
      position: Duration.zero,
      duration: track.duration,
    );
    await commitPlayback(track, gen);
  }

  /// Loads [track] into the player and starts playback. Split from the entry
  /// points so tests can stub the native player while keeping the generation
  /// guards real.
  @visibleForTesting
  Future<void> commitPlayback(Track track, int generation) async {
    await _progressSub?.cancel();
    _progressSub = null;
    await loadTrack(track, generation);
    // A newer request may have started while this load was in flight; then it
    // owns the player and this one must stay silent.
    if (generation != _generation || !ref.mounted) return;
    startPlayer();
  }

  /// Starts playback of whatever is loaded. Split out so tests can stub the
  /// native engine.
  @visibleForTesting
  void startPlayer() => _player.play();

  /// Loads [track] into the player without starting it. Public for tests.
  @visibleForTesting
  Future<void> loadTrack(Track track, int generation) async {
    if (track.isRemote) {
      await _loadRemote(track, generation);
      return;
    }
    final path = track.filePath;
    if (path == null || path.isEmpty) return;
    final file = File(path);
    if (!await file.exists()) return;
    if (generation != _generation || !ref.mounted) return;
    await _openFile(file.path, generation);
    _setCacheProgress(null);
  }

  Future<void> _openFile(String path, int generation) async {
    try {
      await _player.open(Media(Uri.file(path).toString()));
      _loadedGeneration = generation;
    } catch (_) {
      // Unplayable file: keep the track current but stay silent.
    }
  }

  Future<void> _loadRemote(Track track, int generation) async {
    final onion = track.remoteOwner;
    final remoteTrackId = track.remoteTrackId ?? track.id;
    if (onion == null || remoteTrackId.isEmpty) {
      _setCacheProgress(null);
      return;
    }
    final tor = ref.read(torControllerProvider).value;
    if (tor == null) {
      // Tor isn't running; the track is greyed out anyway. Stay silent.
      _setCacheProgress(null);
      return;
    }

    final cache = await ref.read(cacheServiceProvider);
    if (generation != _generation || !ref.mounted) return;
    final cached = await cache.entry(track.id);
    if (generation != _generation || !ref.mounted) return;
    if (cached != null && cached.complete) {
      if (await File(cached.filePath).exists()) {
        if (generation != _generation || !ref.mounted) return;
        await _openFile(cached.filePath, generation);
        _setCacheProgress(1.0);
        await cache.markPlayed(track.id);
        return;
      }
      // Index says complete but the file vanished: fall through to re-stream.
    }

    RemoteStream stream;
    try {
      stream = await cache.streamTrack(
        trackId: track.id,
        onion: onion,
        remoteTrackId: remoteTrackId,
        socksPort: tor.socksPort,
      );
    } catch (_) {
      _setCacheProgress(null);
      return;
    }
    if (generation != _generation || !ref.mounted) return;

    final sub = stream.progress.listen(_setCacheProgress);
    _progressSub = sub;
    try {
      await stream.ready;
    } catch (_) {
      await sub.cancel();
      if (identical(_progressSub, sub)) _progressSub = null;
      _setCacheProgress(null);
      return;
    }
    if (generation != _generation || !ref.mounted) {
      await sub.cancel();
      if (identical(_progressSub, sub)) _progressSub = null;
      return;
    }

    await _openFile(stream.filePath, generation);
    await cache.markPlayed(track.id);

    stream.done
        .whenComplete(() async {
          await sub.cancel();
          if (identical(_progressSub, sub)) _progressSub = null;
          if (!ref.mounted) return;
          _setCacheProgress(1.0);
          ref.invalidate(cacheStateProvider(track.id));
          ref.invalidate(cacheProgressProvider(track.id));
        })
        .catchError((Object _) async {
          await sub.cancel();
          if (identical(_progressSub, sub)) _progressSub = null;
          if (!ref.mounted) return;
          _setCacheProgress(null);
        });
  }

  void _setCacheProgress(double? value) {
    if (ref.mounted) state = state.copyWith(cacheProgress: value);
  }

  /// Moves the track at [currentIndex] to the front and shuffles the rest,
  /// so the current song plays first and the visible queue matches playback.
  List<Track> _shuffleWithCurrent(List<Track> queue, int currentIndex) {
    if (queue.length <= 1 || currentIndex < 0) return queue;
    final current = queue[currentIndex];
    final rest = [...queue]..removeAt(currentIndex);
    rest.shuffle(_random);
    return [current, ...rest];
  }
}