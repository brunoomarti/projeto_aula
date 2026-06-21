import '../../../tasks/domain/task.dart';
import '../../../tasks/presentation/state/task_store.dart';
import '../achievement_event.dart';
import '../achievement_trail_id.dart';

/// Trilha **Dias Concluídos** — 1 ponto por dia com todas as tarefas feitas.
///
/// Avaliado às 23:50 do dia [day] (ou na primeira verificação após esse
/// horário). Exige ao menos uma tarefa agendada para o dia.
abstract final class DaysCompletedTrailRules {
  static const evaluationHour = 23;
  static const evaluationMinute = 50;

  static String eventKeyForDay(DateTime day) {
    return 'days_completed:day:${TaskStore.formatDateYmd(day)}';
  }

  static DateTime evaluationMoment(DateTime day) {
    return DateTime(
      day.year,
      day.month,
      day.day,
      evaluationHour,
      evaluationMinute,
    );
  }

  static bool shouldEvaluateDay({
    required DateTime day,
    required DateTime now,
  }) {
    return !now.isBefore(evaluationMoment(day));
  }

  static AchievementEvent? eventForDay({
    required DateTime day,
    required Iterable<Task> tasks,
    required DateTime now,
  }) {
    if (!shouldEvaluateDay(day: day, now: now)) return null;
    if (!isDayFullyCompleted(day: day, tasks: tasks)) return null;

    return AchievementEvent(
      trail: AchievementTrailId.daysCompleted,
      eventKey: eventKeyForDay(day),
    );
  }

  static bool isDayFullyCompleted({
    required DateTime day,
    required Iterable<Task> tasks,
  }) {
    final dayYmd = TaskStore.formatDateYmd(day);

    final dayTasks = tasks.where((task) {
      if (task.deleted) return false;
      final scheduled = task.data.isNotEmpty
          ? task.data
          : (task.createdAt != null
              ? TaskStore.formatDateYmd(task.createdAt!)
              : dayYmd);
      return scheduled == dayYmd;
    }).toList();

    if (dayTasks.isEmpty) return false;
    return dayTasks.every((task) => task.done);
  }
}
