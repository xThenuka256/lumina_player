import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lumina_player/core/permissions/media_permissions_service.dart';
import 'package:lumina_player/core/permissions/permission_glass_card.dart';
import 'package:lumina_player/core/theme/liquid_glass_container.dart';
import 'package:lumina_player/core/theme/spring_pressable.dart';
import 'package:lumina_player/core/theme/track_artwork.dart';
import 'package:lumina_player/features/library/domain/album.dart';
import 'package:lumina_player/features/library/domain/artist.dart';
import 'package:lumina_player/features/library/domain/track.dart';
import 'package:lumina_player/features/library/presentation/album_detail_screen.dart';
import 'package:lumina_player/features/library/presentation/artist_detail_screen.dart';
import 'package:lumina_player/features/library/presentation/library_provider.dart';
import 'package:lumina_player/features/library/presentation/track_list_tile.dart';
import 'package:lumina_player/features/player/presentation/player_provider.dart';
import 'package:lumina_player/features/settings/presentation/settings_provider.dart';

enum LibraryTab { tracks, albums, artists, folders, favorites }

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  LibraryTab _activeTab = LibraryTab.tracks;
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final library = ref.watch(libraryProvider);

    if (library.initialized &&
        library.permissionStatus != MediaPermissionStatus.granted &&
        library.tracks.isEmpty) {
      return PermissionGlassCard(
        status: library.permissionStatus,
        onRequestPermission: () =>
            ref.read(libraryProvider.notifier).requestPermissionAndScan(),
        onOpenSettings: () async {
          await MediaPermissionsService.instance.openSystemAppSettings();
          if (mounted) {
            await ref.read(libraryProvider.notifier).refreshPermissionStatus();
          }
        },
        onPickFolderSaf: () =>
            ref.read(settingsProvider.notifier).pickWatchedFolder(),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
          child: Row(
            children: [
              Text(
                'Library',
                style: Theme.of(context).textTheme.displaySmall,
              ),
              const Spacer(),
              SpringPressable(
                onTap: () => ref.read(libraryProvider.notifier).rescan(),
                child: LiquidGlassContainer(
                  borderRadius: 16,
                  padding: const EdgeInsets.all(10),
                  elevationShadow: false,
                  child: library.isScanning
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh_rounded, size: 20),
                ),
              ),
              const SizedBox(width: 8),
              if (library.filteredTracks.isNotEmpty)
                SpringPressable(
                  onTap: () {
                    final shuffled = [...library.filteredTracks]..shuffle();
                    ref
                        .read(playerProvider.notifier)
                        .playQueue(shuffled, index: 0);
                  },
                  child: LiquidGlassContainer(
                    borderRadius: 16,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    tintColor: Theme.of(context).colorScheme.primary,
                    tintOpacity: 0.25,
                    elevationShadow: false,
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.shuffle_rounded, size: 18),
                        SizedBox(width: 6),
                        Text(
                          'Shuffle',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: LiquidGlassContainer(
            borderRadius: 18,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
            elevationShadow: false,
            child: TextField(
              controller: _searchController,
              onChanged: (v) =>
                  ref.read(libraryProvider.notifier).setSearchQuery(v),
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: 'Search songs, albums, artists...',
                hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
                icon: Icon(
                  Icons.search_rounded,
                  color: Colors.white.withValues(alpha: 0.65),
                ),
                suffixIcon: library.searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          ref
                              .read(libraryProvider.notifier)
                              .setSearchQuery('');
                        },
                      )
                    : null,
              ),
            ),
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
          child: Row(
            children: LibraryTab.values.map((tab) {
              final selected = tab == _activeTab;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: SpringPressable(
                  haptics: false,
                  onTap: () => setState(() => _activeTab = tab),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      color: selected
                          ? Theme.of(context)
                              .colorScheme
                              .primary
                              .withValues(alpha: 0.28)
                          : Colors.white.withValues(alpha: 0.08),
                      border: Border.all(
                        color: selected
                            ? Theme.of(context)
                                .colorScheme
                                .primary
                                .withValues(alpha: 0.7)
                            : Colors.white.withValues(alpha: 0.14),
                      ),
                    ),
                    child: Text(
                      _tabLabel(tab),
                      style: TextStyle(
                        fontWeight:
                            selected ? FontWeight.w700 : FontWeight.w500,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 260),
            child: _buildTabBody(context, library),
          ),
        ),
      ],
    );
  }

  String _tabLabel(LibraryTab tab) => switch (tab) {
        LibraryTab.tracks => 'Tracks',
        LibraryTab.albums => 'Albums',
        LibraryTab.artists => 'Artists',
        LibraryTab.folders => 'Folders',
        LibraryTab.favorites => 'Favorites',
      };

  Widget _buildTabBody(BuildContext context, LibraryState library) {
    if (library.tracks.isEmpty && !library.isScanning) {
      return Center(
        key: const ValueKey('empty_library'),
        child: LiquidGlassContainer(
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.music_off_rounded, size: 44),
              const SizedBox(height: 12),
              Text(
                'No local music found',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 6),
              Text(
                'Add a music folder in Settings or place audio files (.mp3, .flac, .wav, .ogg, .m4a) in your Music directory.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              SpringPressable(
                onTap: () =>
                    ref.read(settingsProvider.notifier).pickWatchedFolder(),
                child: LiquidGlassContainer(
                  borderRadius: 16,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 10,
                  ),
                  tintColor: Theme.of(context).colorScheme.primary,
                  tintOpacity: 0.28,
                  elevationShadow: false,
                  child: const Text('Add Music Folder'),
                ),
              ),
            ],
          ),
        ),
      );
    }

    switch (_activeTab) {
      case LibraryTab.tracks:
        return _TracksList(
          key: const ValueKey('tab_tracks'),
          tracks: library.filteredTracks,
        );
      case LibraryTab.favorites:
        return _TracksList(
          key: const ValueKey('tab_favorites'),
          tracks: library.favoriteTracks,
          emptyMessage: 'Tap the heart icon on any track to favorite it.',
        );
      case LibraryTab.albums:
        return _AlbumsGrid(
          key: const ValueKey('tab_albums'),
          albums: library.albums,
        );
      case LibraryTab.artists:
        return _ArtistsList(
          key: const ValueKey('tab_artists'),
          artists: library.artists,
        );
      case LibraryTab.folders:
        return _FoldersList(
          key: const ValueKey('tab_folders'),
          folders: library.folders,
        );
    }
  }
}

class _TracksList extends ConsumerWidget {
  const _TracksList({
    super.key,
    required this.tracks,
    this.emptyMessage = 'No matching tracks',
  });

  final List<Track> tracks;
  final String emptyMessage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (tracks.isEmpty) {
      return Center(
        child: Text(emptyMessage, style: Theme.of(context).textTheme.bodyMedium),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 140),
      itemCount: tracks.length,
      itemBuilder: (context, index) {
        final track = tracks[index];
        return TrackListTile(
          track: track,
          index: index,
          onTap: () => ref
              .read(playerProvider.notifier)
              .playQueue(tracks, index: index),
        );
      },
    );
  }
}

class _AlbumsGrid extends StatelessWidget {
  const _AlbumsGrid({super.key, required this.albums});

  final List<Album> albums;

  @override
  Widget build(BuildContext context) {
    if (albums.isEmpty) {
      return const Center(child: Text('No matching albums'));
    }
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 140),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 205,
        childAspectRatio: 0.80,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
      ),
      itemCount: albums.length,
      itemBuilder: (context, index) {
        final album = albums[index];
        return SpringPressable(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => AlbumDetailScreen(album: album),
            ),
          ),
          child: LiquidGlassContainer(
            borderRadius: 22,
            padding: const EdgeInsets.all(10),
            elevationShadow: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: SizedBox(
                    width: double.infinity,
                    child: Hero(
                      tag: 'album_${album.name}_${album.artist}',
                      child: TrackArtwork(
                        artworkPath: album.artworkPath,
                        size: 160,
                        borderRadius: 16,
                        iconSize: 42,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  album.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                Text(
                  '${album.artist} • ${album.tracks.length}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ArtistsList extends StatelessWidget {
  const _ArtistsList({super.key, required this.artists});

  final List<Artist> artists;

  @override
  Widget build(BuildContext context) {
    if (artists.isEmpty) {
      return const Center(child: Text('No matching artists'));
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 140),
      itemCount: artists.length,
      itemBuilder: (context, index) {
        final artist = artists[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: SpringPressable(
            pressedScale: 0.985,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => ArtistDetailScreen(artist: artist),
              ),
            ),
            child: LiquidGlassContainer(
              borderRadius: 18,
              padding: const EdgeInsets.all(12),
              elevationShadow: false,
              child: Row(
                children: [
                  TrackArtwork(
                    artworkPath: artist.artworkPath,
                    size: 52,
                    borderRadius: 26,
                    iconSize: 24,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          artist.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${artist.albumCount} albums • ${artist.tracks.length} tracks',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _FoldersList extends ConsumerWidget {
  const _FoldersList({super.key, required this.folders});

  final Map<String, List<Track>> folders;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = folders.entries.toList();
    if (entries.isEmpty) {
      return const Center(child: Text('No folders indexed'));
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 140),
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final entry = entries[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: SpringPressable(
            pressedScale: 0.985,
            onTap: () => ref
                .read(playerProvider.notifier)
                .playQueue(entry.value, index: 0),
            child: LiquidGlassContainer(
              borderRadius: 18,
              padding: const EdgeInsets.all(14),
              elevationShadow: false,
              child: Row(
                children: [
                  const Icon(Icons.folder_rounded, size: 30),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry.key.split('/').last.isEmpty
                              ? entry.key
                              : entry.key.split('/').last,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                        Text(
                          '${entry.key} • ${entry.value.length} tracks',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.play_circle_outline_rounded),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
