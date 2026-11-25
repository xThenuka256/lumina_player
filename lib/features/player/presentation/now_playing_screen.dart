import 'dart:math' as math;
import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lumina_player/core/audio/sleep_timer_controller.dart';
import 'package:lumina_player/core/theme/ambient_mesh_background.dart';
import 'package:lumina_player/core/theme/liquid_glass_container.dart';
import 'package:lumina_player/core/theme/spring_pressable.dart';
import 'package:lumina_player/core/theme/track_artwork.dart';
import 'package:lumina_player/features/library/domain/track.dart';
import 'package:lumina_player/features/library/presentation/library_provider.dart';
import 'package:lumina_player/features/player/presentation/player_provider.dart';
import 'package:lumina_player/features/player/presentation/queue_glass_drawer.dart';
import 'package:lumina_player/features/player/presentation/waveform_scrubber.dart';

enum _ArtworkMode { card, vinyl }

/// Full-screen Liquid Glass Now Playing experience with Hero transition,
/// interactive 3D tilt/parallax artwork, Vinyl/Wave mode, waveform scrubbing,
/// speed control, sleep timer, and reorderable queue drawer.
class NowPlayingScreen extends ConsumerStatefulWidget {
  const NowPlayingScreen({super.key});

  static PageRoute<void> route() {
    return PageRouteBuilder<void>(
      opaque: false,
      transitionDuration: const Duration(milliseconds: 520),
      reverseTransitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (_, __, ___) => const NowPlayingScreen(),
      transitionsBuilder: (_, animation, __, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutBack,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.14),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  @override
  ConsumerState<NowPlayingScreen> createState() => _NowPlayingScreenState();
}

class _NowPlayingScreenState extends ConsumerState<NowPlayingScreen>
    with TickerProviderStateMixin {
  _ArtworkMode _artworkMode = _ArtworkMode.card;
  Offset _tilt = Offset.zero;
  late final AnimationController _vinylController;
  late final AnimationController _glowController;

  @override
  void initState() {
    super.initState();
    _vinylController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    );
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _vinylController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  void _syncAnimationState(bool isPlaying) {
    if (isPlaying && _artworkMode == _ArtworkMode.vinyl) {
      if (!_vinylController.isAnimating) _vinylController.repeat();
    } else {
      if (_vinylController.isAnimating) _vinylController.stop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final player = ref.watch(playerProvider);
    final library = ref.watch(libraryProvider);
    final sleepTimer = ref.watch(sleepTimerProvider);

    final track = player.currentTrack;
    _syncAnimationState(player.isPlaying);

    // Reflect latest favorite state from library if available
    final Track? liveTrack = track == null
        ? null
        : library.tracks.firstWhere(
            (t) => t.id == track.id,
            orElse: () => track,
          );

    return Dismissible(
      key: const ValueKey('now_playing_dismiss'),
      direction: DismissDirection.down,
      onDismissed: (_) => Navigator.of(context).pop(),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: AmbientMeshBackground(
          primaryColor: player.palette.primary,
          secondaryColor: player.palette.secondary,
          tertiaryColor: player.palette.tertiary,
          child: SafeArea(
            child: liveTrack == null
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Nothing playing right now'),
                        const SizedBox(height: 14),
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Back to Library'),
                        ),
                      ],
                    ),
                  )
                : LayoutBuilder(
                    builder: (context, constraints) {
                      final isWide = constraints.maxWidth >= 820;
                      return Column(
                        children: [
                          _buildTopBar(context, sleepTimer),
                          Expanded(
                            child: isWide
                                ? Row(
                                    children: [
                                      Expanded(
                                        child: Center(
                                          child: _buildArtworkStage(
                                            liveTrack,
                                            player,
                                            math.min(
                                              constraints.maxHeight * 0.62,
                                              360,
                                            ),
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        child: Padding(
                                          padding: const EdgeInsets.fromLTRB(
                                            16,
                                            16,
                                            40,
                                            24,
                                          ),
                                          child: _buildControlsColumn(
                                            context,
                                            liveTrack,
                                            player,
                                            sleepTimer,
                                          ),
                                        ),
                                      ),
                                    ],
                                  )
                                : SingleChildScrollView(
                                    padding: const EdgeInsets.fromLTRB(
                                      24,
                                      8,
                                      24,
                                      24,
                                    ),
                                    child: Column(
                                      children: [
                                        const SizedBox(height: 8),
                                        _buildArtworkStage(
                                          liveTrack,
                                          player,
                                          math.min(
                                            constraints.maxWidth - 64,
                                            320,
                                          ),
                                        ),
                                        const SizedBox(height: 28),
                                        _buildControlsColumn(
                                          context,
                                          liveTrack,
                                          player,
                                          sleepTimer,
                                        ),
                                      ],
                                    ),
                                  ),
                          ),
                        ],
                      );
                    },
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context, SleepTimerState sleepTimer) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          SpringPressable(
            onTap: () => Navigator.of(context).pop(),
            child: LiquidGlassContainer(
              borderRadius: 16,
              padding: const EdgeInsets.all(10),
              elevationShadow: false,
              child: const Icon(Icons.keyboard_arrow_down_rounded, size: 24),
            ),
          ),
          const Spacer(),
          SpringPressable(
            onTap: () {
              setState(() {
                _artworkMode = _artworkMode == _ArtworkMode.card
                    ? _ArtworkMode.vinyl
                    : _ArtworkMode.card;
              });
            },
            child: LiquidGlassContainer(
              borderRadius: 18,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              elevationShadow: false,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _artworkMode == _ArtworkMode.vinyl
                        ? Icons.album_rounded
                        : Icons.graphic_eq_rounded,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _artworkMode == _ArtworkMode.vinyl ? 'Vinyl' : 'Wave',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          SpringPressable(
            onTap: () => QueueGlassDrawer.show(context),
            child: LiquidGlassContainer(
              borderRadius: 16,
              padding: const EdgeInsets.all(10),
              elevationShadow: false,
              child: const Icon(Icons.queue_music_rounded, size: 22),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildArtworkStage(
    Track track,
    PlayerUiState player,
    double artSize,
  ) {
    return MouseRegion(
      onHover: (event) {
        final nx = ((event.localPosition.dx / artSize) - 0.5) * 2;
        final ny = ((event.localPosition.dy / artSize) - 0.5) * 2;
        setState(() => _tilt = Offset(nx.clamp(-1, 1), ny.clamp(-1, 1)));
      },
      onExit: (_) => setState(() => _tilt = Offset.zero),
      child: GestureDetector(
        onPanUpdate: (details) {
          final nx = ((details.localPosition.dx / artSize) - 0.5) * 2;
          final ny = ((details.localPosition.dy / artSize) - 0.5) * 2;
          setState(() => _tilt = Offset(nx.clamp(-1, 1), ny.clamp(-1, 1)));
        },
        onPanEnd: (_) => setState(() => _tilt = Offset.zero),
        child: TweenAnimationBuilder<Offset>(
          tween: Tween(end: _tilt),
          duration: const Duration(milliseconds: 180),
          builder: (context, tilt, child) {
            final matrix = Matrix4.identity()
              ..setEntry(3, 2, 0.0012)
              ..rotateX(-tilt.dy * 0.14)
              ..rotateY(tilt.dx * 0.14);
            return Transform(
              alignment: Alignment.center,
              transform: matrix,
              child: child,
            );
          },
          child: AnimatedBuilder(
            animation: _glowController,
            builder: (context, _) {
              final pulse =
                  player.isPlaying ? (0.45 + 0.35 * _glowController.value) : 0.2;
              return Container(
                width: artSize + 18,
                height: artSize + 18,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: _artworkMode == _ArtworkMode.vinyl
                      ? BoxShape.circle
                      : BoxShape.rectangle,
                  borderRadius: _artworkMode == _ArtworkMode.vinyl
                      ? null
                      : BorderRadius.circular(34),
                  boxShadow: [
                    BoxShadow(
                      color: player.palette.primary.withValues(alpha: pulse),
                      blurRadius: 48,
                      spreadRadius: 2,
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.45),
                      blurRadius: 34,
                      offset: const Offset(0, 18),
                    ),
                  ],
                ),
                child: _artworkMode == _ArtworkMode.vinyl
                    ? RotationTransition(
                        turns: _vinylController,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Container(
                              width: artSize,
                              height: artSize,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: SweepGradient(
                                  colors: [
                                    Colors.black87,
                                    Colors.white.withValues(alpha: 0.12),
                                    Colors.black87,
                                    Colors.white.withValues(alpha: 0.10),
                                    Colors.black87,
                                  ],
                                ),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.25),
                                  width: 2,
                                ),
                              ),
                            ),
                            Hero(
                              tag: 'now_playing_art',
                              child: TrackArtwork(
                                artworkPath: track.artworkPath,
                                size: artSize * 0.72,
                                borderRadius: artSize,
                                iconSize: 56,
                              ),
                            ),
                            Container(
                              width: 26,
                              height: 26,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.black,
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.45),
                                  width: 2,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    : Hero(
                        tag: 'now_playing_art',
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(28),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.34),
                              width: 1.2,
                            ),
                          ),
                          child: TrackArtwork(
                            artworkPath: track.artworkPath,
                            size: artSize,
                            borderRadius: 27,
                            iconSize: 72,
                          ),
                        ),
                      ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildControlsColumn(
    BuildContext context,
    Track track,
    PlayerUiState player,
    SleepTimerState sleepTimer,
  ) {
    final notifier = ref.read(playerProvider.notifier);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    track.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${track.artist} — ${track.album}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withValues(alpha: 0.78),
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            SpringPressable(
              onTap: () =>
                  ref.read(libraryProvider.notifier).toggleFavorite(track),
              child: LiquidGlassContainer(
                borderRadius: 18,
                padding: const EdgeInsets.all(11),
                elevationShadow: false,
                child: Icon(
                  track.isFavorite
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  color: track.isFavorite
                      ? Colors.pinkAccent
                      : Colors.white.withValues(alpha: 0.85),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        WaveformScrubber(
          seedKey: track.id,
          position: player.position,
          duration: player.duration,
          activeColor: player.palette.primary,
          onSeek: notifier.seek,
        ),
        const SizedBox(height: 22),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            SpringPressable(
              onTap: notifier.toggleShuffle,
              child: Icon(
                Icons.shuffle_rounded,
                size: 24,
                color: player.shuffle
                    ? player.palette.primary
                    : Colors.white.withValues(alpha: 0.65),
              ),
            ),
            SpringPressable(
              onTap: notifier.previous,
              child: const Padding(
                padding: EdgeInsets.all(10),
                child: Icon(Icons.skip_previous_rounded, size: 36),
              ),
            ),
            SpringPressable(
              onTap: notifier.togglePlayPause,
              child: LiquidGlassContainer(
                width: 74,
                height: 74,
                borderRadius: 37,
                tintColor: player.palette.primary,
                tintOpacity: 0.34,
                child: Center(
                  child: Icon(
                    player.isPlaying
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                    size: 40,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            SpringPressable(
              onTap: notifier.next,
              child: const Padding(
                padding: EdgeInsets.all(10),
                child: Icon(Icons.skip_next_rounded, size: 36),
              ),
            ),
            SpringPressable(
              onTap: notifier.cycleRepeatMode,
              child: Icon(
                player.repeatMode == AudioServiceRepeatMode.one
                    ? Icons.repeat_one_rounded
                    : Icons.repeat_rounded,
                size: 24,
                color: player.repeatMode != AudioServiceRepeatMode.none
                    ? player.palette.primary
                    : Colors.white.withValues(alpha: 0.65),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        LiquidGlassContainer(
          borderRadius: 20,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          elevationShadow: false,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              SpringPressable(
                onTap: () => _showSpeedPicker(context, player.speed),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.speed_rounded, size: 18),
                    const SizedBox(width: 6),
                    Text(
                      '${player.speed.toStringAsFixed(2).replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '')}x',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              SpringPressable(
                onTap: () => _showSleepTimerPicker(context),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.bedtime_rounded,
                      size: 18,
                      color: sleepTimer.isActive
                          ? player.palette.primary
                          : Colors.white,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      sleepTimer.isActive
                          ? '${sleepTimer.remaining!.inMinutes}m left'
                          : 'Sleep Timer',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: sleepTimer.isActive
                            ? player.palette.primary
                            : Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              SpringPressable(
                onTap: () => QueueGlassDrawer.show(context),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.playlist_play_rounded, size: 20),
                    SizedBox(width: 4),
                    Text(
                      'Queue',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showSpeedPicker(BuildContext context, double currentSpeed) {
    const speeds = [0.75, 1.0, 1.25, 1.5, 2.0];
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
            children: [
              Text('Playback Speed',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: speeds.map((s) {
                  final selected = (s - currentSpeed).abs() < 0.05;
                  return SpringPressable(
                    onTap: () {
                      ref.read(playerProvider.notifier).setSpeed(s);
                      Navigator.of(context).pop();
                    },
                    child: LiquidGlassContainer(
                      borderRadius: 16,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 10),
                      tintOpacity: selected ? 0.30 : 0.08,
                      elevationShadow: false,
                      child: Text(
                        '${s}x',
                        style: TextStyle(
                          fontWeight:
                              selected ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSleepTimerPicker(BuildContext context) {
    const minutesList = [15, 30, 45, 60];
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
            children: [
              Text('Sleep Timer',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  ...minutesList.map((m) {
                    return SpringPressable(
                      onTap: () {
                        ref
                            .read(sleepTimerProvider.notifier)
                            .start(Duration(minutes: m));
                        Navigator.of(context).pop();
                      },
                      child: LiquidGlassContainer(
                        borderRadius: 16,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 10),
                        elevationShadow: false,
                        child: Text('$m min'),
                      ),
                    );
                  }),
                  SpringPressable(
                    onTap: () {
                      ref.read(sleepTimerProvider.notifier).cancel();
                      Navigator.of(context).pop();
                    },
                    child: const LiquidGlassContainer(
                      borderRadius: 16,
                      padding:
                          EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                      elevationShadow: false,
                      child: Text('Turn Off'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
