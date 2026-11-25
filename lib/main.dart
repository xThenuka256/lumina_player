import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:lumina_player/app.dart';
import 'package:lumina_player/core/audio/audio_service_handler.dart';
import 'package:lumina_player/core/audio/mpris_bridge.dart';
import 'package:lumina_player/features/player/presentation/player_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Edge-to-edge rendering on Android 11+ (API 30+)
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  MediaKit.ensureInitialized();
  initLinuxMprisIfNeeded();

  final audioHandler = await AudioService.init<LuminaAudioHandler>(
    builder: LuminaAudioHandler.new,
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'dev.lumina.player.channel.audio',
      androidNotificationChannelName: 'Lumina Music Playback',
      androidNotificationOngoing: true,
      androidStopForegroundOnPause: true,
    ),
  );

  runApp(
    ProviderScope(
      overrides: [
        audioHandlerProvider.overrideWithValue(audioHandler),
      ],
      child: const LuminaApp(),
    ),
  );
}
