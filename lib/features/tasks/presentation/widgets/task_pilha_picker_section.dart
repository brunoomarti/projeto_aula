import 'package:flutter/material.dart';

import 'package:tasker_project/core/icons/tasker_icon.dart';

import 'package:hugeicons/hugeicons.dart';

import '../../../../app/theme/tasker_colors.dart';
import '../../../../core/widgets/tasker_sliding_segmented_control.dart';
import '../../domain/pilha.dart';
import 'complete_input.dart';
import 'task_section_card.dart';

enum TaskPilhaMode { none, existing, createNew }

/// Seletor de pilha no formulário de nova/editar tarefa.
class TaskPilhaPickerSection extends StatelessWidget {
  const TaskPilhaPickerSection({
    super.key,
    required this.mode,
    required this.pilhas,
    required this.selectedPilhaId,
    required this.newPilhaController,
    required this.enabled,
    required this.onModeChanged,
    required this.onPilhaSelected,
  });

  final TaskPilhaMode mode;
  final List<Pilha> pilhas;
  final String? selectedPilhaId;
  final TextEditingController newPilhaController;
  final bool enabled;
  final ValueChanged<TaskPilhaMode> onModeChanged;
  final ValueChanged<String?> onPilhaSelected;

  @override
  Widget build(BuildContext context) {
    return TaskSectionCard(
      title: 'Adicionar a uma pilha',
      icon: HugeIcons.strokeRoundedLayers01,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Agrupe tarefas relacionadas para vê-las empilhadas na home.',
            style: TextStyle(
              fontSize: 13,
              color: TaskerColors.secondaryText.withValues(alpha: 0.9),
            ),
          ),
          const SizedBox(height: 14),
          TaskerSlidingSegmentedControl<TaskPilhaMode>(
            selected: mode,
            onChanged: enabled ? onModeChanged : null,
            segments: [
              const TaskerSegment(
                value: TaskPilhaMode.none,
                label: 'Nenhuma',
                icon: AppHugeIcon(
                  icon: HugeIcons.strokeRoundedRemoveCircle,
                  size: 17,
                ),
              ),
              TaskerSegment(
                value: TaskPilhaMode.existing,
                label: 'Existente',
                icon: const AppHugeIcon(
                  icon: HugeIcons.strokeRoundedFolder01,
                  size: 17,
                ),
                enabled: pilhas.isNotEmpty,
              ),
              const TaskerSegment(
                value: TaskPilhaMode.createNew,
                label: 'Nova',
                icon: AppHugeIcon(
                  icon: HugeIcons.strokeRoundedAddCircle,
                  size: 17,
                ),
              ),
            ],
          ),
          if (mode == TaskPilhaMode.existing) ...[
            const SizedBox(height: 14),
            CompleteInput(
              label: 'Pilha',
              child: DropdownButtonFormField<String>(
                initialValue: selectedPilhaId ??
                    (pilhas.isNotEmpty ? pilhas.first.id : null),
                decoration: TaskerFieldDecoration.decoration(
                  hintText: 'Selecione uma pilha',
                ),
                items: [
                  for (final pilha in pilhas)
                    DropdownMenuItem(
                      value: pilha.id,
                      child: Text(pilha.name),
                    ),
                ],
                onChanged: enabled ? onPilhaSelected : null,
              ),
            ),
          ],
          if (mode == TaskPilhaMode.createNew) ...[
            const SizedBox(height: 14),
            CompleteInput(
              label: 'Nome da nova pilha',
              child: TextField(
                controller: newPilhaController,
                enabled: enabled,
                textInputAction: TextInputAction.done,
                decoration: TaskerFieldDecoration.decoration(
                  hintText: 'Ex.: Grupo CRM UNESC',
                ),
                style: TaskerFieldDecoration.textStyle,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
