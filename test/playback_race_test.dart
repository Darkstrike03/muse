import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:muse/features/library/library_provider.dart';
import 'package:muse/features/playback/playback_controller.dart';
import 'package:muse/shared/models/track.dart';

/// Test double: skips the native media_kit engine but keeps the real
/// generation guards, recording what actually reaches the player.
class FakePlaybackController extends PlaybackController {
  final started = <String>[];
  final loadDelays = <String, Duration>{};

  @override
  PlaybackState build() => const PlaybackState();

  @override
  Future<void> loadTrack(Track track, int generation) async {
    await Future<void>.delayed(loadDelays[track.id] ?? Duration.zero);
  }

  @override
  void startPlayer() {
    started.add(state.current?.id ?? '?');
  }
}

Track _track(String id) => Track(
      id: id,
      title: id.toUpperCase(),
      artist: 'Artist',
      albumId: 'album',
      albumTitle: 'Album',
      filePath: '/music/$id.mp3',
      duration: const Duration(minutes: 3),
    );

class FixedLibrary extends Library {
  FixedLibrary(this.tracks);
  final List<Track> tracks;

  @override
  Future<List<Track>> build() async => tracks;
}

void main() {
  Future<void> waitFor(bool Function() condition) async {
    for (var i = 0; i < 200; i++) {
      if (condition()) return;
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    fail('condition not met');
  }

  test('rapid play requests: the last tap wins the player', () async {
    final a = _track('a');
    final b = _track('b');

    final container = ProviderContainer(
      overrides: [
        libraryProvider.overrideWith(() => FixedLibrary([a, b])),
        playbackControllerProvider.overrideWith(FakePlaybackController.new),
      ],
    );
    addTearDown(container.dispose);

    final notifier =
        container.read(playbackControllerProvider.notifier) as FakePlaybackController;
    // a's remote load crawls through Tor; b's is quick.
    notifier.loadDelays['a'] = const Duration(milliseconds: 300);
    notifier.loadDelays['b'] = Duration.zero;

    // Tap a, change your mind and tap b before a finishes loading.
    final first = notifier.play(a);
    await waitFor(
      () => container.read(playbackControllerProvider).current?.id == 'a',
    );
    final second = notifier.play(b);
    await second;
    expect(container.read(playbackControllerProvider).current?.id, 'b');

    await first;
    await Future<void>.delayed(const Duration(milliseconds: 350));

    // Only b may reach the player — a's stale load must stay silent.
    expect(notifier.started, ['b']);
  });

  test('stale queue navigation does not override a newer selection', () async {
    final a = _track('a');
    final b = _track('b');

    final container = ProviderContainer(
      overrides: [
        libraryProvider.overrideWith(() => FixedLibrary([a, b])),
        playbackControllerProvider.overrideWith(FakePlaybackController.new),
      ],
    );
    addTearDown(container.dispose);

    final notifier =
        container.read(playbackControllerProvider.notifier) as FakePlaybackController;
    notifier.loadDelays['a'] = const Duration(milliseconds: 300);

    final first = notifier.play(a);
    await waitFor(
      () => container.read(playbackControllerProvider).current?.id == 'a',
    );
    // next() while a is still loading bumps the generation.
    await notifier.next();
    await first;

    expect(notifier.started, hasLength(1));
    expect(notifier.started.first, 'b');
  });

  group('shouldAutoAdvance', () {
    test('natural end advances', () {
      expect(
        PlaybackController.shouldAutoAdvance(
          position: const Duration(minutes: 2, seconds: 59),
          duration: const Duration(minutes: 3),
        ),
        isTrue,
      );
    });

    test('premature EOF (dead stream) does not advance', () {
      expect(
        PlaybackController.shouldAutoAdvance(
          position: const Duration(minutes: 1),
          duration: const Duration(minutes: 3),
        ),
        isFalse,
      );
    });

    test('unknown duration advances (cannot tell)', () {
      expect(
        PlaybackController.shouldAutoAdvance(
          position: const Duration(minutes: 1),
          duration: Duration.zero,
        ),
        isTrue,
      );
    });
  });
}