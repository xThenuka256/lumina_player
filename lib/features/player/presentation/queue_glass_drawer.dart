import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lumina_player/core/theme/equalizer_bars.dart';
import 'package:lumina_player/core/theme/liquid_glass_container.dart';
import 'package:lumina_player/core/theme/track_artwork.dart';
import 'package:lumina_player/features/player/presentation/player_provider.dart';

/// Reorderable "Up Next" Liquid Glass drawer supporting drag reorder and
/// swipe-to-remove.
class QueueGlassDrawer extends ConsumerWidget {
  const QueueGlassDrawer({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const QueueGlassDrawer(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerState = ref.watch(playerProvider);
    final queue = playerState.queue;
    final currentIndex = playerState.currentIndex;

    return FractionallySizedBox(
      heightFactor: 0.78,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: LiquidGlassContainer(
          borderRadius: 28,
          blurSigma: 30,
          tintOpacity: 0.14,
          padding: const EdgeInsets.only(top: 12),
          child: Column(
            children: [
              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.32),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Up Next',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        Text(
                          '${queue.length} tracks in queue',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: Colors.white12),
              Expanded(
                child: queue.isEmpty
                    ? Center(
                        child: Text(
                          'Queue is empty',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      )
                    : ReorderableListView.builder(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        buildDefaultDragHandles: false,
                        itemCount: queue.length,
                        onReorder: (oldIndex, newIndex) {
                          ref
                              .read(playerProvider.notifier)
                              .reorderQueue(oldIndex, newIndex);
                        },
                        itemBuilder: (context, index) {
                          final track = queue[index];
                          final isCurrent = index == currentIndex;
                          return Dismissible(
                            key: ValueKey('q_${track.id}_$index'),
                            direction: DismissDirection.endToStart,
                            onDismissed: (_) {
                              ref
                                  .read(playerProvider.notifier)
                                  .removeFromQueue(index);
                            },
                            background: Container(
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              padding: const EdgeInsets.only(right: 20),
                              alignment: Alignment.centerRight,
                              decoration: BoxDecoration(
                                color: Colors.redAccent.withValues(alpha: 0.35),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Icon(
                                Icons.delete_outline_rounded,
                                color: Colors.white,
                              ),
                            ),
                            child: Container(
                              margin: const EdgeInsets.symmetric(vertical: 3),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                color: isCurrent
                                    ? Colors.white.withValues(alpha: 0.12)
                                    : Colors.transparent,
                              ),
                              child: ListTile(
                                onTap: () {
                                  ref
                                      .read(playerProvider.notifier)
                                      .jumpTo(index);
                                },
                                leading: TrackArtwork(
                                  artworkPath: track.artworkPath,
                                  size: 44,
                                  borderRadius: 10,
                                  iconSize: 20,
                                ),
                                title: Text(
                                  track.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontWeight: isCurrent
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    color: isCurrent
                                        ? Theme.of(context).colorScheme.primary
                                        : Colors.white,
                                  ),
                                ),
                                subtitle: Text(
                                  '${track.artist} • ${track.album}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (isCurrent) ...[
                                      EqualizerBars(
                                        isPlaying: playerState.isPlaying,
                                        size: 16,
                                      ),
                                      const SizedBox(width: 10),
                                    ],
                                    ReorderableDragStartListener(
                                      index: index,
                                      child: Icon(
                                        Icons.drag_handle_rounded,
                                        color: Colors.white.withValues(alpha: 0.5),
                                      ),
                                    ),
                                  ],
                                ),
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
}
