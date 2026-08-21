import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/models/shared_scope.dart';
import '../../shared/models/track.dart';
import '../library/library_provider.dart';
import '../pairing/identity_provider.dart';
import '../playlist/playlists_provider.dart';
import 'share_resolver.dart';
import 'share_server.dart';
import 'sharing_provider.dart';

/// The running share server, or an error explaining why it couldn't start.
/// Watching this provider (the Stream tab does) keeps the server alive.
final shareServerStateProvider =
    AsyncNotifierProvider<ShareServerController, ShareServer?>(
  ShareServerController.new,
);

class ShareServerController extends AsyncNotifier<ShareServer?> {
  @override
  Future<ShareServer?> build() async {
    final resolver = await _buildResolver();
    ShareServer server;
    try {
      server = await ShareServer.start(port: shareServerPort, resolver: resolver);
    } on SocketException {
      // Port already taken (e.g. a previous instance): fall back to ephemeral.
      server = await ShareServer.start(port: 0, resolver: resolver);
    }
    ref.onDispose(server.close);
    return server;
  }

  Future<ShareResolver> _buildResolver() async {
    final onion = await ref.read(deviceIdProvider.future);
    final name = await ref.read(deviceNameProvider.future);
    return ShareResolver(
      onion: onion,
      deviceName: name,
      isShareAll: () => ref.read(sharingProvider).value?.shareAll ?? false,
      sharedScopes: () => ref.read(sharingProvider).value?.scopes ?? const [],
      allTracks: () => ref.read(libraryProvider).value ?? const [],
      scopeTracks: _scopeTracks,
      trackById: (id) {
        final tracks = ref.read(libraryProvider).value ?? const [];
        for (final track in tracks) {
          if (track.id == id) return track;
        }
        return null;
      },
    );
  }

  List<Track> _scopeTracks(SharedScope scope) {
    switch (scope.type) {
      case ShareScopeType.playlist:
        return ref.read(playlistTracksProvider(scope.id)).value ?? const [];
      case ShareScopeType.album:
        final albums = ref.read(libraryAlbumsProvider);
        return [
          for (final album in albums)
            if (album.id == scope.id) ...album.tracks,
        ];
      case ShareScopeType.folder:
        final tracks = ref.read(libraryProvider).value ?? const [];
        return [
          for (final track in tracks)
            if (track.albumId == scope.id) track,
        ];
    }
  }
}