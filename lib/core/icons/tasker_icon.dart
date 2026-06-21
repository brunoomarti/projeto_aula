import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import 'tasker_cat_icon.dart';
import 'tasker_drama_icon.dart';
import 'tasker_icon_glyph.dart';
import 'tasker_trees_icon.dart';

/// Sentinel para ícones customizados (não exportados no pacote Flutter 0.0.x).
abstract final class TaskIcon {
  static const catIcon = IconData(0, fontFamily: 'TaskerCatIcon');
  static const treesIcon = IconData(0, fontFamily: 'TaskerTreesIcon');
  static const dramaIcon = IconData(0, fontFamily: 'TaskerDramaIcon');
}

/// Renderiza ícones do app — Hugeicons 1.x ou ícones customizados embutidos.
class TaskerIcon extends StatelessWidget {
  const TaskerIcon({
    super.key,
    required this.icon,
    this.color,
    this.size,
  });

  final TaskerIconGlyph icon;
  final Color? color;
  final double? size;

  @override
  Widget build(BuildContext context) {
    final resolvedColor = color ?? IconTheme.of(context).color;
    final resolvedSize = size ?? IconTheme.of(context).size ?? 24.0;

    final custom = taskerIconAsCustomData(icon);
    if (custom == TaskIcon.catIcon) {
      return TaskerCatIcon(
        color: resolvedColor ?? Colors.black,
        size: resolvedSize,
      );
    }
    if (custom == TaskIcon.treesIcon) {
      return TaskerTreesIcon(
        color: resolvedColor ?? Colors.black,
        size: resolvedSize,
      );
    }
    if (custom == TaskIcon.dramaIcon) {
      return TaskerDramaIcon(
        color: resolvedColor ?? Colors.black,
        size: resolvedSize,
      );
    }

    final hugeData = taskerIconAsHugeData(icon);
    if (hugeData != null) {
      return HugeIcon(
        icon: hugeData,
        color: resolvedColor,
        size: resolvedSize,
      );
    }

    return SizedBox(width: resolvedSize, height: resolvedSize);
  }
}

/// Atalho para [HugeIcon] com cor/tamanho resolvidos do tema.
class AppHugeIcon extends StatelessWidget {
  const AppHugeIcon({
    super.key,
    required this.icon,
    this.color,
    this.size,
    this.strokeWidth,
  });

  final List<List<dynamic>> icon;
  final Color? color;
  final double? size;
  final double? strokeWidth;

  @override
  Widget build(BuildContext context) {
    return HugeIcon(
      icon: icon,
      color: color ?? IconTheme.of(context).color,
      size: size ?? IconTheme.of(context).size ?? 24.0,
      strokeWidth: strokeWidth,
    );
  }
}

/// Ícone Hugeicon dentro de caixa fixa, centralizado com respiro interno.
class TaskerIconBox extends StatelessWidget {
  const TaskerIconBox({
    super.key,
    required this.icon,
    required this.boxSize,
    this.iconSize,
    this.color,
    this.strokeWidth = 1.75,
    this.decoration,
  });

  final List<List<dynamic>> icon;
  final double boxSize;
  final double? iconSize;
  final Color? color;
  final double? strokeWidth;
  final BoxDecoration? decoration;

  /// Ícone ocupa ~50% da caixa — margem visual confortável para stroke icons.
  double get _resolvedIconSize => iconSize ?? boxSize * 0.5;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: boxSize,
      height: boxSize,
      alignment: Alignment.center,
      decoration: decoration,
      child: AppHugeIcon(
        icon: icon,
        color: color,
        size: _resolvedIconSize,
        strokeWidth: strokeWidth,
      ),
    );
  }
}

/// Quadrado arredondado com ícone Hugeicon centralizado (padrão 42×42).
class TaskerAccentIconBadge extends StatelessWidget {
  const TaskerAccentIconBadge({
    super.key,
    required this.icon,
    required this.accent,
    this.boxSize = 42,
    this.iconSize = 24,
    this.strokeWidth = 1.75,
    this.borderRadius = 12,
    this.backgroundAlpha = 0.12,
  });

  final List<List<dynamic>> icon;
  final Color accent;
  final double boxSize;
  final double iconSize;
  final double? strokeWidth;
  final double borderRadius;
  final double backgroundAlpha;

  @override
  Widget build(BuildContext context) {
    return TaskerIconBox(
      icon: icon,
      boxSize: boxSize,
      iconSize: iconSize,
      color: accent,
      strokeWidth: strokeWidth,
      decoration: BoxDecoration(
        color: accent.withValues(alpha: backgroundAlpha),
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
  }
}
