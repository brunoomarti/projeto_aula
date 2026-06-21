import '../../../tasks/domain/task.dart';
import '../achievement_event.dart';
import '../achievement_progress_state.dart';
import '../achievement_trail_id.dart';

/// Trilha **Conquistas lendárias** — feitos raros, um evento por medalha.
abstract final class CuriositiesTrailRules {
  static const flagDayTitle = 'Ordem e progresso';
  static const voiceStreakTarget = 10;
  static const voiceStreak10EventKey = 'curiosities:voice_streak_10';
  static const stampCollectorTarget = 100;
  static const stampCollector100EventKey = 'curiosities:stamp_collector_100';
  static const apollo13Target = 13;
  static const apollo13EventKey = 'curiosities:apollo_13';

  static String eventKeyForFlagDayTask(String taskId) =>
      'curiosities:flag_day:$taskId';

  static List<AchievementEvent> eventsForNewTask(Task task) {
    final event = _eventForFlagDayTask(task);
    return event != null ? [event] : const [];
  }

  /// Avalia sequência de voz após qualquer criação (inclui catch-up no histórico).
  static AchievementEvent? eventForVoiceStreak({
    required Iterable<Task> tasks,
    required AchievementProgressState state,
  }) {
    if (state.recordedEventKeys.contains(voiceStreak10EventKey)) return null;

    final streak = currentVoiceCreationStreak(tasks);
    if (streak < voiceStreakTarget) return null;

    return const AchievementEvent(
      trail: AchievementTrailId.curiosities,
      eventKey: voiceStreak10EventKey,
    );
  }

  /// Concluir uma tarefa que já foi adiantada 13 vezes.
  static AchievementEvent? eventForApollo13({
    required Iterable<Task> tasks,
    required AchievementProgressState state,
  }) {
    if (state.recordedEventKeys.contains(apollo13EventKey)) return null;

    for (final task in tasks) {
      if (task.deleted || !task.done) continue;
      if (advanceCountForTask(task.id, state.recordedEventKeys) >=
          apollo13Target) {
        return const AchievementEvent(
          trail: AchievementTrailId.curiosities,
          eventKey: apollo13EventKey,
        );
      }
    }
    return null;
  }

  static int advanceCountForTask(
    String taskId,
    Set<String> recordedEventKeys,
  ) {
    final prefix = 'task_advance:$taskId:';
    return recordedEventKeys.where((key) => key.startsWith(prefix)).length;
  }

  /// 100 conclusões seguidas sem nenhuma tarefa adiada no meio.
  static AchievementEvent? eventForStampCollector({
    required Iterable<Task> tasks,
    required AchievementProgressState state,
  }) {
    if (state.recordedEventKeys.contains(stampCollector100EventKey)) return null;

    final streak = currentCleanCompletionStreak(tasks);
    if (streak < stampCollectorTarget) return null;

    return const AchievementEvent(
      trail: AchievementTrailId.curiosities,
      eventKey: stampCollector100EventKey,
    );
  }

  /// Conclusões válidas em sequência — zera ao adiar qualquer tarefa.
  static int currentCleanCompletionStreak(Iterable<Task> tasks) {
    final events = <_TimelineEvent>[];

    for (final task in tasks) {
      if (task.deleted) continue;

      if (task.postponed) {
        final at = task.lastUpdated ?? task.createdAt;
        if (at != null) {
          events.add(_TimelineEvent(at: at, kind: _TimelineEventKind.postponed));
        }
      }

      if (task.done) {
        final at = task.completedAt ?? task.lastUpdated ?? task.createdAt;
        if (at != null) {
          events.add(
            _TimelineEvent(
              at: at,
              kind: _TimelineEventKind.completed,
              countsTowardStreak: !task.postponed,
            ),
          );
        }
      }
    }

    if (events.isEmpty) return 0;

    events.sort((a, b) => a.at.compareTo(b.at));

    var streak = 0;
    for (final event in events) {
      switch (event.kind) {
        case _TimelineEventKind.postponed:
          streak = 0;
        case _TimelineEventKind.completed:
          if (event.countsTowardStreak) {
            streak++;
          } else {
            streak = 0;
          }
      }
    }
    return streak;
  }

  /// Tarefas ordenadas por criação — conta voz seguida até a primeira quebra.
  static int currentVoiceCreationStreak(Iterable<Task> tasks) {
    final sorted = tasks
        .where((t) => !t.deleted && t.createdAt != null)
        .toList()
      ..sort((a, b) => a.createdAt!.compareTo(b.createdAt!));

    var streak = 0;
    for (final task in sorted.reversed) {
      if (task.createdViaMagic && task.createdViaVoice) {
        streak++;
      } else {
        break;
      }
    }
    return streak;
  }

  static AchievementEvent? _eventForFlagDayTask(Task task) {
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

enum _TimelineEventKind { postponed, completed }

class _TimelineEvent {
  const _TimelineEvent({
    required this.at,
    required this.kind,
    this.countsTowardStreak = false,
  });

  final DateTime at;
  final _TimelineEventKind kind;
  final bool countsTowardStreak;
}
