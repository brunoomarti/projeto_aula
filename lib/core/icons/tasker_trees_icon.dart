import 'package:flutter/material.dart';

/// TreesIcon do Hugeicons — ainda não exportado como `HugeIcons.strokeRoundedTrees`
/// no pacote Flutter 0.0.x.
class TaskerTreesIcon extends StatelessWidget {
  const TaskerTreesIcon({
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
        painter: _TaskerTreesIconPainter(color: color),
      ),
    );
  }
}

class _TaskerTreesIconPainter extends CustomPainter {
  const _TaskerTreesIconPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / TaskerTreesIcon._viewBox;
    final iconPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5 * scale
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.scale(scale);

    final bush = Path()
      ..moveTo(3, 13)
      ..lineTo(3, 9)
      ..cubicTo(3, 7.34315, 4.34315, 6, 6, 6)
      ..lineTo(8, 6)
      ..cubicTo(9.65685, 6, 11, 7.34315, 11, 9)
      ..lineTo(11, 13)
      ..cubicTo(11, 14.6569, 9.65685, 16, 8, 16)
      ..lineTo(6, 16)
      ..cubicTo(4.34315, 16, 3, 14.6569, 3, 13)
      ..close();
    canvas.drawPath(bush, iconPaint);

    final tree = Path()
      ..moveTo(10, 3.5)
      ..lineTo(11.1599, 2.34017)
      ..cubicTo(11.3777, 2.12236, 11.6731, 2, 11.9811, 2)
      ..cubicTo(12.3113, 2, 12.6259, 2.14057, 12.8462, 2.38654)
      ..lineTo(16.7929, 6.79289)
      ..cubicTo(16.9255, 6.9255, 17, 7.10536, 17, 7.29289)
      ..cubicTo(17, 7.68342, 16.6834, 8, 16.2929, 8)
      ..lineTo(15, 8)
      ..lineTo(18.7929, 11.7929)
      ..cubicTo(18.9255, 11.9255, 19, 12.1054, 19, 12.2929)
      ..cubicTo(19, 12.6834, 18.6834, 13, 18.2929, 13)
      ..lineTo(17, 13)
      ..lineTo(20.7929, 16.7929)
      ..cubicTo(20.9255, 16.9255, 21, 17.1054, 21, 17.2929)
      ..cubicTo(21, 17.6834, 20.6834, 18, 20.2929, 18)
      ..lineTo(12, 18);
    canvas.drawPath(tree, iconPaint);

    canvas.drawLine(const Offset(13, 18), const Offset(13, 22), iconPaint);
    canvas.drawLine(const Offset(7, 11), const Offset(7, 22), iconPaint);
  }

  @override
  bool shouldRepaint(covariant _TaskerTreesIconPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
