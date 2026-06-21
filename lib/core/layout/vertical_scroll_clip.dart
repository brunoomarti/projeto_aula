import 'package:flutter/material.dart';

/// Recorta só o eixo vertical — sombras, brilho e scale dos cards
/// podem ultrapassar as laterais sem serem cortados.
class VerticalScrollClip extends StatelessWidget {
  const VerticalScrollClip({
    super.key,
    required this.child,
    this.horizontalBleed = 28,
  });

  final Widget child;

  /// Quanto o clip se estende além das laterais do layout.
  final double horizontalBleed;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      clipper: _VerticalScrollClipper(horizontalBleed: horizontalBleed),
      child: child,
    );
  }
}

class _VerticalScrollClipper extends CustomClipper<Rect> {
  const _VerticalScrollClipper({required this.horizontalBleed});

  final double horizontalBleed;

  @override
  Rect getClip(Size size) {
    return Rect.fromLTRB(
      -horizontalBleed,
      0,
      size.width + horizontalBleed,
      size.height,
    );
  }

  @override
  bool shouldReclip(covariant _VerticalScrollClipper oldClipper) {
    return oldClipper.horizontalBleed != horizontalBleed;
  }
}
