import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lumina_player/core/permissions/media_permissions_service.dart';
import 'package:lumina_player/core/theme/liquid_glass_container.dart';
import 'package:lumina_player/core/theme/spring_pressable.dart';
import 'package:lumina_player/features/library/presentation/library_provider.dart';
import 'package:lumina_player/features/settings/presentation/settings_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final library = ref.watch(libraryProvider);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 140),
      children: [
        Text(
          'Settings',
          style: Theme.of(context).textTheme.displaySmall,
        ),
        const SizedBox(height: 16),
        LiquidGlassContainer(
          borderRadius: 22,
          padding: const EdgeInsets.all(18),
          elevationShadow: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Library & Scanning',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                '${library.tracks.length} tracks indexed across .mp3, .flac, .wav, .ogg, .m4a',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (Platform.isLinux && settings.xdgMusicDir != null) ...[
                const SizedBox(height: 10),
                Text(
                  'XDG Music Directory: ${settings.xdgMusicDir}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                ),
              ],
              const SizedBox(height: 14),
              SpringPressable(
                onTap: () => ref.read(libraryProvider.notifier).rescan(),
                child: LiquidGlassContainer(
                  borderRadius: 16,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 12,
                  ),
                  tintColor: Theme.of(context).colorScheme.primary,
                  tintOpacity: 0.25,
                  elevationShadow: false,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.sync_rounded, size: 19),
                      const SizedBox(width: 8),
                      Text(
                        library.isScanning ? 'Scanning...' : 'Rescan Library',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        LiquidGlassContainer(
          borderRadius: 22,
          padding: const EdgeInsets.all(18),
          elevationShadow: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Included Folders',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  SpringPressable(
                    onTap: () =>
                        ref.read(settingsProvider.notifier).pickWatchedFolder(),
                    child: Text(
                      '+ Add Folder',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (settings.watchedFolders.isEmpty)
                Text(
                  Platform.isAndroid
                      ? 'Using Android MediaStore automatic audio indexing. Add custom folders via Storage Access Framework if needed.'
                      : 'No extra folders added beyond your XDG Music folder.',
                  style: Theme.of(context).textTheme.bodySmall,
                )
              else
                ...settings.watchedFolders.map(
                  (folder) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.folder_outlined),
                    title: Text(
                      folder,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.remove_circle_outline_rounded),
                      onPressed: () => ref
                          .read(settingsProvider.notifier)
                          .removeWatchedFolder(folder),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        LiquidGlassContainer(
          borderRadius: 22,
          padding: const EdgeInsets.all(18),
          elevationShadow: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Excluded Folders',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  SpringPressable(
                    onTap: () => ref
                        .read(settingsProvider.notifier)
                        .pickExcludedFolder(),
                    child: Text(
                      '+ Exclude',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.secondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (settings.excludedFolders.isEmpty)
                Text(
                  'No folders excluded.',
                  style: Theme.of(context).textTheme.bodySmall,
                )
              else
                ...settings.excludedFolders.map(
                  (folder) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.folder_off_outlined),
                    title: Text(
                      folder,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => ref
                          .read(settingsProvider.notifier)
                          .removeExcludedFolder(folder),
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (Platform.isAndroid) ...[
          const SizedBox(height: 14),
          LiquidGlassContainer(
            borderRadius: 22,
            padding: const EdgeInsets.all(18),
            elevationShadow: false,
            child: Row(
              children: [
                const Icon(Icons.security_rounded),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Android Media Permissions',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        'Status: ${library.permissionStatus.name}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () async {
                    await MediaPermissionsService.instance
                        .openSystemAppSettings();
                    await ref
                        .read(libraryProvider.notifier)
                        .refreshPermissionStatus();
                  },
                  child: const Text('App Settings'),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
