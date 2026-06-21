import 'package:flutter/material.dart';

/// Dimensões compartilhadas entre header flutuante e footer/dock.
abstract final class TaskerPageChrome {
  static const horizontalInset = 22.0;

  /// Altura da cápsula do header (voltar + título).
  static const pillHeight = 58.0;
}

/// Métricas do dock inferior — home e footer de formulário.
abstract final class TaskerDockMetrics {
  static const barHeight = 68.0;
  static const horizontalInset = 22.0;
  static const bottomInset = 14.0;

  static double reservedHeight(BuildContext context) {
    return barHeight +
        bottomInset +
        MediaQuery.paddingOf(context).bottom;
  }
}
