import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Scrubbable waveform progress bar with deterministic bar heights derived
/// from [seedKey] and smooth drag-to-seek feedback.
class WaveformScrubber extends StatefulWidget {
  const WaveformScrubber({
    super.key,
    required this.seedKey,
    required this.position,
    required this.duration,
    required this.onSeek,
    this.activeColor,
    this.barCount = 48,
    this.height = 46,
  });

  final String seedKey;
  final Duration position;
  final Duration duration;
  final ValueChanged<Duration> onSeek;
  final Color? activeColor;
  final int barCount;
  final double height;

  @override
  State<WaveformScrubber> createState() => _WaveformScrubberState();
}

class _WaveformScrubberState extends State<WaveformScrubber> {
  double? _dragFraction;

  List<double> _buildAmplitudes() {
    var hash = widget.seedKey.hashCode;
    return List<double>.generate(widget.barCount, (i) {
      hash = (hash * 1664525 + 1013904223) & 0x7FFFFFFF;
      final rand = (hash % 1000) / 1000.0;
      final envelope = 0.45 + 0.55 * math.sin((i / widget.barCount) * math.pi);
      return (0.22 + 0.78 * rand) * envelope;
    });
  }

  void _updateFromOffset(Offset localPos, double width) {
    if (width <= 0) return;
    final fraction = (localPos.dx / width).clamp(0.0, 1.0);
    setState(() => _dragFraction = fraction);
  }

  void _commitSeek() {
    final frac = _dragFraction;
    setState(() => _dragFraction = null);
    if (frac != null && widget.duration > Duration.zero) {
      final ms = (widget.duration.inMilliseconds * frac).round();
      widget.onSeek(Duration(milliseconds: ms));
    }
  }

  String _format(Duration d) {
    final totalSec = d.inSeconds.clamp(0, 86400);
    final m = totalSec ~/ 60;
    final s = totalSec % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final totalMs = widget.duration.inMilliseconds;
    final liveFraction = totalMs > 0
        ? (widget.position.inMilliseconds / totalMs).clamp(0.0, 1.0)
        : 0.0;
    final displayFraction = _dragFraction ?? liveFraction;
    final displayPosition = Duration(
      milliseconds: (totalMs * displayFraction).round(),
    );

    final color = widget.activeColor ?? Theme.of(context).colorScheme.primary;
    final amplitudes = _buildAmplitudes();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onHorizontalDragStart: (d) =>
                  _updateFromOffset(d.localPosition, constraints.maxWidth),
              onHorizontalDragUpdate: (d) =>
                  _updateFromOffset(d.localPosition, constraints.maxWidth),
              onHorizontalDragEnd: (_) => _commitSeek(),
              onTapDown: (d) =>
                  _updateFromOffset(d.localPosition, constraints.maxWidth),
              onTapUp: (_) => _commitSeek(),
              child: SizedBox(
                height: widget.height,
                width: double.infinity,
                child: CustomPaint(
                  painter: _WaveformPainter(
                    amplitudes: amplitudes,
                    progress: displayFraction,
                    activeColor: color,
                    inactiveColor: Colors.white.withValues(alpha: 0.22),
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _format(displayPosition),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            Text(
              _format(widget.duration),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ],
    );
  }
}

class _WaveformPainter extends CustomPainter {
  const _WaveformPainter({
    required this.amplitudes,
    required this.progress,
    required this.activeColor,
    required this.inactiveColor,
  });

  final List<double> amplitudes;
  final double progress;
  final Color activeColor;
  final Color inactiveColor;

  @override
  void paint(Canvas canvas, Size size) {
    final count = amplitudes.length;
    if (count == 0) return;

    final step = size.width / count;
    final barWidth = (step * 0.54).clamp(2.0, 5.0);
    final midY = size.height / 2;

    for (var i = 0; i < count; i++) {
      final x = i * step + (step - barWidth) / 2;
      final barHeight = (amplitudes[i] * size.height * 0.88).clamp(4.0, size.height);
      final barFraction = (i + 0.5) / count;
      final isActive = barFraction <= progress;

      final paint = Paint()
        ..color = isActive ? activeColor : inactiveColor
        ..style = PaintingStyle.fill;

      final rect = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(x + barWidth / 2, midY),
          width: barWidth,
          height: barHeight,
        ),
        const Radius.circular(3),
      );
      canvas.drawRRect(rect, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _WaveformPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.activeColor != activeColor ||
        oldDelegate.amplitudes != amplitudes;
  }
}
