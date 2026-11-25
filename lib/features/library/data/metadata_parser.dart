import 'dart:convert';
import 'dart:io';
import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:lumina_player/features/library/domain/track.dart';

/// Parses ID3/Vorbis/MP4/FLAC/WAV metadata and caches embedded cover artwork
/// locally as JPEG/PNG files keyed by album+artist hash.
class MetadataParser {
  MetadataParser({required this.artCacheDir});

  final Directory artCacheDir;

  static const supportedExtensions = <String>{
    '.mp3',
    '.flac',
    '.wav',
    '.ogg',
    '.m4a',
  };

  static bool isSupportedAudioFile(String filePath) {
    final ext = p.extension(filePath).toLowerCase();
    return supportedExtensions.contains(ext);
  }

  Future<Track> parseFile(File file) async {
    final filePath = file.path;
    final stat = await file.stat();
    final id = sha1.convert(utf8.encode(filePath)).toString();
    final fallbackTitle = p.basenameWithoutExtension(filePath);
    final folderPath = p.dirname(filePath);

    try {
      final meta = readMetadata(file, getImage: true);
      final title = (meta.title?.trim().isNotEmpty ?? false)
          ? meta.title!.trim()
          : fallbackTitle;
      final artist = (meta.artist?.trim().isNotEmpty ?? false)
          ? meta.artist!.trim()
          : 'Unknown Artist';
      final album = (meta.album?.trim().isNotEmpty ?? false)
          ? meta.album!.trim()
          : 'Unknown Album';
      final albumArtist = (meta.albumArtist?.trim().isNotEmpty ?? false)
          ? meta.albumArtist!.trim()
          : artist;

      String? artPath;
      if (meta.pictures.isNotEmpty) {
        final pic = meta.pictures.first;
        artPath = await _cacheArtwork(
          albumKey: '$albumArtist|$album',
          bytes: pic.bytes,
        );
      }

      return Track(
        id: id,
        uri: filePath,
        title: title,
        artist: artist,
        album: album,
        albumArtist: albumArtist,
        durationMs: meta.duration?.inMilliseconds ?? 0,
        trackNumber: meta.trackNumber ?? 0,
        folderPath: folderPath,
        artworkPath: artPath,
        dateAddedMs: stat.modified.millisecondsSinceEpoch,
      );
    } catch (_) {
      return Track(
        id: id,
        uri: filePath,
        title: fallbackTitle,
        artist: 'Unknown Artist',
        album: 'Unknown Album',
        albumArtist: 'Unknown Artist',
        durationMs: 0,
        trackNumber: 0,
        folderPath: folderPath,
        dateAddedMs: stat.modified.millisecondsSinceEpoch,
      );
    }
  }

  Future<String?> _cacheArtwork({
    required String albumKey,
    required List<int> bytes,
  }) async {
    if (bytes.isEmpty) return null;
    if (!await artCacheDir.exists()) {
      await artCacheDir.create(recursive: true);
    }
    final hash = sha1.convert(utf8.encode(albumKey)).toString();
    final target = File(p.join(artCacheDir.path, '$hash.img'));
    if (!await target.exists()) {
      await target.writeAsBytes(bytes, flush: false);
    }
    return target.path;
  }
}
