import '../../../tasks/domain/task.dart';
import '../achievement_event.dart';
import '../achievement_trail_id.dart';

/// Trilha **Tarefas Criadas** — 1 ponto por tarefa criada.
abstract final class TasksCreatedTrailRules {
  static String eventKeyForTask(String taskId) => 'tasks_created:task:$taskId';

  static AchievementEvent? eventForNewTask(Task task) {
    if (task.deleted) return null;
    return AchievementEvent(
      trail: AchievementTrailId.tasksCreated,
      eventKey: eventKeyForTask(task.id),
    );
  }
}
