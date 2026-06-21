import 'package:flutter/material.dart';

/// DramaIcon do Hugeicons (@hugeicons/core-free-icons) — ainda não exportado
/// como `HugeIcons.strokeRoundedDrama` no pacote Flutter 0.0.x.
class TaskerDramaIcon extends StatelessWidget {
  const TaskerDramaIcon({
    super.key,
    required this.color,
    this.size = 24,
  });

  final Color color;
  final double size;

  static const _viewBox = 24.0;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        size: Size(size, size),
        painter: _TaskerDramaIconPainter(color: color),
      ),
    );
  }
}

class _TaskerDramaIconPainter extends CustomPainter {
  const _TaskerDramaIconPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / TaskerDramaIcon._viewBox;
    final iconPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5 * scale
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.scale(scale);

    final happyMask = Path()
      ..moveTo(22, 13.9844)
      ..cubicTo(22, 17.1977, 19.4586, 19.228, 17.2347, 20.6198)
      ..cubicTo(16.4908, 21.1294, 15.5092, 21.1294, 14.7653, 20.6198)
      ..cubicTo(12.5414, 19.228, 10, 17.1977, 10, 13.9844)
      ..lineTo(10, 11.7012)
      ..cubicTo(10, 9.93499, 10, 9.05189, 10.7684, 8.19878)
      ..cubicTo(11.5369, 7.34566, 12.2207, 7.27251, 13.5884, 7.1262)
      ..cubicTo(14.3394, 7.04585, 15.1519, 7.00195, 16, 7.00195)
      ..cubicTo(16.8481, 7.00195, 17.6606, 7.04585, 18.4116, 7.1262)
      ..cubicTo(19.7793, 7.27251, 20.4631, 7.34566, 21.2316, 8.19878)
      ..cubicTo(22, 9.05189, 22, 9.93499, 22, 11.7012)
      ..lineTo(22, 13.9844)
      ..close();
    canvas.drawPath(happyMask, iconPaint);

    final smile = Path()
      ..moveTo(18, 15.4802)
      ..cubicTo(17.6008, 16.0765, 16.8546, 16.4777, 16, 16.4777)
      ..cubicTo(15.1454, 16.4777, 14.3992, 16.0765, 14, 15.4802);
    canvas.drawPath(smile, iconPaint);

    canvas.drawLine(const Offset(18, 11.4902), const Offset(19, 11.4902), iconPaint);
    canvas.drawLine(const Offset(13, 11.4902), const Offset(14, 11.4902), iconPaint);

    final sadMask = Path()
      ..moveTo(10.2472, 16.989)
      ..cubicTo(9.93106, 17.0237, 9.60485, 16.9893, 9.29198, 16.8796)
      ..cubicTo(6.81334, 16.1238, 3.86807, 14.8429, 3.04447, 11.7967)
      ..lineTo(2.45927, 9.63216)
      ..cubicTo(2.00658, 7.95778, 1.78024, 7.12059, 2.29478, 6.11712)
      ..cubicTo(2.80933, 5.11365, 3.44306, 4.87102, 4.71051, 4.38578)
      ..cubicTo(5.4065, 4.11932, 6.1705, 3.87182, 6.97973, 3.65693)
      ..cubicTo(7.78896, 3.44203, 8.57547, 3.27777, 9.31264, 3.16365)
      ..cubicTo(10.6551, 2.95581, 11.3263, 2.85189, 12.2782, 3.46595)
      ..cubicTo(13.23, 4.08, 13.4564, 4.91719, 13.9091, 6.59157)
      ..lineTo(14, 6.92785);
    canvas.drawPath(sadMask, iconPaint);

    final sadDetails = Path()
      ..moveTo(7.53398, 13.0918)
      ..cubicTo(7.76753, 12.387, 8.39125, 11.7849, 9.22623, 11.5559)
      ..cubicTo(9.44557, 11.4957, 9.66486, 11.4653, 9.87891, 11.4621)
      ..moveTo(5.37891, 8.85975)
      ..lineTo(6.35592, 8.5918);
    canvas.drawPath(sadDetails, iconPaint);
  }

  @override
  bool shouldRepaint(covariant _TaskerDramaIconPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
