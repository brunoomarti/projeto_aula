import 'package:flutter/material.dart';

import 'package:hugeicons/hugeicons.dart';

import '../../../../app/theme/tasker_colors.dart';
import '../../../../core/icons/tasker_icon.dart';
import '../../domain/task_icon_catalog.dart';
import 'task_card.dart';

/// Seletor colapsável: preview clicável → grade de ícones e cores.
class TaskIconPickerSection extends StatefulWidget {
  const TaskIconPickerSection({
    super.key,
    required this.iconKey,
    required this.backgroundArgb,
    required this.onIconChanged,
    required this.onColorChanged,
    this.enabled = true,
  });

  final String iconKey;
  final int backgroundArgb;
  final ValueChanged<String> onIconChanged;
  final ValueChanged<int> onColorChanged;
  final bool enabled;

  @override
  State<TaskIconPickerSection> createState() => _TaskIconPickerSectionState();
}

class _TaskIconPickerSectionState extends State<TaskIconPickerSection> {
  bool _expanded = false;

  @override
  void didUpdateWidget(covariant TaskIconPickerSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled && _expanded) {
      _expanded = false;
    }
  }

  void _toggleExpanded() {
    if (!widget.enabled) return;
    setState(() => _expanded = !_expanded);
  }

  void _collapse() {
    if (!_expanded) return;
    setState(() => _expanded = false);
  }

  @override
  Widget build(BuildContext context) {
    final preset = TaskIconCatalog.presetForArgb(widget.backgroundArgb);
    final iconOption = TaskIconCatalog.optionForKey(widget.iconKey);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          button: true,
          expanded: _expanded,
          label: _expanded
              ? 'Fechar personalização de ícone e cor'
              : 'Personalizar ícone e cor da tarefa',
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.enabled ? _toggleExpanded : null,
              borderRadius: BorderRadius.circular(14),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: _expanded
                      ? TaskerColors.primary.withValues(alpha: 0.06)
                      : const Color(0xFFF7F8FC),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: _expanded
                        ? TaskerColors.primary.withValues(alpha: 0.35)
                        : const Color(0xFFE0E4EE),
                    width: _expanded ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    TaskCardIconBox(
                      icon: iconOption.icon,
                      backgroundColor: preset.background,
                      iconColor: preset.foreground,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            iconOption.label,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                              color: TaskerColors.primaryText,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            _expanded
                                ? 'Escolha abaixo ou toque aqui para fechar'
                                : 'Toque para escolher ícone e cor',
                            style: TextStyle(
                              fontSize: 13,
                              color: _expanded
                                  ? TaskerColors.primary
                                  : TaskerColors.secondaryText.withValues(
                                      alpha: 0.95,
                                    ),
                              fontWeight: _expanded
                                  ? FontWeight.w500
                                  : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ),
                    AppHugeIcon(icon: HugeIcons.strokeRoundedEdit01,
                      size: 18,
                      color: _expanded
                          ? TaskerColors.primary
                          : TaskerColors.mutedText,
                    ),
                    const SizedBox(width: 6),
                    AnimatedRotation(
                      turns: _expanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: AppHugeIcon(icon: HugeIcons.strokeRoundedArrowDown01,
                        size: 24,
                        color: _expanded
                            ? TaskerColors.primary
                            : TaskerColors.mutedText,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        AnimatedCrossFade(
          firstCurve: Curves.easeOut,
          secondCurve: Curves.easeIn,
          sizeCurve: Curves.easeInOut,
          crossFadeState: _expanded
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 220),
          firstChild: const SizedBox.shrink(),
          secondChild: Padding(
            padding: const EdgeInsets.only(top: 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Ícone',
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                    color: TaskerColors.secondaryText,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: TaskIconCatalog.icons.map((option) {
                    final selected = option.key == widget.iconKey;
                    return _IconChip(
                      option: option,
                      selected: selected,
                      enabled: widget.enabled,
                      backgroundColor: preset.background,
                      foregroundColor: preset.foreground,
                      onTap: () => widget.onIconChanged(option.key),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 18),
                Text(
                  'Cor de fundo',
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                    color: TaskerColors.secondaryText,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: TaskIconCatalog.colors.map((colorPreset) {
                    final selected =
                        colorPreset.backgroundArgb == widget.backgroundArgb;
                    return _ColorSwatch(
                      preset: colorPreset,
                      selected: selected,
                      enabled: widget.enabled,
                      onTap: () =>
                          widget.onColorChanged(colorPreset.backgroundArgb),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: widget.enabled ? _collapse : null,
                    icon: const AppHugeIcon(icon: HugeIcons.strokeRoundedTick01, size: 18),
                    label: const Text('Pronto'),
                    style: TextButton.styleFrom(
                      foregroundColor: TaskerColors.primary,
                      textStyle: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _IconChip extends StatelessWidget {
  const _IconChip({
    required this.option,
    required this.selected,
    required this.enabled,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.onTap,
  });

  final TaskIconOption option;
  final bool selected;
  final bool enabled;
  final Color backgroundColor;
  final Color foregroundColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: option.label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: selected
                  ? backgroundColor
                  : const Color(0xFFF3F4F8),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected
                    ? foregroundColor.withValues(alpha: 0.55)
                    : const Color(0xFFE0E3EB),
                width: selected ? 2 : 1,
              ),
            ),
            child: Center(
              child: TaskerIcon(
                icon: option.icon,
                size: 24,
                color: selected ? foregroundColor : TaskerColors.mutedText,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ColorSwatch extends StatelessWidget {
  const _ColorSwatch({
    required this.preset,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final TaskIconColorPreset preset;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? onTap : null,
          customBorder: const CircleBorder(),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: preset.background,
              shape: BoxShape.circle,
              border: Border.all(
                color: selected
                    ? preset.foreground
                    : Colors.white.withValues(alpha: 0.9),
                width: selected ? 3 : 2,
              ),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: preset.foreground.withValues(alpha: 0.25),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: selected
                ? AppHugeIcon(icon: HugeIcons.strokeRoundedTick01, size: 18, color: preset.foreground)
                : null,
          ),
        ),
      ),
    );
  }
}
