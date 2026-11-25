import 'dart:async';
import 'package:audio_service/audio_service.dart';
import 'package:media_kit/media_kit.dart';
import 'package:lumina_player/core/storage/library_database.dart';
import 'package:lumina_player/features/library/domain/track.dart';

/// Bridges `media_kit` playback engine with `audio_service` so Android 11+
/// MediaSession / lockscreen resumption and Linux MPRIS D-Bus controls stay in sync.
class LuminaAudioHandler extends BaseAudioHandler
    with QueueHandler, SeekHandler {
  LuminaAudioHandler() {
    _bindPlayerStreams();
  }

  final Player player = Player(
    configuration: const PlayerConfiguration(
      title: 'Lumina Player',
    ),
  );

  final _currentIndexController = StreamController<int>.broadcast();
  final _tracksController = StreamController<List<Track>>.broadcast();
  final _shuffleController = StreamController<bool>.broadcast();
  final _repeatController = StreamController<AudioServiceRepeatMode>.broadcast();

  Stream<int> get currentIndexStream => _currentIndexController.stream;
  Stream<List<Track>> get queueTracksStream => _tracksController.stream;
  Stream<bool> get shuffleStream => _shuffleController.stream;
  Stream<AudioServiceRepeatMode> get repeatModeStream =>
      _repeatController.stream;

  List<Track> _queueTracks = const [];
  int _currentIndex = 0;
  bool _shuffleEnabled = false;
  AudioServiceRepeatMode _repeatMode = AudioServiceRepeatMode.none;
  DateTime _lastPersistTime = DateTime.fromMillisecondsSinceEpoch(0);

  List<Track> get queueTracks => _queueTracks;
  int get currentIndex => _currentIndex;
  bool get shuffleEnabled => _shuffleEnabled;
  AudioServiceRepeatMode get repeatMode => _repeatMode;
  Track? get currentTrack =>
      (_currentIndex >= 0 && _currentIndex < _queueTracks.length)
          ? _queueTracks[_currentIndex]
          : null;

  void _bindPlayerStreams() {
    player.stream.playing.listen((_) => _broadcastPlaybackState());
    player.stream.position.listen((pos) {
      _broadcastPlaybackState(positionOverride: pos);
      _maybePersistPosition(pos);
    });
    player.stream.duration.listen((dur) {
      final current = mediaItem.value;
      if (current != null && dur > Duration.zero && current.duration != dur) {
        mediaItem.add(current.copyWith(duration: dur));
      }
    });
    player.stream.rate.listen((_) => _broadcastPlaybackState());
    player.stream.playlist.listen((playlist) {
      if (_queueTracks.isEmpty) return;
      final idx = playlist.index;
      if (idx >= 0 && idx < _queueTracks.length) {
        _currentIndex = idx;
        _currentIndexController.add(idx);
        mediaItem.add(_trackToMediaItem(_queueTracks[idx]));
        _broadcastPlaybackState();
        _persistNow();
      }
    });
  }

  MediaItem _trackToMediaItem(Track t) {
    return MediaItem(
      id: t.id,
      title: t.title,
      artist: t.artist,
      album: t.album,
      duration: t.durationMs > 0 ? t.duration : null,
      artUri: (t.artworkPath != null && t.artworkPath!.isNotEmpty)
          ? Uri.file(t.artworkPath!)
          : null,
      extras: {'uri': t.uri},
    );
  }

  void _broadcastPlaybackState({Duration? positionOverride}) {
    final isPlaying = player.state.playing;
    playbackState.add(
      playbackState.value.copyWith(
        controls: [
          MediaControl.skipToPrevious,
          if (isPlaying) MediaControl.pause else MediaControl.play,
          MediaControl.skipToNext,
          MediaControl.stop,
        ],
        systemActions: const {
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
          MediaAction.skipToQueueItem,
          MediaAction.setSpeed,
          MediaAction.setRepeatMode,
          MediaAction.setShuffleMode,
        },
        androidCompactActionIndices: const [0, 1, 2],
        processingState: _queueTracks.isEmpty
            ? AudioProcessingState.idle
            : AudioProcessingState.ready,
        playing: isPlaying,
        updatePosition: positionOverride ?? player.state.position,
        speed: player.state.rate,
        queueIndex: _queueTracks.isEmpty ? null : _currentIndex,
        shuffleMode: _shuffleEnabled
            ? AudioServiceShuffleMode.all
            : AudioServiceShuffleMode.none,
        repeatMode: _repeatMode,
      ),
    );
  }

  Future<void> loadQueue(
    List<Track> tracks, {
    int initialIndex = 0,
    bool autoPlay = true,
    Duration? startPosition,
  }) async {
    _queueTracks = List<Track>.unmodifiable(tracks);
    _tracksController.add(_queueTracks);
    queue.add(_queueTracks.map(_trackToMediaItem).toList());

    if (tracks.isEmpty) {
      await player.stop();
      mediaItem.add(null);
      _broadcastPlaybackState();
      return;
    }

    final safeIndex = initialIndex.clamp(0, tracks.length - 1);
    _currentIndex = safeIndex;
    _currentIndexController.add(safeIndex);
    mediaItem.add(_trackToMediaItem(tracks[safeIndex]));

    final medias = tracks.map((t) => Media(t.uri)).toList();
    await player.open(
      Playlist(medias, index: safeIndex),
      play: autoPlay,
    );
    await player.setShuffle(_shuffleEnabled);
    await _applyRepeatModeToPlayer(_repeatMode);

    if (startPosition != null && startPosition > Duration.zero) {
      await player.seek(startPosition);
    }

    _broadcastPlaybackState();
    await _persistNow();
  }

  Future<void> restoreLastSession(List<Track> libraryTracks) async {
    if (libraryTracks.isEmpty) return;
    final saved = await LibraryDatabase.instance.loadPlaybackState();
    if (saved == null || saved.queueIds.isEmpty) return;

    final trackById = {for (final t in libraryTracks) t.id: t};
    final restored = <Track>[];
    for (final id in saved.queueIds) {
      final t = trackById[id];
      if (t != null) restored.add(t);
    }
    if (restored.isEmpty) return;

    _shuffleEnabled = saved.shuffle;
    _shuffleController.add(_shuffleEnabled);
    _repeatMode = AudioServiceRepeatMode
        .values[saved.repeatMode.clamp(0, AudioServiceRepeatMode.values.length - 1)];
    _repeatController.add(_repeatMode);
    await player.setRate(saved.speed.clamp(0.5, 2.0));

    await loadQueue(
      restored,
      initialIndex: saved.currentIndex.clamp(0, restored.length - 1),
      autoPlay: false,
      startPosition: Duration(milliseconds: saved.positionMs),
    );
  }

  @override
  Future<void> play() async {
    if (_queueTracks.isEmpty) return;
    await player.play();
    _broadcastPlaybackState();
  }

  @override
  Future<void> pause() async {
    await player.pause();
    _broadcastPlaybackState();
    await _persistNow();
  }

  @override
  Future<void> stop() async {
    await _persistNow();
    await player.stop();
    await super.stop();
  }

  @override
  Future<void> seek(Duration position) async {
    await player.seek(position);
    _broadcastPlaybackState(positionOverride: position);
  }

  @override
  Future<void> skipToNext() async {
    if (_queueTracks.isEmpty) return;
    await player.next();
  }

  @override
  Future<void> skipToPrevious() async {
    if (_queueTracks.isEmpty) return;
    if (player.state.position.inSeconds > 3) {
      await player.seek(Duration.zero);
      return;
    }
    await player.previous();
  }

  @override
  Future<void> skipToQueueItem(int index) async {
    if (index < 0 || index >= _queueTracks.length) return;
    await player.jump(index);
  }

  @override
  Future<void> setSpeed(double speed) async {
    final clamped = speed.clamp(0.5, 2.0);
    await player.setRate(clamped);
    _broadcastPlaybackState();
    await _persistNow();
  }

  @override
  Future<void> setShuffleMode(AudioServiceShuffleMode shuffleMode) async {
    _shuffleEnabled = shuffleMode == AudioServiceShuffleMode.all ||
        shuffleMode == AudioServiceShuffleMode.group;
    _shuffleController.add(_shuffleEnabled);
    await player.setShuffle(_shuffleEnabled);
    _broadcastPlaybackState();
    await _persistNow();
  }

  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode repeatMode) async {
    _repeatMode = repeatMode;
    _repeatController.add(repeatMode);
    await _applyRepeatModeToPlayer(repeatMode);
    _broadcastPlaybackState();
    await _persistNow();
  }

  Future<void> _applyRepeatModeToPlayer(AudioServiceRepeatMode mode) async {
    switch (mode) {
      case AudioServiceRepeatMode.none:
        await player.setPlaylistMode(PlaylistMode.none);
        break;
      case AudioServiceRepeatMode.one:
        await player.setPlaylistMode(PlaylistMode.single);
        break;
      case AudioServiceRepeatMode.all:
      case AudioServiceRepeatMode.group:
        await player.setPlaylistMode(PlaylistMode.loop);
        break;
    }
  }

  Future<void> moveQueueItem(int oldIndex, int newIndex) async {
    if (oldIndex < 0 ||
        oldIndex >= _queueTracks.length ||
        newIndex < 0 ||
        newIndex > _queueTracks.length) {
      return;
    }
    final updated = List<Track>.from(_queueTracks);
    final item = updated.removeAt(oldIndex);
    final target = newIndex > oldIndex ? newIndex - 1 : newIndex;
    updated.insert(target, item);

    if (_currentIndex == oldIndex) {
      _currentIndex = target;
    } else if (oldIndex < _currentIndex && target >= _currentIndex) {
      _currentIndex--;
    } else if (oldIndex > _currentIndex && target <= _currentIndex) {
      _currentIndex++;
    }

    _queueTracks = List<Track>.unmodifiable(updated);
    _tracksController.add(_queueTracks);
    _currentIndexController.add(_currentIndex);
    queue.add(_queueTracks.map(_trackToMediaItem).toList());
    await player.move(oldIndex, target);
    await _persistNow();
  }

  @override
  Future<void> removeQueueItemAt(int index) async {
    if (index < 0 || index >= _queueTracks.length) return;
    final updated = List<Track>.from(_queueTracks)..removeAt(index);
    if (updated.isEmpty) {
      await loadQueue(const [], autoPlay: false);
      return;
    }
    if (index < _currentIndex) {
      _currentIndex--;
    } else if (_currentIndex >= updated.length) {
      _currentIndex = updated.length - 1;
    }

    _queueTracks = List<Track>.unmodifiable(updated);
    _tracksController.add(_queueTracks);
    _currentIndexController.add(_currentIndex);
    queue.add(_queueTracks.map(_trackToMediaItem).toList());
    await player.remove(index);
    await _persistNow();
  }

  /// Exposes cached tracks for Android 11+ Quick Settings Media Resumption.
  @override
  Future<List<MediaItem>> getChildren(
    String parentMediaId, [
    Map<String, dynamic>? options,
  ]) async {
    if (_queueTracks.isNotEmpty) {
      return _queueTracks.take(25).map(_trackToMediaItem).toList();
    }
    final cached = await LibraryDatabase.instance.loadTracks();
    return cached.take(25).map(_trackToMediaItem).toList();
  }

  void _maybePersistPosition(Duration pos) {
    final now = DateTime.now();
    if (now.difference(_lastPersistTime).inSeconds >= 5) {
      _lastPersistTime = now;
      _persistNow(positionOverride: pos);
    }
  }

  Future<void> _persistNow({Duration? positionOverride}) async {
    if (_queueTracks.isEmpty) return;
    await LibraryDatabase.instance.savePlaybackState(
      queueIds: _queueTracks.map((t) => t.id).toList(),
      currentIndex: _currentIndex,
      positionMs: (positionOverride ?? player.state.position).inMilliseconds,
      shuffle: _shuffleEnabled,
      repeatMode: _repeatMode.index,
      speed: player.state.rate,
    );
  }

  Future<void> disposePlayer() async {
    await _currentIndexController.close();
    await _tracksController.close();
    await _shuffleController.close();
    await _repeatController.close();
    await player.dispose();
  }
}
