import '../../tasks/domain/pilha.dart';
import '../../tasks/domain/task.dart';
import 'achievement_event.dart';
import 'achievement_progress_applier.dart';
import 'achievement_progress_state.dart';
import 'rules/achievement_day_utils.dart';
import 'rules/days_completed_trail_rules.dart';
import 'rules/magic_input_trail_rules.dart';
import 'rules/pilhas_created_trail_rules.dart';
import 'rules/task_advances_trail_rules.dart';
import 'rules/tasks_created_trail_rules.dart';
import 'rules/unfinished_tasks_trail_rules.dart';

/// Orquestra a geração de eventos de conquistas a partir das ações do usuário.
abstract final class AchievementEvaluator {
  /// Eventos para uma tarefa recém-criada.
  static List<AchievementEvent> eventsForTaskCreated(Task task) {
    return [
      ?TasksCreatedTrailRules.eventForNewTask(task),
      ?MagicInputTrailRules.eventForNewTask(task),
    ];
  }

  /// Evento para mudança de data (adiantamento).
  static AchievementEvent? eventForTaskDateChange({
    required Task previous,
    required Task updated,
    required DateTime now,
  }) {
    return TaskAdvancesTrailRules.eventForDateChange(
      previous: previous,
      updated: updated,
      now: now,
    );
  }

  static AchievementEvent eventForPilhaCreated(Pilha pilha) {
    return PilhasCreatedTrailRules.eventForNewPilha(pilha);
  }

  /// Avalia dias passados pendentes (pendências e dias concluídos).
  static List<AchievementEvent> eventsForScheduledDayChecks({
    required Iterable<Task> tasks,
    required DateTime now,
    required AchievementProgressState state,
    DateTime? accountStartedOn,
  }) {
    final events = <AchievementEvent>[];
    final today = AchievementDayUtils.dateOnly(now);

    // Olha até 90 dias para trás (catch-up ao abrir o app).
    final earliest = today.subtract(const Duration(days: 90));
    final start = accountStartedOn != null &&
            AchievementDayUtils.dateOnly(accountStartedOn).isAfter(earliest)
        ? AchievementDayUtils.dateOnly(accountStartedOn)
        : earliest;

    for (final day in AchievementDayUtils.daysBetween(start: start, end: today)) {
      final unfinishedKey = UnfinishedTasksTrailRules.eventKeyForDay(day);
      if (!state.recordedEventKeys.contains(unfinishedKey)) {
        final unfinished = UnfinishedTasksTrailRules.eventForDay(
          day: day,
          tasks: tasks,
          now: now,
        );
        if (unfinished != null) events.add(unfinished);
      }

      final completedKey = DaysCompletedTrailRules.eventKeyForDay(day);
      if (!state.recordedEventKeys.contains(completedKey)) {
        final completed = DaysCompletedTrailRules.eventForDay(
          day: day,
          tasks: tasks,
          now: now,
        );
        if (completed != null) events.add(completed);
      }
    }

    // Dia de hoje: só dias concluídos após 23:50.
    final todayCompletedKey = DaysCompletedTrailRules.eventKeyForDay(today);
    if (!state.recordedEventKeys.contains(todayCompletedKey)) {
      final todayCompleted = DaysCompletedTrailRules.eventForDay(
        day: today,
        tasks: tasks,
        now: now,
      );
      if (todayCompleted != null) events.add(todayCompleted);
    }

    return events;
  }

  static AchievementProgressState applyAll(
    AchievementProgressState state,
    Iterable<AchievementEvent> events,
  ) {
    return AchievementProgressApplier.applyEvents(state, events);
  }
}
