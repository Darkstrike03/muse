import 'track.dart';

class Album {
  const Album({
    required this.id,
    required this.title,
    required this.artist,
    required this.tracks,
    this.year,
  });

  final String id;
  final String title;
  final String artist;
  final List<Track> tracks;
  final int? year;

  Duration get totalDuration =>
      tracks.fold(Duration.zero, (sum, t) => sum + t.duration);
}