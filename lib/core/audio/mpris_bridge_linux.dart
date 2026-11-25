import 'dart:io';
import 'package:audio_service_mpris/audio_service_mpris.dart';

/// Initializes Linux D-Bus MPRIS integration for `audio_service` so desktop
/// environments (GNOME, KDE, XFCE, hardware media keys) control Lumina Player.
void initLinuxMprisIfNeeded() {
  if (!Platform.isLinux) return;
  AudioServiceMpris.init(
    dBusName: 'LuminaPlayer',
    identity: 'Lumina Player',
    desktopEntry: 'dev.lumina.player',
    minimumRate: 0.5,
    maximumRate: 2.0,
    canControl: true,
    canPlay: true,
    canPause: true,
    canGoNext: true,
    canGoPrevious: true,
  );
}
