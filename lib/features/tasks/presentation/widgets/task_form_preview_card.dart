import 'package:flutter/material.dart';

import '../../domain/task.dart';
import 'task_card.dart';

/// Pré-visualização do card da home — preenchido conforme o formulário.
class TaskFormPreviewCard extends StatelessWidget {
  const TaskFormPreviewCard({
    super.key,
    required this.task,
  });

  final Task task;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        child: KeyedSubtree(
          key: ValueKey<String>(
            '${task.title}|${task.descricao}|${task.data}|${task.hora}|'
            '${task.iconKey}|${task.iconBackgroundArgb}|${task.done}|'
            '${task.location?.lat}|${task.location?.lng}|${task.location?.name}',
          ),
          child: TaskCardSurface(
            task: task,
            showDoneToggle: false,
            applyDoneOpacity: true,
            titleMaxLines: 1,
            descriptionMaxLines: 1,
          ),
        ),
      ),
    );
  }
}
