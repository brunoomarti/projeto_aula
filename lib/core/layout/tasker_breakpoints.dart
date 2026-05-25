import 'package:flutter/material.dart';

/// Breakpoints compartilhados para layout responsivo.
class TaskerBreakpoints {
  const TaskerBreakpoints._();

  /// Telas estreitas (celular em portrait).
  static const double compact = 600;

  /// Telas largas (tablet landscape / desktop web).
  static const double wide = 960;

  /// Largura máxima do formulário em coluna única.
  static const double formMaxWidth = 680;

  /// Largura máxima quando o layout usa duas colunas.
  static const double formWideMaxWidth = 1100;

  static bool isCompact(double width) => width < compact;

  static bool isWide(double width) => width >= wide;

  static double contentMaxWidth(double width) =>
      isWide(width) ? formWideMaxWidth : formMaxWidth;

  static double mapHeight(double width) {
    if (width >= wide) return 360;
    if (width >= compact) return 280;
    return 200;
  }

  /// Mapa de preview (somente leitura) em telas de detalhe.
  static double previewMapHeight(double width) {
    if (width >= wide) return 280;
    if (width >= compact) return 220;
    return 168;
  }

  static EdgeInsets pagePadding(double width) {
    if (width >= wide) {
      return const EdgeInsets.fromLTRB(32, 24, 32, 32);
    }
    if (width >= compact) {
      return const EdgeInsets.fromLTRB(24, 20, 24, 28);
    }
    return const EdgeInsets.fromLTRB(20, 20, 20, 28);
  }

  static double horizontalInset(double width) {
    final maxW = contentMaxWidth(width);
    return ((width - maxW) / 2).clamp(0.0, width / 2);
  }
}

/// Limita a largura e centraliza horizontalmente sem expandir na vertical.
class TaskerResponsiveContent extends StatelessWidget {
  const TaskerResponsiveContent({
    super.key,
    required this.width,
    required this.child,
    this.padding,
  });

  final double width;
  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final inset = TaskerBreakpoints.horizontalInset(width);
    final maxW = TaskerBreakpoints.contentMaxWidth(width);
    final outerPadding = padding ?? EdgeInsets.zero;

    return Padding(
      padding: EdgeInsets.fromLTRB(inset, 0, inset, 0).add(outerPadding),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxW),
          child: child,
        ),
      ),
    );
  }
}
