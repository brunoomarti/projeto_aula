import '../../../tasks/domain/task.dart';
import '../achievement_event.dart';
import '../achievement_trail_id.dart';

/// Trilha **Conquistas lendárias** — feitos raros, um evento por medalha.
abstract final class CuriositiesTrailRules {
  static const flagDayTitle = 'Ordem e progresso';

  static String eventKeyForFlagDayTask(String taskId) =>
      'curiosities:flag_day:$taskId';

  static AchievementEvent? eventForNewTask(Task task) {
    if (task.deleted) return null;

    final created = task.createdAt ?? task.lastUpdated;
    if (created == null || !_isFlagDay(created)) return null;
    if (!_matchesFlagDayTitle(task.title)) return null;

    return AchievementEvent(
      trail: AchievementTrailId.curiosities,
      eventKey: eventKeyForFlagDayTask(task.id),
    );
  }

  /// 19 de novembro — Dia da Bandeira no Brasil.
  static bool _isFlagDay(DateTime date) => date.month == 11 && date.day == 19;

  static bool _matchesFlagDayTitle(String title) {
    return _normalizeTitle(title) == _normalizeTitle(flagDayTitle);
  }

  static String _normalizeTitle(String value) {
    return value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  }
}
