import 'achievement_trail_id.dart';

/// Rótulos curtos do marco exibidos no subtítulo da medalha desbloqueada.
abstract final class AchievementMilestoneLabel {
  static String forMedal({
    required AchievementTrailId trail,
    required int threshold,
  }) {
    return switch (trail) {
      AchievementTrailId.tasksCreated => _count(
          threshold,
          one: '1 tarefa criada',
          many: '$threshold tarefas criadas',
        ),
      AchievementTrailId.unfinishedTasks => threshold == 1
          ? '1 dia com pendências'
          : 'Acumule $threshold dias com pendências',
      AchievementTrailId.taskAdvances => _count(
          threshold,
          one: '1 adiantamento',
          many: '$threshold adiantamentos',
        ),
      AchievementTrailId.daysCompleted => _count(
          threshold,
          one: '1 dia completo',
          many: '$threshold dias completos',
        ),
      AchievementTrailId.pilhasCreated => _count(
          threshold,
          one: '1 pilha criada',
          many: '$threshold pilhas criadas',
        ),
      AchievementTrailId.magicInput => _count(
          threshold,
          one: '1 tarefa no Magic Input',
          many: '$threshold tarefas no Magic Input',
        ),
      AchievementTrailId.curiosities => threshold == 1
          ? '1 conquista lendária'
          : '$threshold conquistas lendárias',
    };
  }

  static String _count(
    int threshold, {
    required String one,
    required String many,
  }) {
    return threshold == 1 ? one : many;
  }
}
