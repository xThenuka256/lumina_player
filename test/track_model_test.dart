import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_player/features/library/data/metadata_parser.dart';
import 'package:lumina_player/features/library/domain/track.dart';

void main() {
  test('Track round-trips through SQLite map representation', () {
    const track = Track(
      id: 'abc123',
      uri: '/music/test.flac',
      title: 'Glass Horizon',
      artist: 'Lumina',
      album: 'Refractions',
      albumArtist: 'Lumina',
      durationMs: 245000,
      trackNumber: 3,
      folderPath: '/music',
      artworkPath: '/cache/art.jpg',
      isFavorite: true,
      dateAddedMs: 1700000000,
    );

    final restored = Track.fromMap(track.toMap());
    expect(restored.id, track.id);
    expect(restored.title, track.title);
    expect(restored.isFavorite, isTrue);
    expect(restored.duration, const Duration(seconds: 245));
  });

  test('MetadataParser detects supported local audio extensions', () {
    expect(MetadataParser.isSupportedAudioFile('song.mp3'), isTrue);
    expect(MetadataParser.isSupportedAudioFile('song.FLAC'), isTrue);
    expect(MetadataParser.isSupportedAudioFile('song.wav'), isTrue);
    expect(MetadataParser.isSupportedAudioFile('song.ogg'), isTrue);
    expect(MetadataParser.isSupportedAudioFile('song.m4a'), isTrue);
    expect(MetadataParser.isSupportedAudioFile('cover.jpg'), isFalse);
  });
}
