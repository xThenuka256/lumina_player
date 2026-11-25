/// Immutable representation of a local audio track.
class Track {
  const Track({
    required this.id,
    required this.uri,
    required this.title,
    required this.artist,
    required this.album,
    required this.albumArtist,
    required this.durationMs,
    required this.trackNumber,
    required this.folderPath,
    this.artworkPath,
    this.isFavorite = false,
    this.dateAddedMs = 0,
  });

  final String id;
  final String uri;
  final String title;
  final String artist;
  final String album;
  final String albumArtist;
  final int durationMs;
  final int trackNumber;
  final String folderPath;
  final String? artworkPath;
  final bool isFavorite;
  final int dateAddedMs;

  Duration get duration => Duration(milliseconds: durationMs);

  Track copyWith({
    String? id,
    String? uri,
    String? title,
    String? artist,
    String? album,
    String? albumArtist,
    int? durationMs,
    int? trackNumber,
    String? folderPath,
    String? artworkPath,
    bool? isFavorite,
    int? dateAddedMs,
  }) {
    return Track(
      id: id ?? this.id,
      uri: uri ?? this.uri,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      album: album ?? this.album,
      albumArtist: albumArtist ?? this.albumArtist,
      durationMs: durationMs ?? this.durationMs,
      trackNumber: trackNumber ?? this.trackNumber,
      folderPath: folderPath ?? this.folderPath,
      artworkPath: artworkPath ?? this.artworkPath,
      isFavorite: isFavorite ?? this.isFavorite,
      dateAddedMs: dateAddedMs ?? this.dateAddedMs,
    );
  }

  Map<String, Object?> toMap() => {
        'id': id,
        'uri': uri,
        'title': title,
        'artist': artist,
        'album': album,
        'album_artist': albumArtist,
        'duration_ms': durationMs,
        'track_number': trackNumber,
        'folder_path': folderPath,
        'artwork_path': artworkPath,
        'is_favorite': isFavorite ? 1 : 0,
        'date_added_ms': dateAddedMs,
      };

  factory Track.fromMap(Map<String, Object?> map) => Track(
        id: map['id'] as String,
        uri: map['uri'] as String,
        title: map['title'] as String,
        artist: map['artist'] as String,
        album: map['album'] as String,
        albumArtist: (map['album_artist'] as String?) ?? 'Unknown Artist',
        durationMs: (map['duration_ms'] as int?) ?? 0,
        trackNumber: (map['track_number'] as int?) ?? 0,
        folderPath: (map['folder_path'] as String?) ?? '',
        artworkPath: map['artwork_path'] as String?,
        isFavorite: ((map['is_favorite'] as int?) ?? 0) == 1,
        dateAddedMs: (map['date_added_ms'] as int?) ?? 0,
      );
}
