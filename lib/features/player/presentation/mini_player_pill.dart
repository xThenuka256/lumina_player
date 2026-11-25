import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lumina_player/core/theme/liquid_glass_container.dart';
import 'package:lumina_player/core/theme/spring_pressable.dart';
import 'package:lumina_player/core/theme/track_artwork.dart';
import 'package:lumina_player/features/player/presentation/now_playing_screen.dart';
import 'package:lumina_player/features/player/presentation/player_provider.dart';

/// Floating Liquid Glass mini-player pill that seamlessly morphs via Hero into
/// [NowPlayingScreen] when tapped.
class MiniPlayerPill extends ConsumerWidget {
  const MiniPlayerPill({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final player = ref.watch(playerProvider);
    final track = player.currentTrack;
    if (track == null) return const SizedBox.shrink();

    final progress = player.duration.inMilliseconds > 0
        ? (player.position.inMilliseconds / player.duration.inMilliseconds)
            .clamp(0.0, 1.0)
        : 0.0;

    return SpringPressable(
      pressedScale: 0.98,
      haptics: false,
      onTap: () => Navigator.of(context).push(NowPlayingScreen.route()),
      child: LiquidGlassContainer(
        borderRadius: 22,
        blurSigma: 26,
        tintOpacity: 0.16,
        padding: const EdgeInsets.fromLTRB(10, 8, 12, 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Hero(
                  tag: 'now_playing_art',
                  child: TrackArtwork(
                    artworkPath: track.artworkPath,
                    size: 46,
                    borderRadius: 13,
                    iconSize: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        track.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        track.artist,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                SpringPressable(
                  onTap: () =>
                      ref.read(playerProvider.notifier).togglePlayPause(),
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Icon(
                      player.isPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      size: 28,
                    ),
                  ),
                ),
                SpringPressable(
                  onTap: () => ref.read(playerProvider.notifier).next(),
                  child: const Padding(
                    padding: EdgeInsets.all(8),
                    child: Icon(Icons.skip_next_rounded, size: 26),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 2.5,
                backgroundColor: Colors.white.withValues(alpha: 0.12),
                valueColor: AlwaysStoppedAnimation(player.palette.primary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
