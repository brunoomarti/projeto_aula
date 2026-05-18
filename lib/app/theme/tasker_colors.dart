import 'package:flutter/material.dart';

/// Paleta única espelhando [tasker-main/src/css/index.css] e [task.css].
abstract final class TaskerColors {
  static const Color primary = Color(0xFF2864F0);
  static const Color primaryText = Color(0xFF242424);
  static const Color secondaryText = Color(0xFF4C4C4C);
  static const Color mutedText = Color(0xFFA5A5A5);

  /// `--app-background-color`
  static const Color appBackground = Color(0xFFE3E5F0);

  /// `.task-card` / cards de tarefa
  static const Color cardBackground = Color(0xFFFAFAFA);
  static const Color cardBorder = Color(0xFFFFFFFF);
  static const Color cardShadow = Color(0x14000000); // rgba(0,0,0,0.08)

  /// `.task-icon-container`
  static const Color iconBackground = Color(0xFFA4DEF9);

  /// `.task-body .status` borda
  static const Color statusBorder = Color(0xFF7D7D7D);

  /// `input` / `textarea` — fundo e foco
  static const Color inputFill = Color(0xBFFFFFFF); // rgba(255,255,255,0.75)
  static const Color inputFocusRing = Color(0x282864F0); // rgba(40,100,240,0.158)

  /// `.navbar-bottom`
  static const Color dockBackground = Color(0x88FFFFFF);
  static const Color dockBorder = Color(0xFFEEEEEE);
}
