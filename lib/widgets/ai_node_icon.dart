import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// A distinct AI Assistant orbital node icon replacing generic AI sparkle star icons.
/// Represents intelligent scheduling orchestration, nodes, and connectivity.
class AiNodeIcon extends StatefulWidget {
  final double size;
  final Color? color;
  final bool animate;

  const AiNodeIcon({
    super.key,
    this.size = 20,
    this.color,
    this.animate = true,
  });

  @override
  State<AiNodeIcon> createState() => _AiNodeIconState();
}

class _AiNodeIconState extends State<AiNodeIcon> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );
    if (widget.animate) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool disableAnimations = MediaQuery.of(context).disableAnimations;
    final iconColor = widget.color ?? AppColors.aiAccent;

    if (disableAnimations || !widget.animate) {
      return Icon(
        Icons.hub_outlined,
        size: widget.size,
        color: iconColor,
      );
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final glowScale = 1.0 + (_controller.value * 0.15);
        final opacity = 0.7 + (_controller.value * 0.3);

        return Transform.scale(
          scale: glowScale,
          child: Opacity(
            opacity: opacity,
            child: Icon(
              Icons.hub_outlined,
              size: widget.size,
              color: iconColor,
            ),
          ),
        );
      },
    );
  }
}
