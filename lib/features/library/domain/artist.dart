import 'package:lumina_player/features/library/domain/track.dart';

/// Aggregated artist view derived from scanned local tracks.
class Artist {
  const Artist({
    required this.name,
    required this.tracks,
    required this.albumCount,
    this.artworkPath,
  });

  final String name;
  final List<Track> tracks;
  final int albumCount;
  final String? artworkPath;
}
