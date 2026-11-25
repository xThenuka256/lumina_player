import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lumina_player/core/theme/ambient_mesh_background.dart';
import 'package:lumina_player/core/theme/app_theme.dart';
import 'package:lumina_player/core/theme/liquid_glass_container.dart';
import 'package:lumina_player/core/theme/spring_pressable.dart';
import 'package:lumina_player/features/library/presentation/library_screen.dart';
import 'package:lumina_player/features/player/presentation/mini_player_pill.dart';
import 'package:lumina_player/features/player/presentation/player_provider.dart';
import 'package:lumina_player/features/playlists/presentation/playlists_screen.dart';
import 'package:lumina_player/features/settings/presentation/settings_screen.dart';

class LuminaApp extends ConsumerWidget {
  const LuminaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(playerProvider.select((s) => s.palette));

    return MaterialApp(
      title: 'Lumina Player',
      debugShowCheckedModeBanner: false,
      theme: LuminaTheme.buildTheme(dynamicScheme: palette.scheme),
      home: const _AdaptiveShell(),
    );
  }
}

class _AdaptiveShell extends ConsumerStatefulWidget {
  const _AdaptiveShell();

  @override
  ConsumerState<_AdaptiveShell> createState() => _AdaptiveShellState();
}

class _AdaptiveShellState extends ConsumerState<_AdaptiveShell> {
  int _selectedIndex = 0;

  static const _destinations = [
    (icon: Icons.library_music_rounded, label: 'Library'),
    (icon: Icons.queue_music_rounded, label: 'Playlists'),
    (icon: Icons.tune_rounded, label: 'Settings'),
  ];

  @override
  Widget build(BuildContext context) {
    final player = ref.watch(playerProvider);
    final hasCurrentTrack = player.currentTrack != null;

    final bodyPage = AnimatedSwitcher(
      duration: const Duration(milliseconds: 280),
      child: switch (_selectedIndex) {
        0 => const LibraryScreen(key: ValueKey('page_library')),
        1 => const PlaylistsScreen(key: ValueKey('page_playlists')),
        _ => const SettingsScreen(key: ValueKey('page_settings')),
      },
    );

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AmbientMeshBackground(
        primaryColor: player.palette.primary,
        secondaryColor: player.palette.secondary,
        tertiaryColor: player.palette.tertiary,
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isDesktop = constraints.maxWidth >= 840;

              if (isDesktop) {
                return Column(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          _DesktopGlassSidebar(
                            selectedIndex: _selectedIndex,
                            onSelect: (i) => setState(() => _selectedIndex = i),
                          ),
                          Expanded(child: bodyPage),
                        ],
                      ),
                    ),
                    if (hasCurrentTrack)
                      const Padding(
                        padding: EdgeInsets.fromLTRB(16, 0, 16, 14),
                        child: MiniPlayerPill(),
                      ),
                  ],
                );
              }

              return Stack(
                children: [
                  Positioned.fill(child: bodyPage),
                  Positioned(
                    left: 14,
                    right: 14,
                    bottom: 10,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (hasCurrentTrack) ...[
                          const MiniPlayerPill(),
                          const SizedBox(height: 10),
                        ],
                        _MobileGlassNavBar(
                          selectedIndex: _selectedIndex,
                          onSelect: (i) => setState(() => _selectedIndex = i),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _DesktopGlassSidebar extends StatelessWidget {
  const _DesktopGlassSidebar({
    required this.selectedIndex,
    required this.onSelect,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return LiquidGlassContainer(
      width: 224,
      margin: const EdgeInsets.fromLTRB(14, 10, 8, 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 18),
      borderRadius: 26,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              children: [
                Icon(
                  Icons.graphic_eq_rounded,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 10),
                const Text(
                  'Lumina',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          ...List.generate(_AdaptiveShellState._destinations.length, (i) {
            final dest = _AdaptiveShellState._destinations[i];
            final active = i == selectedIndex;
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: SpringPressable(
                haptics: false,
                onTap: () => onSelect(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: active
                        ? Theme.of(context)
                            .colorScheme
                            .primary
                            .withValues(alpha: 0.24)
                        : Colors.transparent,
                    border: Border.all(
                      color: active
                          ? Theme.of(context)
                              .colorScheme
                              .primary
                              .withValues(alpha: 0.55)
                          : Colors.transparent,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(dest.icon, size: 20),
                      const SizedBox(width: 12),
                      Text(
                        dest.label,
                        style: TextStyle(
                          fontWeight:
                              active ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
          const Spacer(),
          Text(
            'Linux MPRIS • MediaKit',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _MobileGlassNavBar extends StatelessWidget {
  const _MobileGlassNavBar({
    required this.selectedIndex,
    required this.onSelect,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return LiquidGlassContainer(
      borderRadius: 24,
      blurSigma: 28,
      tintOpacity: 0.14,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: List.generate(_AdaptiveShellState._destinations.length, (i) {
          final dest = _AdaptiveShellState._destinations[i];
          final active = i == selectedIndex;
          return Expanded(
            child: SpringPressable(
              haptics: false,
              onTap: () => onSelect(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  color: active
                      ? Theme.of(context)
                          .colorScheme
                          .primary
                          .withValues(alpha: 0.22)
                      : Colors.transparent,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      dest.icon,
                      size: 21,
                      color: active
                          ? Theme.of(context).colorScheme.primary
                          : Colors.white70,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      dest.label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                        color: active ? Colors.white : Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
