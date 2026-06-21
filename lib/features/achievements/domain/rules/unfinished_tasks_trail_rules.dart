import '../../../tasks/domain/task.dart';
import '../../../tasks/presentation/state/task_store.dart';
import '../achievement_event.dart';
import '../achievement_trail_id.dart';
import 'achievement_day_utils.dart';

/// Trilha **Tarefas Não Concluídas** — máx. 1 ponto por dia civil.
///
/// Contabiliza somente após o dia [day] encerrar. Tarefas ainda agendadas
/// para [day] e não concluídas contam; conclusão após o fim do dia também
/// conta. Tarefas cuja data foi movida para o futuro antes da avaliação
/// deixam de estar em [day] e não entram na contagem.
abstract final class UnfinishedTasksTrailRules {
  static String eventKeyForDay(DateTime day) {
    return 'unfinished_tasks:day:${TaskStore.formatDateYmd(day)}';
  }

  /// Retorna evento se [day] já encerrou e havia pendência naquele dia.
  static AchievementEvent? eventForDay({
    required DateTime day,
    required Iterable<Task> tasks,
    required DateTime now,
  }) {
    if (!AchievementDayUtils.hasDayEnded(day, now)) return null;
    if (!hadUnfinishedTasksOnDay(day: day, tasks: tasks)) return null;

    return AchievementEvent(
      trail: AchievementTrailId.unfinishedTasks,
      eventKey: eventKeyForDay(day),
    );
  }

  static bool hadUnfinishedTasksOnDay({
    required DateTime day,
    required Iterable<Task> tasks,
  }) {
    final dayYmd = TaskStore.formatDateYmd(day);
    final dayOnly = AchievementDayUtils.dateOnly(day);

    for (final task in tasks) {
      if (task.deleted) continue;

      final scheduledYmd = _scheduledYmd(task, fallbackDay: dayOnly);
      if (scheduledYmd != dayYmd) continue;

      if (!task.done) return true;

      final completedAt = task.completedAt ?? task.lastUpdated;
      if (completedAt == null) return true;

      if (AchievementDayUtils.dateOnly(completedAt).isAfter(dayOnly)) {
        return true;
      }
    }

    return false;
  }

  static String _scheduledYmd(Task task, {required DateTime fallbackDay}) {
    if (task.data.isNotEmpty) return task.data;
    final created = task.createdAt;
    if (created != null) {
      return TaskStore.formatDateYmd(created);
    }
    return TaskStore.formatDateYmd(fallbackDay);
  }
}
