import '../../../tasks/domain/task.dart';
import '../../../tasks/domain/task_postponement.dart';
import '../../../tasks/presentation/state/task_store.dart';
import '../achievement_event.dart';
import '../achievement_trail_id.dart';
import 'achievement_day_utils.dart';

/// Trilha **Adiantamentos de Tarefas** — 1 ponto por adiantamento qualificado.
///
/// A data deve avançar (nunca retroceder). A edição só conta após
/// [TaskPostponementRules.gracePeriod] da criação.
abstract final class TaskAdvancesTrailRules {
  static String eventKey({
    required String taskId,
    required String fromYmd,
    required String toYmd,
  }) =>
      'task_advance:$taskId:$fromYmd->$toYmd';

  static AchievementEvent? eventForDateChange({
    required Task previous,
    required Task updated,
    required DateTime now,
  }) {
    if (previous.deleted || updated.deleted) return null;
    if (previous.data == updated.data) return null;

    final fromYmd = _scheduledYmd(previous, now: now);
    final toYmd = _scheduledYmd(updated, now: now);
    if (fromYmd == toYmd) return null;

    final fromDay = AchievementDayUtils.parseYmd(fromYmd);
    final toDay = AchievementDayUtils.parseYmd(toYmd);
    if (!toDay.isAfter(fromDay)) return null;

    final created = previous.createdAt ?? updated.createdAt;
    if (created == null) return null;
    if (now.difference(created) <= TaskPostponementRules.gracePeriod) {
      return null;
    }

    return AchievementEvent(
      trail: AchievementTrailId.taskAdvances,
      eventKey: eventKey(
        taskId: updated.id,
        fromYmd: fromYmd,
        toYmd: toYmd,
      ),
    );
  }

  static String _scheduledYmd(Task task, {required DateTime now}) {
    if (task.data.isNotEmpty) return task.data;
    final created = task.createdAt;
    if (created != null) return TaskStore.formatDateYmd(created);
    return TaskStore.formatDateYmd(now);
  }
}
