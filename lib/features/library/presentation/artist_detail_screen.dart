import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lumina_player/core/theme/ambient_mesh_background.dart';
import 'package:lumina_player/core/theme/liquid_glass_container.dart';
import 'package:lumina_player/core/theme/spring_pressable.dart';
import 'package:lumina_player/core/theme/track_artwork.dart';
import 'package:lumina_player/features/library/domain/artist.dart';
import 'package:lumina_player/features/library/presentation/track_list_tile.dart';
import 'package:lumina_player/features/player/presentation/player_provider.dart';

class ArtistDetailScreen extends ConsumerWidget {
  const ArtistDetailScreen({super.key, required this.artist});

  final Artist artist;

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
                        ],
                      ),
                      const SizedBox(height: 16),
                      LiquidGlassContainer(
                        borderRadius: 28,
                        padding: const EdgeInsets.all(20),
                        child: Row(
                          children: [
                            TrackArtwork(
                              artworkPath: artist.artworkPath,
                              size: 86,
                              borderRadius: 43,
                              iconSize: 38,
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    artist.name,
                                    style:
                                        Theme.of(context).textTheme.titleLarge,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${artist.albumCount} albums • ${artist.tracks.length} tracks',
                                    style:
                                        Theme.of(context).textTheme.bodySmall,
                                  ),
                                  const SizedBox(height: 12),
                                  SpringPressable(
                                    onTap: () => ref
                                        .read(playerProvider.notifier)
                                        .playQueue(artist.tracks, index: 0),
                                    child: LiquidGlassContainer(
                                      borderRadius: 16,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 8,
                                      ),
                                      tintColor:
                                          Theme.of(context).colorScheme.primary,
                                      tintOpacity: 0.28,
                                      elevationShadow: false,
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.play_arrow_rounded,
                                              size: 20),
                                          SizedBox(width: 4),
                                          Text('Play All'),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverList.builder(
                itemCount: artist.tracks.length,
                itemBuilder: (context, index) {
                  final track = artist.tracks[index];
                  return TrackListTile(
                    track: track,
                    index: index,
                    onTap: () => ref
                        .read(playerProvider.notifier)
                        .playQueue(artist.tracks, index: index),
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
