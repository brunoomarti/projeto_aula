import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Máscara circular estilo Looney Tunes — [progress] 0 = ponto, 1 = tela cheia.
class CircleIrisReveal extends StatelessWidget {
  const CircleIrisReveal({
    super.key,
    required this.progress,
    required this.child,
    this.center,
  });

  final double progress;
  final Widget child;
  final Alignment? center;

  @override
  Widget build(BuildContext context) {
    return ClipPath(
      clipper: _CircleIrisClipper(
        progress: progress,
        center: center,
      ),
      clipBehavior: Clip.hardEdge,
      child: child,
    );
  }
}

class _CircleIrisClipper extends CustomClipper<Path> {
  _CircleIrisClipper({
    required this.progress,
    this.center,
  });

  final double progress;
  final Alignment? center;

  @override
  Path getClip(Size size) {
    final alignment = center ?? Alignment.center;
    final focal = alignment.alongSize(size);
    final maxRadius = math.sqrt(
          size.width * size.width + size.height * size.height,
        ) /
        2 *
        1.15;
    final radius = math.max(maxRadius * progress.clamp(0.0, 1.0), 0.5);

    return Path()..addOval(Rect.fromCircle(center: focal, radius: radius));
  }

  @override
  bool shouldReclip(covariant _CircleIrisClipper oldClipper) {
    return oldClipper.progress != progress || oldClipper.center != center;
  }
}
