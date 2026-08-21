import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/album_artist/album_detail_screen.dart';
import '../../features/album_artist/artist_detail_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/library/library_screen.dart';
import '../../features/now_playing/now_playing_screen.dart';
import '../../features/onboarding/onboarding_screen.dart';
import '../../features/onboarding/splash_screen.dart';
import '../../features/pairing/pairing_screen.dart';
import '../../features/playback/playback_controller.dart';
import '../../features/playlist/playlist_detail_screen.dart';
import '../../features/search/search_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/stream/stream_screen.dart';
import '../../shared/models/track.dart';
import '../../shared/navigation/app_shell.dart';
import '../../shared/state/app_state.dart';

/// Paths used by the app. Navigation happens through these constants so
/// call sites stay readable and rename-safe.
abstract final class MusePaths {
  static const splash = '/splash';
  static const onboarding = '/onboarding';
  static const nowPlaying = '/now-playing';
  static const pairing = '/pairing';
  static const album = '/album';
  static const artist = '/artist';
  static const playlist = '/playlist';
  static const library = '/library';
  static const search = '/search';
  static const home = '/home';
  static const settings = '/settings';
  static const stream = '/stream';

  static String albumFor(String albumId) => '$album/$albumId';
  static String artistFor(String name) => '$artist/$name';
  static String playlistFor(String playlistId) => '$playlist/$playlistId';
  static String nowPlayingFor(String trackId) =>
      '$nowPlaying?track=$trackId';
}

final rootNavigatorKey = GlobalKey<NavigatorState>();

/// Opens the shared player, replacing any existing player instance so the
/// stack never accumulates multiple Now Playing screens. The track is handed
/// to the shared playback controller first, so every surface stays in sync.
void openPlayer(BuildContext context, Track track) {
  ProviderScope.containerOf(context)
      .read(playbackControllerProvider.notifier)
      .play(track);
  context.pushReplacement(MusePaths.nowPlayingFor(track.id));
}

/// Opens the Now Playing screen without touching the player. For surfaces
/// where the track is already playing (e.g. the Home now-playing card), so
/// navigating never restarts or resets the song.
void openNowPlaying(BuildContext context, Track track) {
  context.pushReplacement(MusePaths.nowPlayingFor(track.id));
}

/// Plays [track] from an explicit ordered list (e.g. a playlist) and opens
/// the player, keeping the queue scoped to that list. [sourceId] records the
/// playlist the queue came from so its UI can show a "playing" badge.
void openTracks(
  BuildContext context,
  List<Track> tracks,
  Track track, {
  String? sourceId,
}) {
  ProviderScope.containerOf(context)
      .read(playbackControllerProvider.notifier)
      .playTracks(tracks, track, sourceId: sourceId);
  context.pushReplacement(MusePaths.nowPlayingFor(track.id));
}

final goRouterProvider = Provider<GoRouter>((ref) {
  final onboarding = ref.watch(onboardingDoneProvider);

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: MusePaths.splash,
    debugLogDiagnostics: false,
    redirect: (context, state) {
      final path = state.uri.path;
      if (onboarding.isLoading) return null; // stay on splash until known
      final done = onboarding.value ?? false;
      if (path == MusePaths.splash) return done ? MusePaths.home : MusePaths.onboarding;
      if (!done) return MusePaths.onboarding;
      return null;
    },
    routes: [
      GoRoute(
        path: MusePaths.splash,
        name: 'splash',
        builder: (_, _) => const SplashScreen(),
      ),
      GoRoute(
        path: MusePaths.onboarding,
        name: 'onboarding',
        builder: (_, _) => const OnboardingScreen(),
      ),
      GoRoute(
        path: MusePaths.nowPlaying,
        name: 'now-playing',
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, state) => NowPlayingScreen(
          trackId: state.uri.queryParameters['track'],
        ),
      ),
      GoRoute(
        path: MusePaths.pairing,
        name: 'pairing',
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, _) => const PairingScreen(),
      ),
      GoRoute(
        path: '${MusePaths.album}/:albumId',
        name: 'album',
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, state) => AlbumDetailScreen(
          albumId: state.pathParameters['albumId'] ?? '',
        ),
      ),
      GoRoute(
        path: '${MusePaths.artist}/:name',
        name: 'artist',
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, state) => ArtistDetailScreen(
          artist: state.pathParameters['name'] ?? '',
        ),
      ),
      GoRoute(
        path: '${MusePaths.playlist}/:playlistId',
        name: 'playlist',
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, state) => PlaylistDetailScreen(
          playlistId: state.pathParameters['playlistId'] ?? '',
        ),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: MusePaths.library,
                name: 'library',
                builder: (_, _) => const LibraryScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: MusePaths.search,
                name: 'search',
                builder: (_, _) => const SearchScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: MusePaths.home,
                name: 'home',
                builder: (_, _) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: MusePaths.settings,
                name: 'settings',
                builder: (_, _) => const SettingsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: MusePaths.stream,
                name: 'stream',
                builder: (_, _) => const StreamScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});