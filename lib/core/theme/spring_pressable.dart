import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';

/// Tactile button wrapper that scales smoothly down to [pressedScale] using a
/// critically-damped spring simulation on press/release.
class SpringPressable extends StatefulWidget {
  const SpringPressable({
    super.key,
    required this.child,
    required this.onTap,
    this.onLongPress,
    this.pressedScale = 0.95,
    this.haptics = true,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double pressedScale;
  final bool haptics;

  @override
  State<SpringPressable> createState() => _SpringPressableState();
}

class _SpringPressableState extends State<SpringPressable>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  static const _spring = SpringDescription(
    mass: 0.8,
    stiffness: 420,
    damping: 26,
  );

  @override
  void initState() {
    super.initState();
    _controller = AnimationController.unbounded(vsync: this, value: 1.0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _animateTo(double target) {
    final sim = SpringSimulation(_spring, _controller.value, target, 0);
    _controller.animateWith(sim);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: widget.onTap == null
          ? null
          : (_) => _animateTo(widget.pressedScale),
      onTapUp: widget.onTap == null
          ? null
          : (_) {
              _animateTo(1.0);
              if (widget.haptics) HapticFeedback.lightImpact();
              widget.onTap?.call();
            },
      onTapCancel: widget.onTap == null ? null : () => _animateTo(1.0),
      onLongPress: widget.onLongPress,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) => Transform.scale(
          scale: _controller.value.clamp(0.82, 1.08),
          child: child,
        ),
        child: widget.child,
      ),
    );
  }
}
