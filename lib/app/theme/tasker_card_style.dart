import 'package:flutter/material.dart';

import 'tasker_colors.dart';

/// Estilo compartilhado dos cards de seção (detalhes, formulário, ações).
abstract final class TaskerCardStyle {
  static const Color background = Color(0xFFFAFAFA);
  static const double borderRadius = 20;
  static const double elevation = 2;
  static const Color shadowColor = Color.fromARGB(99, 0, 0, 0);
  static const Color splashColor = Color(0x1A000000);
  static const Color highlightColor = Color(0x0D000000);

  /// Padding interno padrão dos cards de seção.
  static const EdgeInsets contentPadding = EdgeInsets.fromLTRB(18, 16, 18, 18);

  /// Espaço entre cards empilhados na mesma tela.
  static const double sectionSpacing = 16;

  /// Espaço entre o título da seção e o conteúdo.
  static const double sectionHeaderGap = 14;

  /// Tiles internos (info, campos agrupados).
  static const double innerTileRadius = 12;

  /// Ícone de ação dentro do card (ex.: concluir, toggle).
  static const double actionIconBoxSize = 44;
  static const double actionIconBoxRadius = 12;
  static const Color actionIconInactiveBackground = Color(0xFFE8EAF0);

  static const TextStyle sectionTitle = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    color: TaskerColors.primaryText,
    height: 1.2,
  );

  static const TextStyle actionTitle = TextStyle(
    fontWeight: FontWeight.w600,
    fontSize: 15,
    color: TaskerColors.primaryText,
    height: 1.2,
  );

  static const TextStyle actionSubtitle = TextStyle(
    fontSize: 12,
    height: 1.25,
    color: TaskerColors.secondaryText,
  );

  static ShapeBorder get shape => RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(borderRadius),
      );
}
