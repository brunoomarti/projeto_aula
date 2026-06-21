import 'dart:ui';

import 'package:flutter/material.dart';

/// Forma da superfície de vidro.
enum TaskerGlassShape {
  /// Cantos arredondados fixos via [borderRadius].
  roundedRect,

  /// Cápsula — raio = metade da altura quando [height] está definido.
  pill,

  /// Círculo perfeito — exige [width] == [height].
  circle,
}

/// Superfície com efeito de vidro fosco (blur + translucidez + borda clara).
///
/// Usado no dock da home, headers flutuantes e outros elementos sobre conteúdo.
class TaskerGlassSurface extends StatelessWidget {
  const TaskerGlassSurface({
    super.key,
    required this.child,
    this.borderRadius,
    this.shape = TaskerGlassShape.roundedRect,
    this.blurSigma = 32,
    this.tint = Colors.white,
    this.tintOpacity = 0.55,
    this.borderColor,
    this.borderOpacity = 0.72,
    this.borderWidth = 1,
    this.shadows = defaultShadows,
    this.width,
    this.height,
    this.padding,
  });

  final Widget child;
  final BorderRadius? borderRadius;
  final TaskerGlassShape shape;
  final double blurSigma;
  final Color tint;
  final double tintOpacity;
  final Color? borderColor;
  final double borderOpacity;
  final double borderWidth;
  final List<BoxShadow>? shadows;
  final double? width;
  final double? height;
  final EdgeInsetsGeometry? padding;

  static const defaultShadows = [
    BoxShadow(
      color: Color(0x1A000000),
      blurRadius: 24,
      offset: Offset(0, 8),
    ),
    BoxShadow(
      color: Color(0x0D000000),
      blurRadius: 6,
      offset: Offset(0, 2),
    ),
  ];

  BorderRadius _resolveBorderRadius() {
    if (shape == TaskerGlassShape.circle) {
      return BorderRadius.circular(9999);
    }
    if (shape == TaskerGlassShape.pill && height != null) {
      return BorderRadius.circular(height! / 2);
    }
    return borderRadius ?? BorderRadius.circular(16);
  }

  @override
  Widget build(BuildContext context) {
    final radius = _resolveBorderRadius();
    final effectiveBorderColor = borderColor ?? Colors.white;

    var content = child;
    if (padding != null) {
      content = Padding(padding: padding!, child: content);
    }
    if (width != null || height != null) {
      content = SizedBox(
        width: width ?? double.infinity,
        height: height,
        child: content,
      );
    }

    return RepaintBoundary(
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          boxShadow: shadows,
        ),
        child: ClipRRect(
          borderRadius: radius,
          child: Stack(
            children: [
              Positioned.fill(
                child: BackdropFilter(
                  filter: ImageFilter.blur(
                    sigmaX: blurSigma,
                    sigmaY: blurSigma,
                  ),
                  child: const ColoredBox(color: Colors.transparent),
                ),
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: tint.withValues(alpha: tintOpacity),
                  border: Border.all(
                    color: effectiveBorderColor.withValues(alpha: borderOpacity),
                    width: borderWidth,
                  ),
                  borderRadius: radius,
                ),
                child: content,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
