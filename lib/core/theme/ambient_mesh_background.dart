import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:lumina_player/core/theme/app_theme.dart';

/// Slowly morphing, multi-layered ambient mesh gradient driven by extracted
/// album art palette colors.
class AmbientMeshBackground extends StatefulWidget {
  const AmbientMeshBackground({
    super.key,
    required this.primaryColor,
    required this.secondaryColor,
    required this.tertiaryColor,
    required this.child,
  });

  final Color primaryColor;
  final Color secondaryColor;
  final Color tertiaryColor;
  final Widget child;

  @override
  State<AmbientMeshBackground> createState() => _AmbientMeshBackgroundState();
}

class _AmbientMeshBackgroundState extends State<AmbientMeshBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: LuminaTheme.surfaceBase),
        AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            return TweenAnimationBuilder<Color?>(
              tween: ColorTween(end: widget.primaryColor),
              duration: const Duration(milliseconds: 900),
              builder: (context, c1, _) {
                return TweenAnimationBuilder<Color?>(
                  tween: ColorTween(end: widget.secondaryColor),
                  duration: const Duration(milliseconds: 900),
                  builder: (context, c2, _) {
                    return TweenAnimationBuilder<Color?>(
                      tween: ColorTween(end: widget.tertiaryColor),
                      duration: const Duration(milliseconds: 900),
                      builder: (context, c3, _) {
                        return CustomPaint(
                          painter: _MeshGradientPainter(
                            progress: _controller.value,
                            c1: c1 ?? widget.primaryColor,
                            c2: c2 ?? widget.secondaryColor,
                            c3: c3 ?? widget.tertiaryColor,
                          ),
                        );
                      },
                    );
                  },
                );
              },
            );
          },
        ),
        // Subtle vignette so glass text remains crisp at any brightness
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.center,
              radius: 1.15,
              colors: [
                Colors.black.withValues(alpha: 0.14),
                Colors.black.withValues(alpha: 0.56),
              ],
            ),
          ),
        ),
        widget.child,
      ],
    );
  }
}

class _MeshGradientPainter extends CustomPainter {
  const _MeshGradientPainter({
    required this.progress,
    required this.c1,
    required this.c2,
    required this.c3,
  });

  final double progress;
  final Color c1;
  final Color c2;
  final Color c3;

  @override
  void paint(Canvas canvas, Size size) {
    final t = progress * math.pi * 2;

    void drawOrb(Offset center, double radius, Color color, double opacity) {
      final paint = Paint()
        ..shader = RadialGradient(
          colors: [
            color.withValues(alpha: opacity),
            color.withValues(alpha: opacity * 0.35),
            color.withValues(alpha: 0.0),
          ],
          stops: const [0.0, 0.45, 1.0],
        ).createShader(Rect.fromCircle(center: center, radius: radius));
      canvas.drawCircle(center, radius, paint);
    }

    final maxDim = math.max(size.width, size.height);

    drawOrb(
      Offset(
        size.width * (0.28 + 0.16 * math.cos(t)),
        size.height * (0.24 + 0.12 * math.sin(t)),
      ),
      maxDim * 0.62,
      c1,
      0.46,
    );

    drawOrb(
      Offset(
        size.width * (0.76 + 0.14 * math.sin(t * 0.85)),
        size.height * (0.40 + 0.18 * math.cos(t * 0.85)),
      ),
      maxDim * 0.58,
      c2,
      0.40,
    );

    drawOrb(
      Offset(
        size.width * (0.45 + 0.20 * math.sin(t * 1.15 + 1.4)),
        size.height * (0.82 + 0.10 * math.cos(t * 1.15 + 1.4)),
      ),
      maxDim * 0.55,
      c3,
      0.34,
    );
  }

  @override
  bool shouldRepaint(covariant _MeshGradientPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.c1 != c1 ||
        oldDelegate.c2 != c2 ||
        oldDelegate.c3 != c3;
  }
}
