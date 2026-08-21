import 'dart:io';

import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../shared/models/album.dart';
import '../../shared/models/track.dart';

/// Seam around the platform folder picker so onboarding and settings are
/// testable (file_picker is a platform channel and can't run in tests).
final pickMusicFolderProvider = Provider<Future<String?> Function()>(
  (ref) => () async => FilePicker.getDirectoryPath(),
);

/// Folders the user has pointed Muse at. Persisted in SharedPreferences so
/// the library survives restarts.
final musicFoldersProvider =
    AsyncNotifierProvider<MusicFolders, List<String>>(MusicFolders.new);

class MusicFolders extends AsyncNotifier<List<String>> {
  static const _key = 'music_folders';

  @override
  Future<List<String>> build() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_key) ?? const [];
  }

  Future<void> add(String path) async {
    final current = await Future.value(state.value ?? const <String>[]);
    if (current.contains(path)) return;
    final updated = [...current, path];
    await _persist(updated);
  }

  Future<void> remove(String path) async {
    final current = await Future.value(state.value ?? const <String>[]);
    final updated = current.where((p) => p != path).toList(growable: false);
    await _persist(updated);
  }

  Future<void> _persist(List<String> updated) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, updated);
    state = AsyncData(updated);
  }
}

/// The playable library: scanned tracks from configured folders. Empty when
/// no folders are configured — the UI guides the user to add one.
final libraryProvider =
    AsyncNotifierProvider<Library, List<Track>>(Library.new);

class Library extends AsyncNotifier<List<Track>> {
  @override
  Future<List<Track>> build() async {
    final folders = await ref.watch(musicFoldersProvider.future);
    if (folders.isEmpty) return const [];

    final tracks = <Track>[];
    for (final folder in folders) {
      final dir = Directory(folder);
      if (!await dir.exists()) continue;
      try {
        await for (final file in _audioFiles(dir)) {
          await Future<void>.delayed(Duration.zero);
          final meta = await _readTags(file);
          final albumTag = _nonEmpty(meta.album);
          tracks.add(Track(
            id: file.path,
            title: _nonEmpty(meta.title) ?? _nameFrom(file),
            artist: _nonEmpty(meta.artist) ?? 'Unknown Artist',
            albumId: albumTag ?? dir.path,
            albumTitle: albumTag ?? dir.path.split(Platform.pathSeparator).last,
            filePath: file.path,
            duration: meta.duration ?? Duration.zero,
          ));
        }
      } catch (_) {
        // Unreadable folder (e.g. storage permission revoked): skip it rather
        // than failing the whole library.
      }
    }

    tracks.sort((a, b) {
      final byTitle = a.title.toLowerCase().compareTo(b.title.toLowerCase());
      return byTitle != 0 ? byTitle : a.artist.compareTo(b.artist);
    });
    return tracks;
  }

  Stream<File> _audioFiles(Directory dir) async* {
    final extensions = supportedFileExtensions.toSet();
    await for (final entity in dir.list(recursive: true, followLinks: false)) {
      if (entity is File && extensions.contains(_extensionOf(entity.path))) {
        yield entity;
      }
    }
  }

  Future<AudioMetadata> _readTags(File file) async {
    try {
      return readMetadata(file);
    } catch (_) {
      return AudioMetadata(file: file);
    }
  }

  String _extensionOf(String path) {
    final i = path.lastIndexOf('.');
    return i < 0 ? '' : path.substring(i).toLowerCase();
  }

  String _nameFrom(File file) {
    final name = file.path.split(Platform.pathSeparator).last;
    final i = name.lastIndexOf('.');
    return i > 0 ? name.substring(0, i) : name;
  }

  String? _nonEmpty(String? value) {
    final trimmed = value?.trim();
    return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
  }
}

/// Albums derived from the scanned library, grouped by [Track.albumId] and
/// sorted by title. Untagged tracks group under their folder (basename title).
final libraryAlbumsProvider = Provider<List<Album>>((ref) {
  final tracks = ref.watch(libraryProvider).value ?? const [];
  final byKey = <String, List<Track>>{};
  for (final track in tracks) {
    byKey.putIfAbsent(track.albumId, () => []).add(track);
  }
  final albums = byKey.entries.map((entry) {
    final albumTracks = entry.value..sort((a, b) {
      final byTitle = a.title.toLowerCase().compareTo(b.title.toLowerCase());
      return byTitle != 0 ? byTitle : a.artist.compareTo(b.artist);
    });
    final first = albumTracks.first;
    return Album(
      id: entry.key,
      title: first.albumTitle.isNotEmpty ? first.albumTitle : entry.key,
      artist: first.artist,
      tracks: albumTracks,
    );
  }).toList()
    ..sort(
      (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
    );
  return albums;
});

/// Distinct artist names from the scanned library, sorted.
final libraryArtistsProvider = Provider<List<String>>((ref) {
  final tracks = ref.watch(libraryProvider).value ?? const [];
  return tracks.map((t) => t.artist).toSet().toList(growable: false)
    ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
});