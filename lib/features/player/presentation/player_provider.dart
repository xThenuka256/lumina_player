import 'dart:io';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lumina_player/core/audio/audio_service_handler.dart';
import 'package:lumina_player/core/theme/app_theme.dart';
import 'package:lumina_player/features/library/domain/track.dart';

/// Global [LuminaAudioHandler] overridden at startup in `main()`.
final audioHandlerProvider = Provider<LuminaAudioHandler>((ref) {
  throw UnimplementedError('audioHandlerProvider must be overridden in main()');
});

class DynamicPalette {
  const DynamicPalette({
    required this.primary,
    required this.secondary,
    required this.tertiary,
    this.scheme,
  });

  final Color primary;
  final Color secondary;
  final Color tertiary;
  final ColorScheme? scheme;

  static const fallback = DynamicPalette(
    primary: LuminaTheme.fallbackPrimary,
    secondary: LuminaTheme.fallbackSecondary,
    tertiary: LuminaTheme.fallbackTertiary,
  );
}

class PlayerUiState {
  const PlayerUiState({
    this.queue = const [],
    this.currentIndex = 0,
    this.isPlaying = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.shuffle = false,
    this.repeatMode = AudioServiceRepeatMode.none,
    this.speed = 1.0,
    this.palette = DynamicPalette.fallback,
  });

  final List<Track> queue;
  final int currentIndex;
  final bool isPlaying;
  final Duration position;
  final Duration duration;
  final bool shuffle;
  final AudioServiceRepeatMode repeatMode;
  final double speed;
  final DynamicPalette palette;

  Track? get currentTrack =>
      (currentIndex >= 0 && currentIndex < queue.length)
          ? queue[currentIndex]
          : null;

  PlayerUiState copyWith({
    List<Track>? queue,
    int? currentIndex,
    bool? isPlaying,
    Duration? position,
    Duration? duration,
    bool? shuffle,
    AudioServiceRepeatMode? repeatMode,
    double? speed,
    DynamicPalette? palette,
  }) {
    return PlayerUiState(
      queue: queue ?? this.queue,
      currentIndex: currentIndex ?? this.currentIndex,
      isPlaying: isPlaying ?? this.isPlaying,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      shuffle: shuffle ?? this.shuffle,
      repeatMode: repeatMode ?? this.repeatMode,
      speed: speed ?? this.speed,
      palette: palette ?? this.palette,
    );
  }
}

class PlayerNotifier extends Notifier<PlayerUiState> {
  String? _lastExtractedArtPath;

  @override
  PlayerUiState build() {
    final handler = ref.watch(audioHandlerProvider);

    final subPlaying = handler.player.stream.playing.listen((playing) {
      state = state.copyWith(isPlaying: playing);
    });
    final subPos = handler.player.stream.position.listen((pos) {
      state = state.copyWith(position: pos);
    });
    final subDur = handler.player.stream.duration.listen((dur) {
      if (dur > Duration.zero) {
        state = state.copyWith(duration: dur);
      }
    });
    final subRate = handler.player.stream.rate.listen((rate) {
      state = state.copyWith(speed: rate);
    });
    final subQueue = handler.queueTracksStream.listen((tracks) {
      state = state.copyWith(queue: tracks);
      _updatePaletteForCurrentTrack();
    });
    final subIndex = handler.currentIndexStream.listen((idx) {
      final trackDur = (idx >= 0 && idx < state.queue.length)
          ? state.queue[idx].duration
          : Duration.zero;
      state = state.copyWith(
        currentIndex: idx,
        duration: trackDur > Duration.zero ? trackDur : state.duration,
      );
      _updatePaletteForCurrentTrack();
    });
    final subShuffle = handler.shuffleStream.listen((shuffle) {
      state = state.copyWith(shuffle: shuffle);
    });
    final subRepeat = handler.repeatModeStream.listen((repeat) {
      state = state.copyWith(repeatMode: repeat);
    });

    ref.onDispose(() {
      subPlaying.cancel();
      subPos.cancel();
      subDur.cancel();
      subRate.cancel();
      subQueue.cancel();
      subIndex.cancel();
      subShuffle.cancel();
      subRepeat.cancel();
    });

    return PlayerUiState(
      queue: handler.queueTracks,
      currentIndex: handler.currentIndex,
      isPlaying: handler.player.state.playing,
      position: handler.player.state.position,
      duration: handler.currentTrack?.duration ?? handler.player.state.duration,
      shuffle: handler.shuffleEnabled,
      repeatMode: handler.repeatMode,
      speed: handler.player.state.rate,
    );
  }

  Future<void> _updatePaletteForCurrentTrack() async {
    final artPath = state.currentTrack?.artworkPath;
    if (artPath == _lastExtractedArtPath) return;
    _lastExtractedArtPath = artPath;

    if (artPath == null || artPath.isEmpty || !File(artPath).existsSync()) {
      state = state.copyWith(palette: DynamicPalette.fallback);
      return;
    }

    try {
      final scheme = await ColorScheme.fromImageProvider(
        provider: FileImage(File(artPath)),
        brightness: Brightness.dark,
        dynamicSchemeVariant: DynamicSchemeVariant.vibrant,
      );
      state = state.copyWith(
        palette: DynamicPalette(
          primary: scheme.primary,
          secondary: scheme.secondary,
          tertiary: scheme.tertiary,
          scheme: scheme,
        ),
      );
    } catch (_) {
      state = state.copyWith(palette: DynamicPalette.fallback);
    }
  }

  Future<void> playQueue(List<Track> tracks, {int index = 0}) async {
    await ref
        .read(audioHandlerProvider)
        .loadQueue(tracks, initialIndex: index, autoPlay: true);
  }

  Future<void> togglePlayPause() async {
    final handler = ref.read(audioHandlerProvider);
    if (state.isPlaying) {
      await handler.pause();
    } else {
      await handler.play();
    }
  }

  Future<void> next() => ref.read(audioHandlerProvider).skipToNext();
  Future<void> previous() => ref.read(audioHandlerProvider).skipToPrevious();
  Future<void> seek(Duration position) =>
      ref.read(audioHandlerProvider).seek(position);
  Future<void> jumpTo(int index) =>
      ref.read(audioHandlerProvider).skipToQueueItem(index);
  Future<void> setSpeed(double rate) =>
      ref.read(audioHandlerProvider).setSpeed(rate);

  Future<void> toggleShuffle() async {
    final next = !state.shuffle;
    await ref.read(audioHandlerProvider).setShuffleMode(
          next ? AudioServiceShuffleMode.all : AudioServiceShuffleMode.none,
        );
  }

  Future<void> cycleRepeatMode() async {
    final next = switch (state.repeatMode) {
      AudioServiceRepeatMode.none => AudioServiceRepeatMode.all,
      AudioServiceRepeatMode.all => AudioServiceRepeatMode.one,
      _ => AudioServiceRepeatMode.none,
    };
    await ref.read(audioHandlerProvider).setRepeatMode(next);
  }

  Future<void> reorderQueue(int oldIndex, int newIndex) =>
      ref.read(audioHandlerProvider).moveQueueItem(oldIndex, newIndex);

  Future<void> removeFromQueue(int index) =>
      ref.read(audioHandlerProvider).removeQueueItemAt(index);
}

final playerProvider = NotifierProvider<PlayerNotifier, PlayerUiState>(
  PlayerNotifier.new,
);
