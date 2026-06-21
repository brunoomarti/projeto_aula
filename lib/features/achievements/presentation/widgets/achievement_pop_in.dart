import 'package:flutter/material.dart';

/// Entrada pop + bounce — mesmo estilo dos balões do dock.
class AchievementPopIn extends StatelessWidget {
  const AchievementPopIn({
    super.key,
    required this.animation,
    required this.child,
    this.alignment = Alignment.center,
  });

  final Animation<double> animation;
  final Widget child;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final t = animation.value.clamp(0.0, 1.0);
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, (1 - t) * 18),
            child: Transform.scale(
              scale: t,
              alignment: alignment,
              child: child,
            ),
          ),
        );
      },
      child: child,
    );
  }
}
