import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lumina_player/core/theme/ambient_mesh_background.dart';
import 'package:lumina_player/core/theme/liquid_glass_container.dart';
import 'package:lumina_player/core/theme/spring_pressable.dart';
import 'package:lumina_player/features/library/domain/track.dart';
import 'package:lumina_player/features/library/presentation/library_provider.dart';
import 'package:lumina_player/features/library/presentation/track_list_tile.dart';
import 'package:lumina_player/features/player/presentation/player_provider.dart';
import 'package:lumina_player/features/playlists/presentation/playlists_provider.dart';

class PlaylistDetailScreen extends ConsumerWidget {
  const PlaylistDetailScreen({super.key, required this.playlistId});

  final String playlistId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playlists = ref.watch(playlistsProvider);
    final matches = playlists.where((p) => p.id == playlistId);
    final playlist = matches.isEmpty ? null : matches.first;
    final libraryTracks = ref.watch(libraryProvider).tracks;
    final palette = ref.watch(playerProvider).palette;

    if (playlist == null) {
      return const Scaffold(body: Center(child: Text('Playlist deleted')));
    }

    final trackMap = {for (final t in libraryTracks) t.id: t};
    final resolvedTracks = <Track>[
      for (final id in playlist.trackIds)
        if (trackMap[id] != null) trackMap[id]!,
    ];

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AmbientMeshBackground(
        primaryColor: palette.primary,
        secondaryColor: palette.secondary,
        tertiaryColor: palette.tertiary,
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                child: Row(
                  children: [
                    SpringPressable(
                      onTap: () => Navigator.of(context).pop(),
                      child: const LiquidGlassContainer(
                        borderRadius: 16,
                        padding: EdgeInsets.all(10),
                        elevationShadow: false,
                        child: Icon(Icons.arrow_back_rounded),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            playlist.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          Text(
                            '${resolvedTracks.length} tracks',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    SpringPressable(
                      onTap: () => _showAddTracksSheet(
                        context,
                        ref,
                        libraryTracks,
                        playlist.trackIds.toSet(),
                      ),
                      child: const LiquidGlassContainer(
                        borderRadius: 16,
                        padding: EdgeInsets.all(10),
                        elevationShadow: false,
                        child: Icon(Icons.add_rounded),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (resolvedTracks.isNotEmpty)
                      SpringPressable(
                        onTap: () => ref
                            .read(playerProvider.notifier)
                            .playQueue(resolvedTracks, index: 0),
                        child: LiquidGlassContainer(
                          borderRadius: 16,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          tintColor: Theme.of(context).colorScheme.primary,
                          tintOpacity: 0.28,
                          elevationShadow: false,
                          child: const Icon(Icons.play_arrow_rounded),
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: resolvedTracks.isEmpty
                    ? Center(
                        child: Text(
                          'Tap + to add tracks to this playlist',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      )
                    : ReorderableListView.builder(
                        padding: const EdgeInsets.only(bottom: 120),
                        itemCount: resolvedTracks.length,
                        onReorder: (oldIndex, newIndex) {
                          ref
                              .read(playlistsProvider.notifier)
                              .reorderTrack(playlist.id, oldIndex, newIndex);
                        },
                        itemBuilder: (context, index) {
                          final track = resolvedTracks[index];
                          return Dismissible(
                            key: ValueKey('pl_${playlist.id}_${track.id}'),
                            direction: DismissDirection.endToStart,
                            onDismissed: (_) {
                              ref
                                  .read(playlistsProvider.notifier)
                                  .removeTrack(playlist.id, track.id);
                            },
                            child: TrackListTile(
                              track: track,
                              index: index,
                              onTap: () => ref
                                  .read(playerProvider.notifier)
                                  .playQueue(resolvedTracks, index: index),
                              trailingExtra: const Icon(
                                Icons.drag_handle_rounded,
                                size: 20,
                                color: Colors.white54,
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddTracksSheet(
    BuildContext context,
    WidgetRef ref,
    List<Track> allTracks,
    Set<String> existingIds,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.72,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: LiquidGlassContainer(
            borderRadius: 26,
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Text(
                  'Add Songs',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView.builder(
                    itemCount: allTracks.length,
                    itemBuilder: (context, i) {
                      final t = allTracks[i];
                      final added = existingIds.contains(t.id);
                      return ListTile(
                        title: Text(
                          t.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          t.artist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: Icon(
                          added
                              ? Icons.check_circle_rounded
                              : Icons.add_circle_outline_rounded,
                          color: added
                              ? Theme.of(context).colorScheme.primary
                              : Colors.white70,
                        ),
                        onTap: () {
                          if (!added) {
                            ref
                                .read(playlistsProvider.notifier)
                                .addTrack(playlistId, t.id);
                            Navigator.of(context).pop();
                          }
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
