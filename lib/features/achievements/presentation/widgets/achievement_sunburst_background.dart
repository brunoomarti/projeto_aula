import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Raios solares rotativos sobre fundo colorido.
class AchievementSunburstBackground extends StatefulWidget {
  const AchievementSunburstBackground({
    super.key,
    required this.color,
    this.rayColor = Colors.white,
  });

  final Color color;
  final Color rayColor;

  @override
  State<AchievementSunburstBackground> createState() =>
      _AchievementSunburstBackgroundState();
}

class _AchievementSunburstBackgroundState extends State<AchievementSunburstBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 24),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: widget.color,
      child: RotationTransition(
        turns: _controller,
        child: CustomPaint(
          painter: _SunburstPainter(
            rayColor: widget.rayColor.withValues(alpha: 0.14),
            rayCount: 18,
          ),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

class _SunburstPainter extends CustomPainter {
  _SunburstPainter({
    required this.rayColor,
    required this.rayCount,
  });

  final Color rayColor;
  final int rayCount;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.sqrt(size.width * size.width + size.height * size.height);
    final sweep = (2 * math.pi) / rayCount;
    final paint = Paint()..color = rayColor;

    for (var i = 0; i < rayCount; i++) {
      final start = i * sweep;
      final path = Path()
        ..moveTo(center.dx, center.dy)
        ..arcTo(
          Rect.fromCircle(center: center, radius: radius),
          start,
          sweep * 0.42,
          false,
        )
        ..close();
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SunburstPainter oldDelegate) {
    return oldDelegate.rayColor != rayColor || oldDelegate.rayCount != rayCount;
  }
}
