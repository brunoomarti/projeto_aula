import 'daily_combo_calculator.dart';
import 'daily_combo_dates.dart';
import 'daily_combo_history_entry.dart';
import 'daily_combo_state.dart';

/// Aplica transições de estado (quebra, reinício e histórico).
abstract final class DailyComboEvaluator {
  static DailyComboState evaluate({
    required DailyComboState persisted,
    required DailyComboComputed computed,
    required DateTime today,
    required ({int total, int completed}) Function(DateTime date) statsForDate,
  }) {
    var next = persisted.copyWith(
      currentStreak: computed.streak,
      streakStartedOn: computed.streakStartedOn,
      lastClearedOn: computed.lastClearedOn,
      synced: false,
    );

    final streakLost = persisted.currentStreak > 0 && computed.streak == 0;

    if (streakLost && !persisted.hasPendingArchive) {
      final brokenOn = DailyComboCalculator.findFirstFailedDay(
            today: today,
            from: persisted.streakStartedOn ?? persisted.lastClearedOn,
            statsForDate: statsForDate,
          ) ??
          DailyComboDates.dateOnly(today);

      next = next.copyWith(
        pendingArchiveLength: persisted.currentStreak,
        pendingArchiveStartedOn:
            persisted.streakStartedOn ?? persisted.lastClearedOn ?? brokenOn,
        pendingArchiveBrokenOn: brokenOn,
      );
    }

    if (persisted.hasPendingArchive &&
        computed.streak > 0 &&
        computed.streakStartedOn != null) {
      final entry = DailyComboHistoryEntry(
        streakLength: persisted.pendingArchiveLength!,
        startedOn: persisted.pendingArchiveStartedOn!,
        endedOn: persisted.pendingArchiveBrokenOn!,
        restartedOn: computed.streakStartedOn!,
      );
      next = next.copyWith(
        pendingHistory: [...persisted.pendingHistory, entry],
        clearPendingArchive: true,
      );
    }

    return next;
  }
}
