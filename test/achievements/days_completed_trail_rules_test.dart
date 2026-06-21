import 'package:flutter_test/flutter_test.dart';

import 'package:tasker_project/features/achievements/domain/rules/days_completed_trail_rules.dart';
import 'package:tasker_project/features/tasks/domain/task.dart';
import 'package:tasker_project/features/tasks/presentation/state/task_store.dart';

void main() {
  final day = DateTime(2026, 6, 18);
  final dayYmd = TaskStore.formatDateYmd(day);

  Task t({
    required String id,
    bool done = false,
    String? data,
  }) {
    return Task(
      id: id,
      title: id,
      data: data ?? dayYmd,
      hora: '10:00',
      createdAt: day,
      lastUpdated: day,
      done: done,
      completedAt: done ? day.add(const Duration(hours: 12)) : null,
    );
  }

  group('DaysCompletedTrailRules', () {
    test('não avalia antes das 23:50', () {
      final now = DateTime(2026, 6, 18, 20, 0);
      expect(
        DaysCompletedTrailRules.shouldEvaluateDay(day: day, now: now),
        isFalse,
      );
      expect(
        DaysCompletedTrailRules.eventForDay(
          day: day,
          tasks: [t(id: '1', done: true)],
          now: now,
        ),
        isNull,
      );
    });

    test('conta dia com todas as tarefas concluídas após 23:50', () {
      final now = DateTime(2026, 6, 18, 23, 55);
      final event = DaysCompletedTrailRules.eventForDay(
        day: day,
        tasks: [
          t(id: '1', done: true),
          t(id: '2', done: true),
        ],
        now: now,
      );
      expect(event, isNotNull);
    });

    test('não conta se falta concluir alguma tarefa', () {
      final now = DateTime(2026, 6, 18, 23, 55);
      final event = DaysCompletedTrailRules.eventForDay(
        day: day,
        tasks: [
          t(id: '1', done: true),
          t(id: '2', done: false),
        ],
        now: now,
      );
      expect(event, isNull);
    });

    test('não conta dia sem tarefas', () {
      final now = DateTime(2026, 6, 18, 23, 55);
      expect(
        DaysCompletedTrailRules.isDayFullyCompleted(day: day, tasks: const []),
        isFalse,
      );
      expect(
        DaysCompletedTrailRules.eventForDay(day: day, tasks: const [], now: now),
        isNull,
      );
    });

    test('avalia no dia seguinte se perdeu 23:50', () {
      final now = DateTime(2026, 6, 19, 8, 0);
      final event = DaysCompletedTrailRules.eventForDay(
        day: day,
        tasks: [t(id: '1', done: true)],
        now: now,
      );
      expect(event, isNotNull);
    });
  });
}
