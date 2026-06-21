import '../../../tasks/domain/task.dart';
import '../achievement_event.dart';
import '../achievement_trail_id.dart';

/// Trilha **Magic Input** — 1 ponto por tarefa criada via entrada inteligente.
abstract final class MagicInputTrailRules {
  static String eventKeyForTask(String taskId) => 'magic_input:task:$taskId';

  static AchievementEvent? eventForNewTask(Task task) {
    if (task.deleted || !task.createdViaMagic) return null;
    return AchievementEvent(
      trail: AchievementTrailId.magicInput,
      eventKey: eventKeyForTask(task.id),
    );
  }
}
