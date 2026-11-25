import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:lumina_player/core/storage/library_database.dart';
import 'package:lumina_player/features/library/data/metadata_parser.dart';
import 'package:lumina_player/features/library/domain/track.dart';

/// Cross-platform library scanner:
/// - Linux: Detects XDG user music directory (`~/.config/user-dirs.dirs` / `~/Music`)
///   plus custom user-selected folders, honoring excluded folders.
/// - Android 11+ (API 30+): Queries `MediaStore.Audio.Media.EXTERNAL_CONTENT_URI`
///   via platform channel (Scoped Storage compliant) and supports SAF tree URIs.
class LibraryScanner {
  LibraryScanner._();
  static final LibraryScanner instance = LibraryScanner._();

  static const _channel = MethodChannel('dev.lumina.player/mediastore');

  Future<Directory> _getArtCacheDir() async {
    final cache = await getApplicationCacheDirectory();
    return Directory(p.join(cache.path, 'art_cache'));
  }

  /// Resolves the Linux XDG `XDG_MUSIC_DIR`, falling back to `$HOME/Music`.
  Future<String?> detectXdgMusicDirectory() async {
    if (!Platform.isLinux) return null;
    final home = Platform.environment['HOME'];
    if (home == null || home.isEmpty) return null;

    final userDirsFile = File(p.join(home, '.config', 'user-dirs.dirs'));
    if (await userDirsFile.exists()) {
      try {
        final lines = await userDirsFile.readAsLines();
        for (final line in lines) {
          final trimmed = line.trim();
          if (trimmed.startsWith('XDG_MUSIC_DIR=')) {
            var value = trimmed.substring('XDG_MUSIC_DIR='.length).trim();
            if (value.startsWith('"') && value.endsWith('"') && value.length >= 2) {
              value = value.substring(1, value.length - 1);
            }
            value = value.replaceAll(r'$HOME', home);
            if (await Directory(value).exists()) {
              return value;
            }
          }
        }
      } catch (_) {
        // Fallback below
      }
    }

    final defaultMusic = p.join(home, 'Music');
    if (await Directory(defaultMusic).exists()) {
      return defaultMusic;
    }
    return null;
  }

  /// Prompts user to choose a folder (SAF on Android 11+, native portal on Linux)
  /// and registers it in SQLite watched folders.
  Future<String?> pickAndAddFolder() async {
    try {
      final selectedUri = await FilePicker.pickDirectory(
        dialogTitle: 'Select Music Folder',
      );
      if (selectedUri == null) return null;
      final resolved = selectedUri.scheme == 'file'
          ? selectedUri.toFilePath()
          : selectedUri.toString();
      if (resolved.isEmpty) return null;
      await LibraryDatabase.instance.addFolderRule(resolved, 'watched');
      return resolved;
    } catch (_) {
      return null;
    }
  }

  Future<List<Track>> scanLibrary() async {
    final db = LibraryDatabase.instance;
    final watched = await db.getFolders('watched');
    final excluded = await db.getFolders('excluded');
    final excludedSet = excluded.map(p.normalize).toSet();

    final tracks = <Track>[];
    final seenIds = <String>{};

    if (Platform.isAndroid) {
      final mediaStoreTracks = await _scanAndroidMediaStore(excludedSet);
      for (final t in mediaStoreTracks) {
        if (seenIds.add(t.id)) {
          tracks.add(t);
        }
      }

      // Also scan any custom SAF / directory entries added by the user
      for (final folder in watched) {
        if (_isExcluded(folder, excludedSet)) continue;
        final safTracks = await _scanAndroidFolder(folder);
        for (final t in safTracks) {
          if (seenIds.add(t.id)) {
            tracks.add(t);
          }
        }
      }
    } else {
      final roots = <String>{...watched};
      final xdgMusic = await detectXdgMusicDirectory();
      if (xdgMusic != null) {
        roots.add(xdgMusic);
      }

      final artCacheDir = await _getArtCacheDir();
      final parser = MetadataParser(artCacheDir: artCacheDir);

      for (final root in roots) {
        if (_isExcluded(root, excludedSet)) continue;
        final dir = Directory(root);
        if (!await dir.exists()) continue;

        await for (final entity
            in dir.list(recursive: true, followLinks: false)) {
          if (entity is! File) continue;
          if (!MetadataParser.isSupportedAudioFile(entity.path)) continue;
          if (_isExcluded(entity.path, excludedSet)) continue;

          final track = await parser.parseFile(entity);
          if (seenIds.add(track.id)) {
            tracks.add(track);
          }
        }
      }
    }

    tracks.sort(
      (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
    );
    await db.replaceScannedTracks(tracks);
    return db.loadTracks();
  }

  Future<List<Track>> _scanAndroidMediaStore(Set<String> excludedSet) async {
    try {
      final raw = await _channel.invokeMethod<List<dynamic>>('queryAudioTracks');
      if (raw == null) return const [];
      return _mapNativeTracks(raw, excludedSet);
    } catch (_) {
      return const [];
    }
  }

  Future<List<Track>> _scanAndroidFolder(String folderPathOrUri) async {
    if (folderPathOrUri.startsWith('content://')) {
      try {
        final raw = await _channel.invokeMethod<List<dynamic>>(
          'querySafFolder',
          {'treeUri': folderPathOrUri},
        );
        if (raw == null) return const [];
        return _mapNativeTracks(raw, const {});
      } catch (_) {
        return const [];
      }
    }

    final dir = Directory(folderPathOrUri);
    if (!await dir.exists()) return const [];
    final parser = MetadataParser(artCacheDir: await _getArtCacheDir());
    final list = <Track>[];
    await for (final entity in dir.list(recursive: true, followLinks: false)) {
      if (entity is File && MetadataParser.isSupportedAudioFile(entity.path)) {
        list.add(await parser.parseFile(entity));
      }
    }
    return list;
  }

  List<Track> _mapNativeTracks(
      List<dynamic> raw, Set<String> excludedSet) {
    final result = <Track>[];
    for (final entry in raw) {
      final map = Map<String, dynamic>.from(entry as Map);
      final uri = (map['uri'] as String?) ?? '';
      final folder = (map['folderPath'] as String?) ?? '';
      if (uri.isEmpty) continue;
      if (!MetadataParser.isSupportedAudioFile(
          (map['displayName'] as String?) ?? uri)) {
        // Still allow MediaStore entries whose URI has no extension if mime matches
        final mime = (map['mimeType'] as String?) ?? '';
        if (!mime.startsWith('audio/')) continue;
      }
      if (_isExcluded(folder, excludedSet) || _isExcluded(uri, excludedSet)) {
        continue;
      }

      final id = sha1.convert(utf8.encode(uri)).toString();
      result.add(
        Track(
          id: id,
          uri: uri,
          title: ((map['title'] as String?)?.trim().isNotEmpty ?? false)
              ? (map['title'] as String).trim()
              : p.basenameWithoutExtension(uri),
          artist: ((map['artist'] as String?)?.trim().isNotEmpty ?? false)
              ? (map['artist'] as String).trim()
              : 'Unknown Artist',
          album: ((map['album'] as String?)?.trim().isNotEmpty ?? false)
              ? (map['album'] as String).trim()
              : 'Unknown Album',
          albumArtist: ((map['albumArtist'] as String?)?.trim().isNotEmpty ?? false)
              ? (map['albumArtist'] as String).trim()
              : (((map['artist'] as String?)?.trim().isNotEmpty ?? false)
                  ? (map['artist'] as String).trim()
                  : 'Unknown Artist'),
          durationMs: (map['durationMs'] as int?) ?? 0,
          trackNumber: (map['trackNumber'] as int?) ?? 0,
          folderPath: folder,
          artworkPath: map['artworkPath'] as String?,
          dateAddedMs: (map['dateAddedMs'] as int?) ?? 0,
        ),
      );
    }
    return result;
  }

  bool _isExcluded(String candidate, Set<String> excludedSet) {
    if (excludedSet.isEmpty || candidate.isEmpty) return false;
    final normalized = p.normalize(candidate);
    for (final ex in excludedSet) {
      if (normalized == ex || p.isWithin(ex, normalized)) {
        return true;
      }
    }
    return false;
  }
}
