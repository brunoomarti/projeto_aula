import '../../tasks/domain/task.dart';
import '../../tasks/presentation/state/task_store.dart';
import 'daily_combo_dates.dart';

/// Período de tolerância antes de marcar [Task.postponed] ao trocar a data.
const Duration kDailyComboPostponeGracePeriod = Duration(hours: 1);

/// Regras de elegibilidade de tarefas para o combo diário (foguinho).
abstract final class DailyComboTaskRules {
  /// Tarefa pode entrar no total do combo do dia [day]?
  ///
  /// - Criada no mesmo dia civil de [day].
  /// - Agendada para [day] (não vale concluir tarefa de outro dia).
  /// - Sem adiamento ([Task.postponed]) nem troca de data ([Task.scheduleAdjusted]).
  static bool isEligibleForComboDay(
    Task task,
    DateTime day, {
    DateTime? now,
  }) {
    if (task.deleted || task.postponed || task.scheduleAdjusted) return false;

    final created = task.createdAt;
    if (created == null) return false;

    final dayYmd = TaskStore.formatDateYmd(day);
    final scheduledYmd = task.data.isEmpty
        ? TaskStore.formatDateYmd(now ?? DateTime.now())
        : task.data;
    if (scheduledYmd != dayYmd) return false;

    final createdDay = DailyComboDates.dateOnly(created);
    final targetDay = DailyComboDates.dateOnly(day);
    return createdDay == targetDay;
  }

  /// Conclusão válida para o combo: criada e finalizada no mesmo dia [day].
  static bool countsAsCompletedForComboDay(
    Task task,
    DateTime day, {
    DateTime? now,
  }) {
    if (!isEligibleForComboDay(task, day, now: now)) return false;
    if (!task.done) return false;

    final completedAt = task.completedAt ?? task.lastUpdated;
    if (completedAt == null) return false;

    final completedDay = DailyComboDates.dateOnly(completedAt);
    final targetDay = DailyComboDates.dateOnly(day);
    return completedDay == targetDay;
  }

  static ({int total, int completed}) statsForDay(
    Iterable<Task> dayTasks,
    DateTime day, {
    DateTime? now,
  }) {
    var total = 0;
    var completed = 0;
    for (final task in dayTasks) {
      if (!isEligibleForComboDay(task, day, now: now)) continue;
      total++;
      if (countsAsCompletedForComboDay(task, day, now: now)) {
        completed++;
      }
    }
    return (total: total, completed: completed);
  }
}
