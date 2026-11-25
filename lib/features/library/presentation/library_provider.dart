import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lumina_player/core/permissions/media_permissions_service.dart';
import 'package:lumina_player/core/storage/library_database.dart';
import 'package:lumina_player/features/library/data/library_scanner.dart';
import 'package:lumina_player/features/library/domain/album.dart';
import 'package:lumina_player/features/library/domain/artist.dart';
import 'package:lumina_player/features/library/domain/track.dart';
import 'package:lumina_player/features/player/presentation/player_provider.dart';

class LibraryState {
  const LibraryState({
    this.tracks = const [],
    this.searchQuery = '',
    this.isScanning = false,
    this.permissionStatus = MediaPermissionStatus.granted,
    this.initialized = false,
  });

  final List<Track> tracks;
  final String searchQuery;
  final bool isScanning;
  final MediaPermissionStatus permissionStatus;
  final bool initialized;

  List<Track> get filteredTracks {
    if (searchQuery.trim().isEmpty) return tracks;
    final q = searchQuery.toLowerCase().trim();
    return tracks.where((t) {
      return t.title.toLowerCase().contains(q) ||
          t.artist.toLowerCase().contains(q) ||
          t.album.toLowerCase().contains(q);
    }).toList();
  }

  List<Track> get favoriteTracks =>
      filteredTracks.where((t) => t.isFavorite).toList();

  List<Album> get albums {
    final map = <String, List<Track>>{};
    for (final t in filteredTracks) {
      final key = '${t.album}::${t.albumArtist}';
      map.putIfAbsent(key, () => []).add(t);
    }
    final list = map.values.map((group) {
      group.sort((a, b) => a.trackNumber.compareTo(b.trackNumber));
      final first = group.first;
      final art = group
          .map((e) => e.artworkPath)
          .firstWhere((e) => e != null && e.isNotEmpty, orElse: () => null);
      return Album(
        name: first.album,
        artist: first.albumArtist,
        tracks: group,
        artworkPath: art,
      );
    }).toList();
    list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return list;
  }

  List<Artist> get artists {
    final map = <String, List<Track>>{};
    for (final t in filteredTracks) {
      map.putIfAbsent(t.artist, () => []).add(t);
    }
    final list = map.entries.map((entry) {
      final albumNames = entry.value.map((e) => e.album).toSet();
      final art = entry.value
          .map((e) => e.artworkPath)
          .firstWhere((e) => e != null && e.isNotEmpty, orElse: () => null);
      return Artist(
        name: entry.key,
        tracks: entry.value,
        albumCount: albumNames.length,
        artworkPath: art,
      );
    }).toList();
    list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return list;
  }

  Map<String, List<Track>> get folders {
    final map = <String, List<Track>>{};
    for (final t in filteredTracks) {
      final folder = t.folderPath.isEmpty ? 'Device Audio' : t.folderPath;
      map.putIfAbsent(folder, () => []).add(t);
    }
    return Map.fromEntries(
      map.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
    );
  }

  LibraryState copyWith({
    List<Track>? tracks,
    String? searchQuery,
    bool? isScanning,
    MediaPermissionStatus? permissionStatus,
    bool? initialized,
  }) {
    return LibraryState(
      tracks: tracks ?? this.tracks,
      searchQuery: searchQuery ?? this.searchQuery,
      isScanning: isScanning ?? this.isScanning,
      permissionStatus: permissionStatus ?? this.permissionStatus,
      initialized: initialized ?? this.initialized,
    );
  }
}

class LibraryNotifier extends Notifier<LibraryState> {
  @override
  LibraryState build() {
    Future.microtask(initialize);
    return const LibraryState();
  }

  Future<void> initialize() async {
    final db = LibraryDatabase.instance;
    final cached = await db.loadTracks();
    final perm = await MediaPermissionsService.instance.checkMediaPermission();

    state = state.copyWith(
      tracks: cached,
      permissionStatus: perm,
      initialized: true,
    );

    if (cached.isNotEmpty) {
      await ref.read(audioHandlerProvider).restoreLastSession(cached);
    }

    if (perm == MediaPermissionStatus.granted) {
      await rescan();
    }
  }

  Future<void> requestPermissionAndScan() async {
    final status =
        await MediaPermissionsService.instance.requestMediaPermission();
    state = state.copyWith(permissionStatus: status);
    if (status == MediaPermissionStatus.granted) {
      await rescan();
    }
  }

  Future<void> refreshPermissionStatus() async {
    final status =
        await MediaPermissionsService.instance.checkMediaPermission();
    state = state.copyWith(permissionStatus: status);
    if (status == MediaPermissionStatus.granted) {
      await rescan();
    }
  }

  Future<void> rescan() async {
    if (state.isScanning) return;
    state = state.copyWith(isScanning: true);
    try {
      final scanned = await LibraryScanner.instance.scanLibrary();
      state = state.copyWith(tracks: scanned, isScanning: false);
    } catch (_) {
      state = state.copyWith(isScanning: false);
    }
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  Future<void> toggleFavorite(Track track) async {
    final nextVal = !track.isFavorite;
    await LibraryDatabase.instance.setTrackFavorite(track.id, nextVal);
    final updated = state.tracks
        .map((t) => t.id == track.id ? t.copyWith(isFavorite: nextVal) : t)
        .toList();
    state = state.copyWith(tracks: updated);
  }
}

final libraryProvider = NotifierProvider<LibraryNotifier, LibraryState>(
  LibraryNotifier.new,
);
