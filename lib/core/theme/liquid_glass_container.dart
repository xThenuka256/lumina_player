import 'dart:ui';
import 'package:flutter/material.dart';

/// Reusable Liquid Glass surface featuring backdrop blur, translucent tint,
/// 1px specular top-edge gradient rim highlight, and soft ambient shadow.
class LiquidGlassContainer extends StatelessWidget {
  const LiquidGlassContainer({
    super.key,
    required this.child,
    this.borderRadius = 24,
    this.blurSigma = 24,
    this.padding,
    this.margin,
    this.width,
    this.height,
    this.tintColor,
    this.tintOpacity = 0.10,
    this.borderOpacity = 0.34,
    this.elevationShadow = true,
    this.onTap,
  });

  final Widget child;
  final double borderRadius;
  final double blurSigma;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? width;
  final double? height;
  final Color? tintColor;
  final double tintOpacity;
  final double borderOpacity;
  final bool elevationShadow;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final baseTint = tintColor ?? Colors.white;
    final radius = BorderRadius.circular(borderRadius);

    final decorated = Container(
      width: width,
      height: height,
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: elevationShadow
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.36),
                  blurRadius: 28,
                  spreadRadius: -6,
                  offset: const Offset(0, 14),
                ),
                BoxShadow(
                  color: Theme.of(context)
                      .colorScheme
                      .primary
                      .withValues(alpha: 0.08),
                  blurRadius: 22,
                  spreadRadius: -8,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
          child: CustomPaint(
            painter: _SpecularRimPainter(
              borderRadius: borderRadius,
              borderOpacity: borderOpacity,
            ),
            child: Container(
              padding: padding,
              decoration: BoxDecoration(
                borderRadius: radius,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    baseTint.withValues(alpha: tintOpacity + 0.06),
                    baseTint.withValues(alpha: tintOpacity * 0.55),
                    Colors.black.withValues(alpha: 0.14),
                  ],
                ),
              ),
              child: child,
            ),
          ),
        ),
      ),
    );

    if (onTap == null) return decorated;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: decorated,
    );
  }
}

class _SpecularRimPainter extends CustomPainter {
  const _SpecularRimPainter({
    required this.borderRadius,
    required this.borderOpacity,
  });

  final double borderRadius;
  final double borderOpacity;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(
      rect.deflate(0.5),
      Radius.circular(borderRadius),
    );

    final rimPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        stops: const [0.0, 0.35, 0.85, 1.0],
        colors: [
          Colors.white.withValues(alpha: borderOpacity + 0.16),
          Colors.white.withValues(alpha: borderOpacity * 0.45),
          Colors.white.withValues(alpha: borderOpacity * 0.12),
          Colors.white.withValues(alpha: borderOpacity * 0.28),
        ],
      ).createShader(rect);

    canvas.drawRRect(rrect, rimPaint);
  }

  @override
  bool shouldRepaint(covariant _SpecularRimPainter oldDelegate) {
    return oldDelegate.borderRadius != borderRadius ||
        oldDelegate.borderOpacity != borderOpacity;
  }
}
