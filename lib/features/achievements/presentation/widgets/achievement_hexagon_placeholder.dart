import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../app/theme/tasker_card_style.dart';
import '../../../../app/theme/tasker_colors.dart';

/// Espaço reservado para a arte da medalha — hexágono com cantos levemente arredondados.
class AchievementHexagonPlaceholder extends StatelessWidget {
  const AchievementHexagonPlaceholder({
    super.key,
    this.size = 76,
    this.unlocked = false,
  });

  final double size;
  final bool unlocked;

  @override
  Widget build(BuildContext context) {
    final fill = unlocked
        ? TaskerColors.primary.withValues(alpha: 0.14)
        : TaskerCardStyle.actionIconInactiveBackground.withValues(alpha: 0.65);
    final stroke = unlocked
        ? TaskerColors.primary.withValues(alpha: 0.45)
        : TaskerColors.mutedText.withValues(alpha: 0.35);

    return CustomPaint(
      size: Size(size, size * 1.12),
      painter: _RoundedHexagonPainter(fill: fill, stroke: stroke),
    );
  }
}

class _RoundedHexagonPainter extends CustomPainter {
  _RoundedHexagonPainter({
    required this.fill,
    required this.stroke,
  });

  final Color fill;
  final Color stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final cornerRadius = size.width * 0.09;
    final path = _hexagonPath(size);

    // Preenchimento com junção arredondada — hexágono reto + cantos suaves.
    canvas.drawPath(
      path,
      Paint()
        ..color = fill
        ..style = PaintingStyle.stroke
        ..strokeWidth = cornerRadius * 2
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );

    canvas.drawPath(
      path,
      Paint()
        ..color = stroke
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );
  }

  /// Hexágono regular com topo pontiagudo e arestas retas.
  Path _hexagonPath(Size size) {
    final vertices = _hexagonVertices(size);
    final path = Path()..moveTo(vertices.first.dx, vertices.first.dy);
    for (var i = 1; i < vertices.length; i++) {
      path.lineTo(vertices[i].dx, vertices[i].dy);
    }
    path.close();
    return path;
  }

  List<Offset> _hexagonVertices(Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final radius = math.min(size.width, size.height) / 2;

    return List.generate(6, (i) {
      final angle = -math.pi / 2 + i * math.pi / 3;
      return Offset(
        cx + radius * math.cos(angle),
        cy + radius * math.sin(angle),
      );
    });
  }

  @override
  bool shouldRepaint(covariant _RoundedHexagonPainter oldDelegate) {
    return oldDelegate.fill != fill || oldDelegate.stroke != stroke;
  }
}
