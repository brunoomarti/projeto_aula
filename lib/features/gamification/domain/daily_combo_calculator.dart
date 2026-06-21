import 'daily_combo_dates.dart';

/// Status de um dia para o combo diário.
enum DailyComboDayStatus {
  /// Sem tarefas — não quebra nem incrementa a sequência.
  empty,

  /// Todas as tarefas concluídas.
  cleared,

  /// Dia passado com tarefas pendentes — quebra a sequência.
  failed,

  /// Hoje com tarefas ainda abertas — não conta nem quebra.
  inProgress,
}

/// Resultado do cálculo de sequência a partir das tarefas.
class DailyComboComputed {
  const DailyComboComputed({
    required this.streak,
    this.streakStartedOn,
    this.lastClearedOn,
  });

  final int streak;
  final DateTime? streakStartedOn;
  final DateTime? lastClearedOn;
}

/// Lógica pura de cálculo do combo diário.
abstract final class DailyComboCalculator {
  static DailyComboDayStatus dayStatus({
    required int total,
    required int completed,
    required bool isToday,
  }) {
    if (total <= 0) return DailyComboDayStatus.empty;
    if (completed >= total) return DailyComboDayStatus.cleared;
    if (isToday) return DailyComboDayStatus.inProgress;
    return DailyComboDayStatus.failed;
  }

  static DailyComboComputed compute({
    required DateTime today,
    required ({int total, int completed}) Function(DateTime date) statsForDate,
    int maxDays = 400,
  }) {
    final anchor = DailyComboDates.dateOnly(today);
    var cursor = anchor;
    var streak = 0;
    DateTime? lastCleared;
    DateTime? streakStart;

    for (var i = 0; i < maxDays; i++) {
      final stats = statsForDate(cursor);
      final isToday = _sameDay(cursor, anchor);
      final status = dayStatus(
        total: stats.total,
        completed: stats.completed,
        isToday: isToday,
      );

      switch (status) {
        case DailyComboDayStatus.cleared:
          streak++;
          lastCleared ??= cursor;
          streakStart = cursor;
          cursor = cursor.subtract(const Duration(days: 1));
        case DailyComboDayStatus.empty:
          cursor = cursor.subtract(const Duration(days: 1));
        case DailyComboDayStatus.inProgress:
          cursor = cursor.subtract(const Duration(days: 1));
        case DailyComboDayStatus.failed:
          return DailyComboComputed(
            streak: streak,
            streakStartedOn: streak > 0 ? streakStart : null,
            lastClearedOn: lastCleared,
          );
      }
    }

    return DailyComboComputed(
      streak: streak,
      streakStartedOn: streak > 0 ? streakStart : null,
      lastClearedOn: lastCleared,
    );
  }

  /// Primeiro dia com falha entre [from] e [today] (inclusive).
  static DateTime? findFirstFailedDay({
    required DateTime today,
    required DateTime? from,
    required ({int total, int completed}) Function(DateTime date) statsForDate,
  }) {
    if (from == null) return null;

    final end = DailyComboDates.dateOnly(today);
    var cursor = DailyComboDates.dateOnly(from);
    while (!cursor.isAfter(end)) {
      final stats = statsForDate(cursor);
      final status = dayStatus(
        total: stats.total,
        completed: stats.completed,
        isToday: _sameDay(cursor, end),
      );
      if (status == DailyComboDayStatus.failed) return cursor;
      cursor = cursor.add(const Duration(days: 1));
    }
    return end;
  }

  static bool _sameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}
