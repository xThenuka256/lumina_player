import 'dart:io';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

enum MediaPermissionStatus {
  granted,
  denied,
  permanentlyDenied,
}

/// Cross-platform runtime permission manager targeting Android 11+ (API 30–35+)
/// and Linux desktop.
class MediaPermissionsService {
  MediaPermissionsService._();
  static final MediaPermissionsService instance = MediaPermissionsService._();

  static const _channel = MethodChannel('dev.lumina.player/mediastore');

  Future<int> getAndroidSdkInt() async {
    if (!Platform.isAndroid) return 0;
    try {
      final sdk = await _channel.invokeMethod<int>('getAndroidSdkInt');
      return sdk ?? 30;
    } catch (_) {
      return 30;
    }
  }

  Future<MediaPermissionStatus> checkMediaPermission() async {
    if (!Platform.isAndroid) return MediaPermissionStatus.granted;

    final sdk = await getAndroidSdkInt();
    final primary = sdk >= 33 ? Permission.audio : Permission.storage;
    final status = await primary.status;

    if (status.isGranted || status.isLimited) {
      return MediaPermissionStatus.granted;
    }
    if (status.isPermanentlyDenied) {
      return MediaPermissionStatus.permanentlyDenied;
    }
    return MediaPermissionStatus.denied;
  }

  Future<MediaPermissionStatus> requestMediaPermission() async {
    if (!Platform.isAndroid) return MediaPermissionStatus.granted;

    final sdk = await getAndroidSdkInt();
    final primary = sdk >= 33 ? Permission.audio : Permission.storage;
    final result = await primary.request();

    if (sdk >= 33) {
      // Request notification permission so Android 13+ foreground playback
      // media controls remain visible in the shade and lockscreen.
      final notifStatus = await Permission.notification.status;
      if (notifStatus.isDenied) {
        await Permission.notification.request();
      }
    }

    if (result.isGranted || result.isLimited) {
      return MediaPermissionStatus.granted;
    }
    if (result.isPermanentlyDenied) {
      return MediaPermissionStatus.permanentlyDenied;
    }
    return MediaPermissionStatus.denied;
  }

  Future<bool> openSystemAppSettings() => openAppSettings();
}
