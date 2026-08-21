import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:muse/app.dart';
import 'package:muse/core/storage/muse_db.dart';
import 'package:muse/features/library/library_provider.dart';
import 'package:muse/features/onboarding/onboarding_screen.dart';
import 'package:muse/features/playback/playback_controller.dart';
import 'package:muse/features/stream/friends_reachability_provider.dart';
import 'package:muse/features/stream/share_server.dart';
import 'package:muse/features/stream/share_server_provider.dart';
import 'package:muse/features/stream/stream_screen.dart';
import 'package:muse/shared/models/track.dart';
import 'package:muse/shared/navigation/app_shell.dart';
import 'package:muse/shared/navigation/muse_nav_bar.dart';

/// Test double: never touches the real media_kit engine, which can't run in
/// the widget-test environment. All playback surfaces read state only.
class TestPlaybackController extends PlaybackController {
  @override
  PlaybackState build() => const PlaybackState();
}

/// Test double: never binds a real HTTP server (or port 42800) in tests.
class TestShareServerController extends ShareServerController {
  @override
  Future<ShareServer?> build() async => null;
}

/// Test double: never starts the 30s reachability probe timer in tests.
class TestReachability extends FriendsReachability {
  @override
  Future<Set<String>> build() async => const {};
}

/// Test double: simulates a failed library scan (e.g. storage permission
/// denied on Android), which used to blank out imported playlists.
class BrokenLibrary extends Library {
  @override
  Future<List<Track>> build() async => throw StateError('scan failed');
}

void main() {
  Future<void> usePortrait(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
  }

  Widget testApp() => ProviderScope(
        overrides: [
          playbackControllerProvider.overrideWith(TestPlaybackController.new),
          // file_picker is a platform channel; return a fake path instead.
          pickMusicFolderProvider.overrideWith(
            (ref) => () async => r'C:\Music\Test',
          ),
          // SQLite via ffi in-memory; path_provider isn't available in tests.
          museDbProvider.overrideWithValue(
            MuseDb.open(path: inMemoryDatabasePath),
          ),
          shareServerStateProvider.overrideWith(TestShareServerController.new),
          friendsReachabilityProvider.overrideWith(TestReachability.new),
        ],
        child: const MuseApp(),
      );

  testWidgets('first launch shows onboarding', (tester) async {
    await usePortrait(tester);
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(testApp());
    await tester.pumpAndSettle();

    expect(find.byType(OnboardingScreen), findsOneWidget);
    expect(find.text('muse'), findsOneWidget);
  });

  testWidgets('completing onboarding requires a folder, then enters the shell',
      (tester) async {
    await usePortrait(tester);
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(testApp());
    await tester.pumpAndSettle();

    // Step 1: identity pitch.
    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();

    // Step 2: folder step — Enter Muse is disabled until a folder is added.
    final enterButton = find.widgetWithText(FilledButton, 'Enter Muse');
    expect(
      tester.widget<FilledButton>(enterButton).onPressed,
      isNull,
    );

    await tester.tap(find.text('Add folder'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<FilledButton>(enterButton).onPressed,
      isNotNull,
    );

    await tester.tap(find.text('Enter Muse'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.byType(AppShell), findsOneWidget);
    expect(find.byType(OnboardingScreen), findsNothing);

    // Floating marble nav bar with five slots; Home is the medallion.
    expect(find.byType(MuseNavBar), findsOneWidget);
    expect(find.text('Library'), findsOneWidget);
    expect(find.text('Search'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Stream'), findsOneWidget);
    expect(find.text('Home'), findsNothing);
  });

  testWidgets('returning user goes straight to the shell', (tester) async {
    await usePortrait(tester);
    SharedPreferences.setMockInitialValues({'onboarding_done': true});

    await tester.pumpWidget(testApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.byType(AppShell), findsOneWidget);
    expect(find.byType(OnboardingScreen), findsNothing);
  });

  testWidgets('stream screen renders while identity is still loading',
      (tester) async {
    await usePortrait(tester);
    SharedPreferences.setMockInitialValues({'onboarding_done': true});

    await tester.pumpWidget(testApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(milliseconds: 600));

    await tester.tap(find.text('Stream'));
    // Single frame: the identity provider has not resolved yet, so the screen
    // must survive its loading state (regression: it used to RangeError on a
    // 1-char placeholder id).
    await tester.pump();

    expect(find.byType(StreamScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('imported playlists show a shared badge and hide local controls',
      (tester) async {
    await usePortrait(tester);
    SharedPreferences.setMockInitialValues({'onboarding_done': true});

    final db = MuseDb.open(path: inMemoryDatabasePath);
    addTearDown(() async => (await db).close());
    // sqflite runs on a separate isolate; its futures only complete while the
    // binding pumps real async, so seeding must go through runAsync.
    await tester.runAsync(() async {
      final handle = await db;
      const onion = 'cccccccccccccccccccccccccccccccccccccccccccccccccccc';
      await handle.insertFriend(onion, 'Bob');
      await handle.importRemotePlaylist(
        id: 'remote:$onion:playlist:pl1',
        ownerOnion: onion,
        name: 'Bob · Mix',
        tracks: [
          PlaylistTrack(
            trackId: '/a.mp3',
            title: 'A',
            artist: 'Art',
            albumTitle: 'Album',
            albumId: 'al1',
            durationMs: 1000,
            ownerOnion: onion,
          ),
        ],
      );
    });

    await tester.pumpWidget(ProviderScope(
      overrides: [
        playbackControllerProvider.overrideWith(TestPlaybackController.new),
        pickMusicFolderProvider.overrideWith(
          (ref) => () async => r'C:\Music\Test',
        ),
        museDbProvider.overrideWithValue(db),
        shareServerStateProvider.overrideWith(TestShareServerController.new),
        friendsReachabilityProvider.overrideWith(TestReachability.new),
      ],
      child: const MuseApp(),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(milliseconds: 600));

    // Note: no pumpAndSettle after the shell mounts — MuseWave animates
    // forever on Home, so we advance time with fixed pumps instead.
    await tester.tap(find.text('Library'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('Playlists'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Bob · Mix'), findsOneWidget);
    expect(find.text('Shared · 1 songs'), findsOneWidget);

    await tester.tap(find.text('Bob · Mix'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Shared by Bob'), findsOneWidget);
    expect(find.text('Rename'), findsNothing);
    expect(find.text('Add songs'), findsNothing);
    expect(find.byIcon(Icons.remove_circle_outline_rounded), findsNothing);

    // The imported track itself renders even though it is not in the local
    // library (regression: the detail used to block on the library scan).
    expect(find.text('A'), findsOneWidget);
  });

  testWidgets('imported playlists render even when the library scan fails',
      (tester) async {
    await usePortrait(tester);
    SharedPreferences.setMockInitialValues({'onboarding_done': true});

    final db = MuseDb.open(path: inMemoryDatabasePath);
    addTearDown(() async => (await db).close());
    await tester.runAsync(() async {
      final handle = await db;
      const onion = 'dddddddddddddddddddddddddddddddddddddddddddddddddddd';
      await handle.insertFriend(onion, 'Cara');
      await handle.importRemotePlaylist(
        id: 'remote:$onion:playlist:pl9',
        ownerOnion: onion,
        name: 'Cara · Mix',
        tracks: [
          PlaylistTrack(
            trackId: '/b.mp3',
            title: 'B',
            artist: 'Art',
            albumTitle: 'Album',
            albumId: 'al1',
            durationMs: 2000,
            ownerOnion: onion,
          ),
        ],
      );
    });

    await tester.pumpWidget(ProviderScope(
      overrides: [
        playbackControllerProvider.overrideWith(TestPlaybackController.new),
        pickMusicFolderProvider.overrideWith(
          (ref) => () async => r'C:\Music\Test',
        ),
        museDbProvider.overrideWithValue(db),
        shareServerStateProvider.overrideWith(TestShareServerController.new),
        friendsReachabilityProvider.overrideWith(TestReachability.new),
        // Simulates Android denying storage access: the scan errors out.
        libraryProvider.overrideWith(BrokenLibrary.new),
      ],
      child: const MuseApp(),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(milliseconds: 600));

    await tester.tap(find.text('Library'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('Playlists'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Cara · Mix'), findsOneWidget);

    await tester.tap(find.text('Cara · Mix'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Shared by Cara'), findsOneWidget);
    expect(find.text('B'), findsOneWidget);
    expect(find.text('Could not load these songs right now.'), findsNothing);
  });
}