import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:lumina_player/features/library/domain/track.dart';
import 'package:lumina_player/features/playlists/domain/playlist.dart';

/// Persistent local SQLite store for cached music metadata, playlists,
/// watched/excluded folders, and playback resumption state.
class LibraryDatabase {
  LibraryDatabase._();
  static final LibraryDatabase instance = LibraryDatabase._();

  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _open();
    return _db!;
  }

  Future<Database> _open() async {
    if (Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    final supportDir = await getApplicationSupportDirectory();
    if (!await supportDir.exists()) {
      await supportDir.create(recursive: true);
    }
    final dbPath = p.join(supportDir.path, 'lumina_library.db');

    return openDatabase(
      dbPath,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE tracks (
            id TEXT PRIMARY KEY,
            uri TEXT NOT NULL,
            title TEXT NOT NULL,
            artist TEXT NOT NULL,
            album TEXT NOT NULL,
            album_artist TEXT NOT NULL,
            duration_ms INTEGER NOT NULL,
            track_number INTEGER NOT NULL,
            folder_path TEXT NOT NULL,
            artwork_path TEXT,
            is_favorite INTEGER NOT NULL DEFAULT 0,
            date_added_ms INTEGER NOT NULL DEFAULT 0
          )
        ''');

        await db.execute('''
          CREATE TABLE playlists (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            created_at_ms INTEGER NOT NULL
          )
        ''');

        await db.execute('''
          CREATE TABLE playlist_tracks (
            playlist_id TEXT NOT NULL,
            track_id TEXT NOT NULL,
            position INTEGER NOT NULL,
            PRIMARY KEY (playlist_id, track_id)
          )
        ''');

        await db.execute('''
          CREATE TABLE folder_rules (
            path TEXT PRIMARY KEY,
            rule_type TEXT NOT NULL
          )
        ''');

        await db.execute('''
          CREATE TABLE playback_state (
            id INTEGER PRIMARY KEY CHECK (id = 1),
            queue_ids TEXT NOT NULL,
            current_index INTEGER NOT NULL,
            position_ms INTEGER NOT NULL,
            shuffle INTEGER NOT NULL,
            repeat_mode INTEGER NOT NULL,
            speed REAL NOT NULL
          )
        ''');
      },
    );
  }

  Future<List<Track>> loadTracks() async {
    final db = await database;
    final rows = await db.query('tracks', orderBy: 'title COLLATE NOCASE ASC');
    return rows.map(Track.fromMap).toList();
  }

  Future<void> replaceScannedTracks(List<Track> scanned) async {
    final db = await database;
    final existingRows = await db.query('tracks', columns: ['id', 'is_favorite']);
    final favMap = <String, bool>{
      for (final row in existingRows)
        row['id'] as String: ((row['is_favorite'] as int?) ?? 0) == 1,
    };

    await db.transaction((txn) async {
      await txn.delete('tracks');
      final batch = txn.batch();
      for (final track in scanned) {
        final merged = track.copyWith(
          isFavorite: favMap[track.id] ?? track.isFavorite,
        );
        batch.insert('tracks', merged.toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await batch.commit(noResult: true);
    });
  }

  Future<void> setTrackFavorite(String trackId, bool isFavorite) async {
    final db = await database;
    await db.update(
      'tracks',
      {'is_favorite': isFavorite ? 1 : 0},
      where: 'id = ?',
      whereArgs: [trackId],
    );
  }

  Future<List<String>> getFolders(String ruleType) async {
    final db = await database;
    final rows = await db.query(
      'folder_rules',
      where: 'rule_type = ?',
      whereArgs: [ruleType],
      orderBy: 'path ASC',
    );
    return rows.map((r) => r['path'] as String).toList();
  }

  Future<void> addFolderRule(String path, String ruleType) async {
    final db = await database;
    await db.insert(
      'folder_rules',
      {'path': path, 'rule_type': ruleType},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> removeFolderRule(String path, String ruleType) async {
    final db = await database;
    await db.delete(
      'folder_rules',
      where: 'path = ? AND rule_type = ?',
      whereArgs: [path, ruleType],
    );
  }

  Future<List<PlaylistModel>> loadPlaylists() async {
    final db = await database;
    final plRows = await db.query('playlists', orderBy: 'created_at_ms DESC');
    final results = <PlaylistModel>[];
    for (final row in plRows) {
      final id = row['id'] as String;
      final trackRows = await db.query(
        'playlist_tracks',
        where: 'playlist_id = ?',
        whereArgs: [id],
        orderBy: 'position ASC',
      );
      results.add(
        PlaylistModel(
          id: id,
          name: row['name'] as String,
          createdAtMs: row['created_at_ms'] as int,
          trackIds: trackRows.map((t) => t['track_id'] as String).toList(),
        ),
      );
    }
    return results;
  }

  Future<void> createPlaylist(PlaylistModel playlist) async {
    final db = await database;
    await db.insert('playlists', {
      'id': playlist.id,
      'name': playlist.name,
      'created_at_ms': playlist.createdAtMs,
    });
  }

  Future<void> deletePlaylist(String playlistId) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete(
        'playlist_tracks',
        where: 'playlist_id = ?',
        whereArgs: [playlistId],
      );
      await txn.delete('playlists', where: 'id = ?', whereArgs: [playlistId]);
    });
  }

  Future<void> renamePlaylist(String playlistId, String newName) async {
    final db = await database;
    await db.update(
      'playlists',
      {'name': newName},
      where: 'id = ?',
      whereArgs: [playlistId],
    );
  }

  Future<void> setPlaylistTracks(
      String playlistId, List<String> trackIds) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete(
        'playlist_tracks',
        where: 'playlist_id = ?',
        whereArgs: [playlistId],
      );
      final batch = txn.batch();
      for (var i = 0; i < trackIds.length; i++) {
        batch.insert(
          'playlist_tracks',
          {
            'playlist_id': playlistId,
            'track_id': trackIds[i],
            'position': i,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);
    });
  }

  Future<void> savePlaybackState({
    required List<String> queueIds,
    required int currentIndex,
    required int positionMs,
    required bool shuffle,
    required int repeatMode,
    required double speed,
  }) async {
    final db = await database;
    await db.insert(
      'playback_state',
      {
        'id': 1,
        'queue_ids': jsonEncode(queueIds),
        'current_index': currentIndex,
        'position_ms': positionMs,
        'shuffle': shuffle ? 1 : 0,
        'repeat_mode': repeatMode,
        'speed': speed,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<PersistedPlaybackState?> loadPlaybackState() async {
    final db = await database;
    final rows = await db.query('playback_state', where: 'id = 1');
    if (rows.isEmpty) return null;
    final row = rows.first;
    final rawIds = jsonDecode(row['queue_ids'] as String) as List<dynamic>;
    return PersistedPlaybackState(
      queueIds: rawIds.cast<String>(),
      currentIndex: (row['current_index'] as int?) ?? 0,
      positionMs: (row['position_ms'] as int?) ?? 0,
      shuffle: ((row['shuffle'] as int?) ?? 0) == 1,
      repeatMode: (row['repeat_mode'] as int?) ?? 0,
      speed: ((row['speed'] as num?) ?? 1.0).toDouble(),
    );
  }
}

class PersistedPlaybackState {
  const PersistedPlaybackState({
    required this.queueIds,
    required this.currentIndex,
    required this.positionMs,
    required this.shuffle,
    required this.repeatMode,
    required this.speed,
  });

  final List<String> queueIds;
  final int currentIndex;
  final int positionMs;
  final bool shuffle;
  final int repeatMode;
  final double speed;
}
