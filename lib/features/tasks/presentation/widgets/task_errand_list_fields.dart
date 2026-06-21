import 'package:flutter/material.dart';

import 'package:tasker_project/core/icons/tasker_icon.dart';

import 'package:hugeicons/hugeicons.dart';

import '../../../../app/theme/tasker_colors.dart';
import 'complete_input.dart';

/// Campos editáveis para itens de uma lista de afazeres.
class TaskErrandListFields extends StatelessWidget {
  const TaskErrandListFields({
    super.key,
    required this.controllers,
    required this.onAdd,
    required this.onRemove,
    this.enabled = true,
  });

  final List<TextEditingController> controllers;
  final VoidCallback onAdd;
  final ValueChanged<int> onRemove;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < controllers.length; i++) ...[
          if (i > 0) const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  '${i + 1}.',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: TaskerColors.secondaryText.withValues(alpha: 0.85),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: controllers[i],
                  enabled: enabled,
                  textInputAction: TextInputAction.next,
                  decoration: TaskerFieldDecoration.decoration(
                    hintText: 'Ex.: Comprar leite',
                  ),
                  style: TaskerFieldDecoration.textStyle,
                  onSubmitted: (_) {
                    if (i == controllers.length - 1) onAdd();
                  },
                ),
              ),
              if (controllers.length > 1) ...[
                const SizedBox(width: 4),
                IconButton(
                  onPressed: enabled ? () => onRemove(i) : null,
                  tooltip: 'Remover afazer',
                  visualDensity: VisualDensity.compact,
                  icon: AppHugeIcon(icon: HugeIcons.strokeRoundedRemoveCircle,
                    size: 22,
                    color: enabled
                        ? TaskerColors.secondaryText.withValues(alpha: 0.75)
                        : TaskerColors.mutedText,
                  ),
                ),
              ],
            ],
          ),
        ],
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: enabled ? onAdd : null,
            icon: const AppHugeIcon(icon: HugeIcons.strokeRoundedAdd01, size: 20),
            label: const Text('Adicionar afazer'),
            style: TextButton.styleFrom(
              foregroundColor: TaskerColors.primary,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            ),
          ),
        ),
      ],
    );
  }
}
