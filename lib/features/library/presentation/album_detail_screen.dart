import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lumina_player/core/theme/ambient_mesh_background.dart';
import 'package:lumina_player/core/theme/liquid_glass_container.dart';
import 'package:lumina_player/core/theme/spring_pressable.dart';
import 'package:lumina_player/core/theme/track_artwork.dart';
import 'package:lumina_player/features/library/domain/album.dart';
import 'package:lumina_player/features/library/presentation/track_list_tile.dart';
import 'package:lumina_player/features/player/presentation/player_provider.dart';

class AlbumDetailScreen extends ConsumerWidget {
  const AlbumDetailScreen({super.key, required this.album});

  final Album album;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(playerProvider).palette;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AmbientMeshBackground(
        primaryColor: palette.primary,
        secondaryColor: palette.secondary,
        tertiaryColor: palette.tertiary,
        child: SafeArea(
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                  child: Column(
                    children: [
                      Row(
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
                          const Spacer(),
                        ],
                      ),
                      const SizedBox(height: 16),
                      LiquidGlassContainer(
                        borderRadius: 28,
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            Hero(
                              tag: 'album_${album.name}_${album.artist}',
                              child: TrackArtwork(
                                artworkPath: album.artworkPath,
                                size: 180,
                                borderRadius: 22,
                                iconSize: 64,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              album.name,
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.headlineMedium,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${album.artist} • ${album.tracks.length} tracks',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SpringPressable(
                                  onTap: () => ref
                                      .read(playerProvider.notifier)
                                      .playQueue(album.tracks, index: 0),
                                  child: LiquidGlassContainer(
                                    borderRadius: 18,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 22,
                                      vertical: 11,
                                    ),
                                    tintColor:
                                        Theme.of(context).colorScheme.primary,
                                    tintOpacity: 0.30,
                                    elevationShadow: false,
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.play_arrow_rounded),
                                        SizedBox(width: 6),
                                        Text(
                                          'Play Album',
                                          style: TextStyle(
                                              fontWeight: FontWeight.w600),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                SpringPressable(
                                  onTap: () {
                                    final shuffled = [...album.tracks]..shuffle();
                                    ref
                                        .read(playerProvider.notifier)
                                        .playQueue(shuffled, index: 0);
                                  },
                                  child: const LiquidGlassContainer(
                                    borderRadius: 18,
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 18,
                                      vertical: 11,
                                    ),
                                    elevationShadow: false,
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.shuffle_rounded, size: 20),
                                        SizedBox(width: 6),
                                        Text('Shuffle'),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverList.builder(
                itemCount: album.tracks.length,
                itemBuilder: (context, index) {
                  final track = album.tracks[index];
                  return TrackListTile(
                    track: track,
                    index: index,
                    onTap: () => ref
                        .read(playerProvider.notifier)
                        .playQueue(album.tracks, index: index),
                  );
                },
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 110)),
            ],
          ),
        ),
      ),
    );
  }
}
