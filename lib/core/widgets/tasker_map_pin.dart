import 'package:flutter/material.dart';

/// Pin de mapa preenchível — substitui ícones outline no centro do mapa.
class TaskerMapPin extends StatelessWidget {
  const TaskerMapPin({
    super.key,
    required this.fillColor,
    this.size = 32,
    this.showHole = true,
    this.showGroundShadow = false,
  });

  final Color fillColor;
  final double size;
  final bool showHole;

  /// Sombra oval sob a ponta (útil em mapas estáticos).
  final bool showGroundShadow;

  static const _viewW = 24.0;
  static const _viewH = 36.0;

  @override
  Widget build(BuildContext context) {
    final height = size * (_viewH / _viewW);

    return SizedBox(
      width: size,
      height: height,
      child: CustomPaint(
        size: Size(size, height),
        painter: _TaskerMapPinPainter(
          fillColor: fillColor,
          showHole: showHole,
          showGroundShadow: showGroundShadow,
        ),
      ),
    );
  }

  /// Deslocamento para ancorar a ponta do pin no centro do mapa.
  static Offset centerAnchorOffset(double size) {
    final height = size * (_viewH / _viewW);
    return Offset(0, -height / 2);
  }
}

class _TaskerMapPinPainter extends CustomPainter {
  const _TaskerMapPinPainter({
    required this.fillColor,
    required this.showHole,
    required this.showGroundShadow,
  });

  final Color fillColor;
  final bool showHole;
  final bool showGroundShadow;

  Path _bodyPath() {
    return Path()
      ..moveTo(12, 36)
      ..cubicTo(12, 36, 1.5, 22, 1.5, 11.5)
      ..cubicTo(1.5, 5.6, 6.15, 1, 12, 1)
      ..cubicTo(17.85, 1, 22.5, 5.6, 22.5, 11.5)
      ..cubicTo(22.5, 22, 12, 36, 12, 36)
      ..close();
  }

  Path _holePath() {
    return Path()
      ..addOval(
        Rect.fromCircle(center: const Offset(12, 11.5), radius: 3.8),
      );
  }

  Path _filledPath() {
    final body = _bodyPath();
    if (!showHole) return body;
    return Path.combine(PathOperation.difference, body, _holePath());
  }

  @override
  void paint(Canvas canvas, Size size) {
    final scaleX = size.width / TaskerMapPin._viewW;
    final scaleY = size.height / TaskerMapPin._viewH;
    canvas.scale(scaleX, scaleY);

    if (showGroundShadow) {
      final shadowPaint = Paint()..color = Colors.black.withValues(alpha: 0.2);
      canvas.drawOval(
        Rect.fromCenter(center: const Offset(12, 35), width: 8, height: 3),
        shadowPaint,
      );
    }

    final bodyPaint = Paint()
      ..color = fillColor
      ..style = PaintingStyle.fill;

    canvas.drawPath(_filledPath(), bodyPaint);
  }

  @override
  bool shouldRepaint(covariant _TaskerMapPinPainter oldDelegate) {
    return oldDelegate.fillColor != fillColor ||
        oldDelegate.showHole != showHole ||
        oldDelegate.showGroundShadow != showGroundShadow;
  }
}
