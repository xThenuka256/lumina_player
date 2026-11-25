import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lumina_player/features/player/presentation/player_provider.dart';

class SleepTimerState {
  const SleepTimerState({this.remaining});

  final Duration? remaining;
  bool get isActive => remaining != null && remaining! > Duration.zero;
}

/// Countdown sleep timer that gracefully pauses playback on expiration.
class SleepTimerController extends Notifier<SleepTimerState> {
  Timer? _timer;

  @override
  SleepTimerState build() {
    ref.onDispose(() => _timer?.cancel());
    return const SleepTimerState();
  }

  void start(Duration duration) {
    _timer?.cancel();
    state = SleepTimerState(remaining: duration);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final current = state.remaining;
      if (current == null || current.inSeconds <= 1) {
        timer.cancel();
        state = const SleepTimerState();
        ref.read(audioHandlerProvider).pause();
      } else {
        state = SleepTimerState(remaining: current - const Duration(seconds: 1));
      }
    });
  }

  void cancel() {
    _timer?.cancel();
    state = const SleepTimerState();
  }
}

final sleepTimerProvider =
    NotifierProvider<SleepTimerController, SleepTimerState>(
  SleepTimerController.new,
);
