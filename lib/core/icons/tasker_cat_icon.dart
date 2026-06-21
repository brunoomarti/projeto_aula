import 'package:flutter/material.dart';

/// CatIcon do Hugeicons (@hugeicons/core-free-icons) — ainda não exportado
/// como `HugeIcons.strokeRoundedCat` no pacote Flutter 0.0.x.
class TaskerCatIcon extends StatelessWidget {
  const TaskerCatIcon({
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
        painter: _TaskerCatIconPainter(color: color),
      ),
    );
  }
}

class _TaskerCatIconPainter extends CustomPainter {
  const _TaskerCatIconPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / TaskerCatIcon._viewBox;
    final iconPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5 * scale
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.scale(scale);

    canvas.drawLine(const Offset(8, 11.0059), const Offset(8, 11.5059), iconPaint);
    canvas.drawLine(const Offset(16, 11.0059), const Offset(16, 11.5059), iconPaint);

    final nose = Path()
      ..moveTo(11, 15.0039)
      ..lineTo(13, 15.0039)
      ..lineTo(12, 16.0039)
      ..close();
    canvas.drawPath(nose, iconPaint);

    final head = Path()
      ..moveTo(12, 21)
      ..cubicTo(7.02944, 21, 3, 17.4204, 3, 13.0048)
      ..cubicTo(3, 12.0531, 3.18719, 11.1402, 3.53066, 10.2936)
      ..cubicTo(3.73678, 9.78553, 3.83984, 9.5315, 3.85136, 9.37485)
      ..cubicTo(3.86289, 9.2182, 3.79135, 8.92393, 3.64826, 8.3354)
      ..cubicTo(3.48638, 7.66957, 3.4236, 6.9388, 3.42029, 6.21803)
      ..cubicTo(3.41215, 4.45075, 3.40808, 3.56711, 4.21032, 3.14258)
      ..cubicTo(5.01255, 2.71805, 5.82239, 3.27349, 7.44206, 4.38436)
      ..cubicTo(7.57926, 4.47847, 7.71208, 4.56999, 7.83857, 4.65769)
      ..cubicTo(8.41215, 5.05532, 8.69893, 5.25414, 8.88778, 5.29711)
      ..cubicTo(9.07663, 5.34007, 9.51313, 5.27022, 10.3861, 5.13051)
      ..cubicTo(10.8215, 5.06083, 11.3595, 5.00958, 12, 5.00958)
      ..cubicTo(12.6405, 5.00958, 13.1785, 5.06083, 13.6139, 5.13051)
      ..cubicTo(14.4869, 5.27022, 14.9234, 5.34007, 15.1122, 5.29711)
      ..cubicTo(15.3011, 5.25414, 15.5878, 5.05533, 16.1614, 4.6577)
      ..cubicTo(16.2879, 4.56999, 16.4207, 4.47847, 16.5579, 4.38436)
      ..cubicTo(18.1776, 3.27349, 18.9874, 2.71805, 19.7897, 3.14258)
      ..cubicTo(20.5919, 3.56711, 20.5878, 4.45075, 20.5797, 6.21803)
      ..cubicTo(20.5764, 6.9388, 20.5136, 7.66957, 20.3517, 8.33539)
      ..cubicTo(20.2087, 8.92393, 20.1371, 9.2182, 20.1486, 9.37485)
      ..cubicTo(20.1602, 9.5315, 20.2632, 9.78553, 20.4693, 10.2936)
      ..cubicTo(20.8128, 11.1402, 21, 12.0531, 21, 13.0048)
      ..cubicTo(21, 17.4204, 16.9706, 21, 12, 21)
      ..close();
    canvas.drawPath(head, iconPaint);
  }

  @override
  bool shouldRepaint(covariant _TaskerCatIconPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
