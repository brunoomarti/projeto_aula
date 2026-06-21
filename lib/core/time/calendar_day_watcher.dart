import 'dart:async';

/// Dispara quando o dia civil muda (meia-noite local ou retorno ao app).
class CalendarDayWatcher {
  CalendarDayWatcher({required this.onDayChanged});

  final void Function(DateTime previousDay, DateTime newDay) onDayChanged;

  Timer? _midnightTimer;
  late DateTime _trackedDay;

  void start() {
    _trackedDay = _dateOnly(DateTime.now());
    _scheduleMidnightCheck();
  }

  void stop() {
    _midnightTimer?.cancel();
    _midnightTimer = null;
  }

  /// Verifica imediatamente se o dia mudou (ex.: app voltou ao primeiro plano).
  void checkNow() {
    final today = _dateOnly(DateTime.now());
    if (_isSameDay(today, _trackedDay)) return;

    final previous = _trackedDay;
    _trackedDay = today;
    onDayChanged(previous, today);
    _scheduleMidnightCheck();
  }

  void _scheduleMidnightCheck() {
    _midnightTimer?.cancel();
    final now = DateTime.now();
    final nextMidnight = DateTime(now.year, now.month, now.day + 1);
    final delay = nextMidnight.difference(now) + const Duration(seconds: 1);
    _midnightTimer = Timer(delay, () {
      checkNow();
    });
  }

  static DateTime _dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  static bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
