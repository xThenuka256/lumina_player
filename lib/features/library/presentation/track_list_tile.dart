import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lumina_player/core/theme/equalizer_bars.dart';
import 'package:lumina_player/core/theme/liquid_glass_container.dart';
import 'package:lumina_player/core/theme/spring_pressable.dart';
import 'package:lumina_player/core/theme/track_artwork.dart';
import 'package:lumina_player/features/library/domain/track.dart';
import 'package:lumina_player/features/library/presentation/library_provider.dart';
import 'package:lumina_player/features/player/presentation/player_provider.dart';
import 'package:lumina_player/features/playlists/presentation/playlists_provider.dart';

/// Staggered-entrance track row with active equalizer indicator, favorite
/// toggle, and quick "Add to Playlist" action sheet.
class TrackListTile extends ConsumerWidget {
  const TrackListTile({
    super.key,
    required this.track,
    required this.index,
    required this.onTap,
    this.trailingExtra,
  });

  final Track track;
  final int index;
  final VoidCallback onTap;
  final Widget? trailingExtra;

  String _formatDuration(Duration d) {
    if (d <= Duration.zero) return '--:--';
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final player = ref.watch(playerProvider);
    final isCurrent = player.currentTrack?.id == track.id;
    final delayFactor = (index.clamp(0, 10) * 28);

    return TweenAnimationBuilder<double>(
      key: ValueKey('anim_${track.id}_$index'),
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 260 + delayFactor),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, (1 - value) * 14),
            child: child,
          ),
        );
      },
      child: SpringPressable(
        pressedScale: 0.985,
        haptics: false,
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            color: isCurrent
                ? Colors.white.withValues(alpha: 0.14)
                : Colors.white.withValues(alpha: 0.04),
            border: Border.all(
              color: isCurrent
                  ? Theme.of(context)
                      .colorScheme
                      .primary
                      .withValues(alpha: 0.48)
                  : Colors.white.withValues(alpha: 0.08),
            ),
          ),
          child: Row(
            children: [
              TrackArtwork(
                artworkPath: track.artworkPath,
                size: 48,
                borderRadius: 12,
                iconSize: 22,
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
                      style: TextStyle(
                        fontWeight:
                            isCurrent ? FontWeight.w700 : FontWeight.w600,
                        fontSize: 15,
                        color: isCurrent
                            ? Theme.of(context).colorScheme.primary
                            : Colors.white,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${track.artist} • ${track.album}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (isCurrent) ...[
                EqualizerBars(isPlaying: player.isPlaying, size: 16),
                const SizedBox(width: 10),
              ] else ...[
                Text(
                  _formatDuration(track.duration),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(width: 4),
              ],
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: () =>
                    ref.read(libraryProvider.notifier).toggleFavorite(track),
                icon: Icon(
                  track.isFavorite
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  size: 19,
                  color: track.isFavorite
                      ? Colors.pinkAccent
                      : Colors.white.withValues(alpha: 0.55),
                ),
              ),
              trailingExtra ??
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    onPressed: () => _showAddToPlaylistSheet(context, ref),
                    icon: Icon(
                      Icons.more_vert_rounded,
                      size: 19,
                      color: Colors.white.withValues(alpha: 0.65),
                    ),
                  ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddToPlaylistSheet(BuildContext context, WidgetRef ref) {
    final playlists = ref.read(playlistsProvider);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Padding(
        padding: const EdgeInsets.all(16),
        child: LiquidGlassContainer(
          borderRadius: 24,
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Add "${track.title}" to Playlist',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 14),
              if (playlists.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'No playlists yet. Create one from the Playlists tab!',
                  ),
                )
              else
                ...playlists.map(
                  (pl) => ListTile(
                    leading: const Icon(Icons.playlist_add_rounded),
                    title: Text(pl.name),
                    subtitle: Text('${pl.trackIds.length} tracks'),
                    onTap: () {
                      ref
                          .read(playlistsProvider.notifier)
                          .addTrack(pl.id, track.id);
                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Added to ${pl.name}')),
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
}
