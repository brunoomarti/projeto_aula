import 'achievement_trail_id.dart';

/// Liga/desliga trilhas sem remover código — reative alterando o flag.
abstract final class AchievementTrailFlags {
  /// Trilha **Tarefas não concluídas** — desativada temporariamente.
  static const unfinishedTasksEnabled = false;

  static bool isEnabled(AchievementTrailId id) {
    return switch (id) {
      AchievementTrailId.unfinishedTasks => unfinishedTasksEnabled,
      _ => true,
    };
  }
}
