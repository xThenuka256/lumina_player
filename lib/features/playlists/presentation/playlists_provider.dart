import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lumina_player/core/storage/library_database.dart';
import 'package:lumina_player/features/playlists/domain/playlist.dart';

class PlaylistsNotifier extends Notifier<List<PlaylistModel>> {
  @override
  List<PlaylistModel> build() {
    Future.microtask(load);
    return const [];
  }

  Future<void> load() async {
    final lists = await LibraryDatabase.instance.loadPlaylists();
    state = lists;
  }

  Future<void> createPlaylist(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    final created = PlaylistModel(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: trimmed,
      trackIds: const [],
      createdAtMs: DateTime.now().millisecondsSinceEpoch,
    );
    await LibraryDatabase.instance.createPlaylist(created);
    state = [created, ...state];
  }

  Future<void> renamePlaylist(String playlistId, String newName) async {
    final trimmed = newName.trim();
    if (trimmed.isEmpty) return;
    await LibraryDatabase.instance.renamePlaylist(playlistId, trimmed);
    state = state
        .map((p) => p.id == playlistId ? p.copyWith(name: trimmed) : p)
        .toList();
  }

  Future<void> deletePlaylist(String playlistId) async {
    await LibraryDatabase.instance.deletePlaylist(playlistId);
    state = state.where((p) => p.id != playlistId).toList();
  }

  Future<void> addTrack(String playlistId, String trackId) async {
    final target = state.firstWhere((p) => p.id == playlistId);
    if (target.trackIds.contains(trackId)) return;
    final updatedIds = [...target.trackIds, trackId];
    await LibraryDatabase.instance.setPlaylistTracks(playlistId, updatedIds);
    state = state
        .map((p) => p.id == playlistId ? p.copyWith(trackIds: updatedIds) : p)
        .toList();
  }

  Future<void> removeTrack(String playlistId, String trackId) async {
    final target = state.firstWhere((p) => p.id == playlistId);
    final updatedIds = target.trackIds.where((id) => id != trackId).toList();
    await LibraryDatabase.instance.setPlaylistTracks(playlistId, updatedIds);
    state = state
        .map((p) => p.id == playlistId ? p.copyWith(trackIds: updatedIds) : p)
        .toList();
  }

  Future<void> reorderTrack(
    String playlistId,
    int oldIndex,
    int newIndex,
  ) async {
    final target = state.firstWhere((p) => p.id == playlistId);
    final updatedIds = List<String>.from(target.trackIds);
    final moved = updatedIds.removeAt(oldIndex);
    final dest = newIndex > oldIndex ? newIndex - 1 : newIndex;
    updatedIds.insert(dest, moved);
    await LibraryDatabase.instance.setPlaylistTracks(playlistId, updatedIds);
    state = state
        .map((p) => p.id == playlistId ? p.copyWith(trackIds: updatedIds) : p)
        .toList();
  }
}

final playlistsProvider =
    NotifierProvider<PlaylistsNotifier, List<PlaylistModel>>(
  PlaylistsNotifier.new,
);
