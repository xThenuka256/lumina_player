import 'dart:io';
import 'package:flutter/material.dart';
import 'package:lumina_player/core/theme/app_theme.dart';

/// Displays cached local album artwork with graceful Liquid Glass fallback.
class TrackArtwork extends StatelessWidget {
  const TrackArtwork({
    super.key,
    required this.artworkPath,
    this.size = 52,
    this.borderRadius = 14,
    this.iconSize = 24,
  });

  final String? artworkPath;
  final double size;
  final double borderRadius;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final hasFile = artworkPath != null &&
        artworkPath!.isNotEmpty &&
        File(artworkPath!).existsSync();

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: SizedBox(
        width: size,
        height: size,
        child: hasFile
            ? Image.file(
                File(artworkPath!),
                fit: BoxFit.cover,
                cacheWidth: (size * 2.5).round(),
                errorBuilder: (_, __, ___) => _FallbackArt(iconSize: iconSize),
              )
            : _FallbackArt(iconSize: iconSize),
      ),
    );
  }
}

class _FallbackArt extends StatelessWidget {
  const _FallbackArt({required this.iconSize});

  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            scheme.primary.withValues(alpha: 0.42),
            scheme.secondary.withValues(alpha: 0.35),
            LuminaTheme.surfaceBase.withValues(alpha: 0.9),
          ],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.music_note_rounded,
          size: iconSize,
          color: Colors.white.withValues(alpha: 0.85),
        ),
      ),
    );
  }
}
