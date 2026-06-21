import 'package:flutter/material.dart';

import 'package:tasker_project/core/icons/tasker_icon.dart';
import 'package:tasker_project/core/icons/tasker_icon_glyph.dart';

import 'package:hugeicons/hugeicons.dart';

import 'task.dart';

/// Par de cores para o quadrado do ícone (fundo claro + ícone escuro).
class TaskIconColorPreset {
  const TaskIconColorPreset({
    required this.background,
    required this.foreground,
  });

  final Color background;
  final Color foreground;

  int get backgroundArgb => background.toARGB32();
}

/// Definição de um ícone selecionável para tarefas.
class TaskIconOption {
  const TaskIconOption({
    required this.key,
    required this.icon,
    required this.label,
  });

  final String key;
  final TaskerIconGlyph icon;
  final String label;
}

/// Ícones e paleta de cores pré-definidos para personalização de tarefas.
abstract final class TaskIconCatalog {
  static const defaultIconKey = 'home';

  static const TaskIconColorPreset defaultColor = TaskIconColorPreset(
    background: Color(0xFFD4CCFF),
    foreground: Color(0xFF4A3D9E),
  );

  /// 12 tons suaves com ícone escuro na mesma família — estilo do card de referência.
  static const List<TaskIconColorPreset> colors = [
    TaskIconColorPreset(
      background: Color(0xFFD4CCFF),
      foreground: Color(0xFF4A3D9E),
    ),
    TaskIconColorPreset(
      background: Color(0xFFB8F0D0),
      foreground: Color(0xFF1F6B4A),
    ),
    TaskIconColorPreset(
      background: Color(0xFFD4F5A8),
      foreground: Color(0xFF4A6620),
    ),
    TaskIconColorPreset(
      background: Color(0xFFFFF0A8),
      foreground: Color(0xFF7A6518),
    ),
    TaskIconColorPreset(
      background: Color(0xFFFFD4CC),
      foreground: Color(0xFF9E4038),
    ),
    TaskIconColorPreset(
      background: Color(0xFFB8E4FF),
      foreground: Color(0xFF1F5A8A),
    ),
    TaskIconColorPreset(
      background: Color(0xFFFFE0C8),
      foreground: Color(0xFF8A5020),
    ),
    TaskIconColorPreset(
      background: Color(0xFFFFCCE8),
      foreground: Color(0xFF8A2860),
    ),
    TaskIconColorPreset(
      background: Color(0xFFB8F0F0),
      foreground: Color(0xFF1F6A6A),
    ),
    TaskIconColorPreset(
      background: Color(0xFFFFDAB8),
      foreground: Color(0xFF8A4820),
    ),
    TaskIconColorPreset(
      background: Color(0xFFC8CCFF),
      foreground: Color(0xFF3838A0),
    ),
    TaskIconColorPreset(
      background: Color(0xFFD8DCE8),
      foreground: Color(0xFF4A5060),
    ),
  ];

  static const List<TaskIconOption> icons = [
    TaskIconOption(
      key: 'home',
      icon: HugeIcons.strokeRoundedGuestHouse,
      label: 'Casa',
    ),
    TaskIconOption(
      key: 'gym',
      icon: HugeIcons.strokeRoundedDumbbell01,
      label: 'Academia',
    ),
    TaskIconOption(
      key: 'ball_sports',
      icon: HugeIcons.strokeRoundedFootball,
      label: 'Esporte com bola',
    ),
    TaskIconOption(
      key: 'swimming',
      icon: HugeIcons.strokeRoundedSwimming,
      label: 'Natação',
    ),
    TaskIconOption(
      key: 'market',
      icon: HugeIcons.strokeRoundedShoppingCart01,
      label: 'Mercado',
    ),
    TaskIconOption(
      key: 'shopping',
      icon: HugeIcons.strokeRoundedShoppingBag01,
      label: 'Compras',
    ),
    TaskIconOption(
      key: 'food',
      icon: HugeIcons.strokeRoundedDish02,
      label: 'Comida',
    ),
    TaskIconOption(
      key: 'people',
      icon: HugeIcons.strokeRoundedUserGroup,
      label: 'Pessoas',
    ),
    TaskIconOption(key: 'tree', icon: TaskIcon.treesIcon, label: 'Natureza'),
    TaskIconOption(
      key: 'walk',
      icon: HugeIcons.strokeRoundedWorkoutRun,
      label: 'Caminhada',
    ),
    TaskIconOption(key: 'work', icon: HugeIcons.strokeRoundedBriefcase01, label: 'Trabalho'),
    TaskIconOption(
      key: 'study',
      icon: HugeIcons.strokeRoundedMortarboard01,
      label: 'Estudo',
    ),
    TaskIconOption(
      key: 'health',
      icon: HugeIcons.strokeRoundedHealth,
      label: 'Saúde',
    ),
    TaskIconOption(key: 'pets', icon: TaskIcon.catIcon, label: 'Pets'),
    TaskIconOption(
      key: 'leisure',
      icon: TaskIcon.dramaIcon,
      label: 'Lazer',
    ),
    TaskIconOption(key: 'travel', icon: HugeIcons.strokeRoundedAirplane01, label: 'Viagem'),
    TaskIconOption(key: 'event', icon: HugeIcons.strokeRoundedCalendar03, label: 'Evento'),
    TaskIconOption(
      key: 'repair',
      icon: HugeIcons.strokeRoundedTools,
      label: 'Manutenção',
    ),
    TaskIconOption(
      key: 'clothing',
      icon: HugeIcons.strokeRoundedHanger,
      label: 'Roupa',
    ),
    TaskIconOption(
      key: 'beauty',
      icon: HugeIcons.strokeRoundedPerfume,
      label: 'Beleza',
    ),
    TaskIconOption(
      key: 'faith',
      icon: HugeIcons.strokeRoundedChurch,
      label: 'Fé',
    ),
    TaskIconOption(
      key: 'task',
      icon: HugeIcons.strokeRoundedTask01,
      label: 'Tarefa',
    ),
  ];

  static TaskIconOption optionForKey(String? key) {
    final k = key ?? defaultIconKey;
    return icons.firstWhere(
      (o) => o.key == k,
      orElse: () => icons.first,
    );
  }

  static TaskerIconGlyph iconFor(Task task) => optionForKey(task.iconKey).icon;

  static String labelFor(Task task) => optionForKey(task.iconKey).label;

  static Color backgroundFor(Task task) {
    final argb = task.iconBackgroundArgb;
    if (argb != null) return Color(argb);
    return defaultColor.background;
  }

  static Color foregroundFor(Task task) =>
      foregroundForBackground(backgroundFor(task));

  static Color foregroundForBackground(Color background) {
    for (final preset in colors) {
      if (preset.background.toARGB32() == background.toARGB32()) {
        return preset.foreground;
      }
    }

    final hsl = HSLColor.fromColor(background);
    return hsl
        .withLightness((hsl.lightness * 0.42).clamp(0.18, 0.45))
        .withSaturation((hsl.saturation * 1.12).clamp(0.35, 1.0))
        .toColor();
  }

  static TaskIconColorPreset presetForArgb(int? argb) {
    if (argb == null) return defaultColor;
    for (final preset in colors) {
      if (preset.backgroundArgb == argb) return preset;
    }
    final bg = Color(argb);
    return TaskIconColorPreset(
      background: bg,
      foreground: foregroundForBackground(bg),
    );
  }
}
