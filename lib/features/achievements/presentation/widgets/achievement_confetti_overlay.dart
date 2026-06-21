import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../app/theme/tasker_colors.dart';

/// Confetes leves disparados ao desbloquear conquista.
class AchievementConfettiOverlay extends StatefulWidget {
  const AchievementConfettiOverlay({
    super.key,
    required this.playing,
  });

  final bool playing;

  @override
  State<AchievementConfettiOverlay> createState() =>
      _AchievementConfettiOverlayState();
}

class _AchievementConfettiOverlayState extends State<AchievementConfettiOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final List<_ConfettiPiece> _pieces;
  final _random = math.Random(42);

  @override
  void initState() {
    super.initState();
    _pieces = List.generate(56, (_) => _ConfettiPiece.random(_random));
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    );
    if (widget.playing) _controller.forward();
  }

  @override
  void didUpdateWidget(covariant AchievementConfettiOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.playing && !oldWidget.playing) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        if (_controller.value <= 0) return const SizedBox.shrink();
        return IgnorePointer(
          child: CustomPaint(
            painter: _ConfettiPainter(
              pieces: _pieces,
              progress: _controller.value,
            ),
            child: const SizedBox.expand(),
          ),
        );
      },
    );
  }
}

class _ConfettiPiece {
  _ConfettiPiece({
    required this.x,
    required this.delay,
    required this.speed,
    required this.wobble,
    required this.size,
    required this.color,
    required this.rotation,
  });

  final double x;
  final double delay;
  final double speed;
  final double wobble;
  final double size;
  final Color color;
  final double rotation;

  factory _ConfettiPiece.random(math.Random random) {
    const palette = [
      Colors.white,
      Color(0xFFFFE066),
      Color(0xFFFF8FAB),
      Color(0xFF7DD3FC),
      TaskerColors.iconBackground,
    ];
    return _ConfettiPiece(
      x: random.nextDouble(),
      delay: random.nextDouble() * 0.35,
      speed: 0.55 + random.nextDouble() * 0.65,
      wobble: random.nextDouble() * 2 * math.pi,
      size: 5 + random.nextDouble() * 5,
      color: palette[random.nextInt(palette.length)],
      rotation: random.nextDouble() * math.pi,
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter({
    required this.pieces,
    required this.progress,
  });

  final List<_ConfettiPiece> pieces;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    for (final piece in pieces) {
      final local = ((progress - piece.delay) / (1 - piece.delay)).clamp(0.0, 1.0);
      if (local <= 0) continue;

      final fade = (1 - local).clamp(0.0, 1.0);
      final paint = Paint()..color = piece.color.withValues(alpha: fade * 0.95);

      final x = piece.x * size.width +
          math.sin(local * math.pi * 3 + piece.wobble) * 28;
      final y = -24 + local * (size.height + 80) * piece.speed;

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(piece.rotation + local * math.pi * 2);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset.zero,
            width: piece.size,
            height: piece.size * 0.55,
          ),
          const Radius.circular(1.5),
        ),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
