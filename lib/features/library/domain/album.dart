import 'package:lumina_player/features/library/domain/track.dart';

/// Aggregated album view derived from scanned local tracks.
class Album {
  const Album({
    required this.name,
    required this.artist,
    required this.tracks,
    this.artworkPath,
  });

  final String name;
  final String artist;
  final List<Track> tracks;
  final String? artworkPath;

  Duration get totalDuration => tracks.fold(
        Duration.zero,
        (acc, t) => acc + t.duration,
      );
}
