import 'package:flutter/material.dart';
import 'package:lumina_player/core/permissions/media_permissions_service.dart';
import 'package:lumina_player/core/theme/liquid_glass_container.dart';
import 'package:lumina_player/core/theme/spring_pressable.dart';

/// In-app Liquid Glass card shown when Android 11+ audio permission is denied
/// or permanently denied, offering one-tap request or App Settings deep link.
class PermissionGlassCard extends StatelessWidget {
  const PermissionGlassCard({
    super.key,
    required this.status,
    required this.onRequestPermission,
    required this.onOpenSettings,
    required this.onPickFolderSaf,
  });

  final MediaPermissionStatus status;
  final VoidCallback onRequestPermission;
  final VoidCallback onOpenSettings;
  final VoidCallback onPickFolderSaf;

  @override
  Widget build(BuildContext context) {
    final isPermanent = status == MediaPermissionStatus.permanentlyDenied;
    final scheme = Theme.of(context).colorScheme;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: LiquidGlassContainer(
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(26),
          borderRadius: 28,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      scheme.primary.withValues(alpha: 0.35),
                      scheme.secondary.withValues(alpha: 0.25),
                    ],
                  ),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.3),
                  ),
                ),
                child: const Icon(
                  Icons.library_music_rounded,
                  size: 32,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                isPermanent
                    ? 'Audio Permission Required'
                    : 'Access Your Local Music',
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                isPermanent
                    ? 'Audio access was permanently denied in Android settings. Open App Settings to enable Music & Audio access, or select a folder directly via Storage Access Framework.'
                    : 'Lumina scans local MP3, FLAC, WAV, OGG, and M4A audio via Android MediaStore without modifying or uploading your files.',
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 22),
              SpringPressable(
                onTap: isPermanent ? onOpenSettings : onRequestPermission,
                child: LiquidGlassContainer(
                  borderRadius: 18,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 14,
                  ),
                  tintColor: scheme.primary,
                  tintOpacity: 0.28,
                  elevationShadow: false,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isPermanent
                            ? Icons.settings_rounded
                            : Icons.verified_user_rounded,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        isPermanent ? 'Open App Settings' : 'Grant Audio Access',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SpringPressable(
                onTap: onPickFolderSaf,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  child: Text(
                    'Or Pick a Folder via SAF',
                    style: TextStyle(
                      color: scheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
