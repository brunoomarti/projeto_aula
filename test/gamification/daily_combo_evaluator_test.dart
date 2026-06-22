import 'package:flutter_test/flutter_test.dart';

import 'package:tasker_project/features/gamification/domain/daily_combo_calculator.dart';
import 'package:tasker_project/features/gamification/domain/daily_combo_evaluator.dart';
import 'package:tasker_project/features/gamification/domain/daily_combo_state.dart';

void main() {
  final today = DateTime(2026, 6, 21);

  ({int total, int completed}) statsForDate(DateTime date) {
    final map = <DateTime, ({int total, int completed})>{
      DateTime(2026, 6, 21): (total: 1, completed: 1),
      DateTime(2026, 6, 20): (total: 1, completed: 0),
      DateTime(2026, 6, 19): (total: 1, completed: 1),
    };
    return map[DateTime(date.year, date.month, date.day)] ??
        (total: 0, completed: 0);
  }

  test('atualiza streak sem perda', () {
    const persisted = DailyComboState(currentStreak: 1);
    const computed = DailyComboComputed(
      streak: 2,
      streakStartedOn: null,
      lastClearedOn: null,
    );

    final next = DailyComboEvaluator.evaluate(
      persisted: persisted,
      computed: computed,
      today: today,
      statsForDate: statsForDate,
    );

    expect(next.currentStreak, 2);
    expect(next.synced, isFalse);
  });

  test('arquiva sequência perdida', () {
    final persisted = DailyComboState(
      currentStreak: 3,
      streakStartedOn: DateTime(2026, 6, 17),
      lastClearedOn: DateTime(2026, 6, 19),
    );
    const computed = DailyComboComputed(streak: 0);

    final next = DailyComboEvaluator.evaluate(
      persisted: persisted,
      computed: computed,
      today: today,
      statsForDate: statsForDate,
    );

    expect(next.pendingArchiveLength, 3);
    expect(next.pendingArchiveBrokenOn, DateTime(2026, 6, 20));
  });

  test('grava histórico ao reiniciar streak', () {
    final persisted = DailyComboState(
      currentStreak: 0,
      pendingArchiveLength: 2,
      pendingArchiveStartedOn: DateTime(2026, 6, 10),
      pendingArchiveBrokenOn: DateTime(2026, 6, 12),
    );
    final computed = DailyComboComputed(
      streak: 1,
      streakStartedOn: DateTime(2026, 6, 21),
      lastClearedOn: DateTime(2026, 6, 21),
    );

    final next = DailyComboEvaluator.evaluate(
      persisted: persisted,
      computed: computed,
      today: today,
      statsForDate: statsForDate,
    );

    expect(next.hasPendingArchive, isFalse);
    expect(next.pendingHistory, hasLength(1));
    expect(next.pendingHistory.first.streakLength, 2);
    expect(next.pendingHistory.first.restartedOn, DateTime(2026, 6, 21));
  });
}
