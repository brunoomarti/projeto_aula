import '../../../tasks/presentation/state/task_store.dart';

/// Utilitários de data compartilhados pelas regras de conquistas.
abstract final class AchievementDayUtils {
  static DateTime dateOnly(DateTime value) {
    return TaskStore.dateOnly(value);
  }

  static DateTime parseYmd(String ymd) {
    final parts = ymd.split('-');
    return DateTime(
      int.parse(parts[0]),
      int.parse(parts[1]),
      int.parse(parts[2]),
    );
  }

  /// `true` quando [now] já está no dia civil seguinte a [day].
  static bool hasDayEnded(DateTime day, DateTime now) {
    final dayOnly = dateOnly(day);
    final nowOnly = dateOnly(now);
    return nowOnly.isAfter(dayOnly);
  }

  /// Dias civis entre [start] e [end] (exclusivo de [end]), em ordem crescente.
  static Iterable<DateTime> daysBetween({
    required DateTime start,
    required DateTime end,
  }) sync* {
    var cursor = dateOnly(start);
    final limit = dateOnly(end);
    while (cursor.isBefore(limit)) {
      yield cursor;
      cursor = cursor.add(const Duration(days: 1));
    }
  }
}
