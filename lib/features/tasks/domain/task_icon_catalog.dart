import 'package:flutter/material.dart';

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
  final IconData icon;
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
    TaskIconOption(key: 'home', icon: Icons.home_outlined, label: 'Casa'),
    TaskIconOption(
      key: 'gym',
      icon: Icons.fitness_center_outlined,
      label: 'Academia',
    ),
    TaskIconOption(
      key: 'market',
      icon: Icons.shopping_cart_outlined,
      label: 'Mercado',
    ),
    TaskIconOption(
      key: 'shopping',
      icon: Icons.shopping_bag_outlined,
      label: 'Compras',
    ),
    TaskIconOption(
      key: 'food',
      icon: Icons.restaurant_outlined,
      label: 'Comida',
    ),
    TaskIconOption(
      key: 'people',
      icon: Icons.groups_outlined,
      label: 'Pessoas',
    ),
    TaskIconOption(key: 'tree', icon: Icons.park_outlined, label: 'Natureza'),
    TaskIconOption(
      key: 'walk',
      icon: Icons.directions_walk_outlined,
      label: 'Caminhada',
    ),
    TaskIconOption(key: 'work', icon: Icons.work_outline, label: 'Trabalho'),
    TaskIconOption(key: 'study', icon: Icons.school_outlined, label: 'Estudo'),
    TaskIconOption(
      key: 'health',
      icon: Icons.medical_services_outlined,
      label: 'Saúde',
    ),
    TaskIconOption(key: 'pets', icon: Icons.pets_outlined, label: 'Pets'),
    TaskIconOption(key: 'travel', icon: Icons.flight_outlined, label: 'Viagem'),
    TaskIconOption(key: 'event', icon: Icons.event_outlined, label: 'Evento'),
    TaskIconOption(
      key: 'repair',
      icon: Icons.build_outlined,
      label: 'Manutenção',
    ),
    TaskIconOption(
      key: 'clothing',
      icon: Icons.checkroom_outlined,
      label: 'Roupa',
    ),
    TaskIconOption(
      key: 'beauty',
      icon: Icons.spa_outlined,
      label: 'Beleza',
    ),
    TaskIconOption(
      key: 'faith',
      icon: Icons.church_outlined,
      label: 'Fé',
    ),
    TaskIconOption(
      key: 'task',
      icon: Icons.task_alt_outlined,
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

  static IconData iconFor(Task task) => optionForKey(task.iconKey).icon;

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
