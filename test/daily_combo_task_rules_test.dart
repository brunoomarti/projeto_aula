import 'package:flutter_test/flutter_test.dart';

import 'package:tasker_project/features/gamification/domain/daily_combo_task_rules.dart';
import 'package:tasker_project/features/tasks/domain/task.dart';
import 'package:tasker_project/features/tasks/domain/task_postponement.dart';
import 'package:tasker_project/features/tasks/presentation/state/task_store.dart';

void main() {
  final day = DateTime(2026, 6, 18);
  final dayYmd = TaskStore.formatDateYmd(day);

  Task task({
    required String id,
    DateTime? createdAt,
    DateTime? completedAt,
    DateTime? lastUpdated,
    String? data,
    bool done = false,
    bool postponed = false,
    bool scheduleAdjusted = false,
  }) {
    final created = createdAt ?? day;
    return Task(
      id: id,
      title: 'Tarefa $id',
      data: data ?? dayYmd,
      hora: '10:00',
      done: done,
      createdAt: created,
      lastUpdated: lastUpdated ?? created,
      completedAt: completedAt,
      postponed: postponed,
      scheduleAdjusted: scheduleAdjusted,
    );
  }

  group('isEligibleForComboDay', () {
    test('aceita tarefa criada e agendada no mesmo dia', () {
      final t = task(id: '1');
      expect(DailyComboTaskRules.isEligibleForComboDay(t, day), isTrue);
    });

    test('rejeita tarefa criada em outro dia', () {
      final t = task(
        id: '1',
        createdAt: day.subtract(const Duration(days: 1)),
      );
      expect(DailyComboTaskRules.isEligibleForComboDay(t, day), isFalse);
    });

    test('rejeita tarefa agendada para outro dia', () {
      final tomorrow = TaskStore.formatDateYmd(day.add(const Duration(days: 1)));
      final t = task(id: '1', data: tomorrow);
      expect(DailyComboTaskRules.isEligibleForComboDay(t, day), isFalse);
    });

    test('rejeita tarefa adiada (postponed)', () {
      final t = task(id: '1', postponed: true);
      expect(DailyComboTaskRules.isEligibleForComboDay(t, day), isFalse);
    });

    test('rejeita tarefa com data alterada (scheduleAdjusted)', () {
      final t = task(id: '1', scheduleAdjusted: true);
      expect(DailyComboTaskRules.isEligibleForComboDay(t, day), isFalse);
    });
  });

  group('countsAsCompletedForComboDay', () {
    test('conta quando concluída no mesmo dia', () {
      final t = task(
        id: '1',
        done: true,
        completedAt: day.add(const Duration(hours: 12)),
      );
      expect(
        DailyComboTaskRules.countsAsCompletedForComboDay(t, day),
        isTrue,
      );
    });

    test('não conta conclusão feita em outro dia', () {
      final t = task(
        id: '1',
        done: true,
        completedAt: day.add(const Duration(days: 1)),
      );
      expect(
        DailyComboTaskRules.countsAsCompletedForComboDay(t, day),
        isFalse,
      );
    });
  });

  group('TaskPostponementRules', () {
    test('marca scheduleAdjusted em qualquer troca de data', () {
      final created = day.add(const Duration(minutes: 30));
      final previous = task(id: '1', createdAt: created);
      final tomorrow = TaskStore.formatDateYmd(day.add(const Duration(days: 1)));
      final updated = previous.copyWith(data: tomorrow);

      final result = TaskPostponementRules.applyDateChange(
        previous: previous,
        updated: updated,
        now: created.add(const Duration(minutes: 45)),
      );

      expect(result.scheduleAdjusted, isTrue);
      expect(result.postponed, isFalse);
    });

    test('marca postponed após 1 h da criação', () {
      final created = day;
      final previous = task(id: '1', createdAt: created);
      final tomorrow = TaskStore.formatDateYmd(day.add(const Duration(days: 1)));
      final updated = previous.copyWith(data: tomorrow);

      final result = TaskPostponementRules.applyDateChange(
        previous: previous,
        updated: updated,
        now: created.add(const Duration(hours: 2)),
      );

      expect(result.scheduleAdjusted, isTrue);
      expect(result.postponed, isTrue);
    });
  });

  group('statsForDay', () {
    test('ignora tarefa burlada (< 1 h) ao trocar de dia', () {
      final created = day.add(const Duration(minutes: 10));
      final previous = task(id: '1', createdAt: created);
      final tomorrow = TaskStore.formatDateYmd(day.add(const Duration(days: 1)));
      final cheated = TaskPostponementRules.applyDateChange(
        previous: previous,
        updated: previous.copyWith(
          data: tomorrow,
          done: true,
          completedAt: day.add(const Duration(hours: 1)),
        ),
        now: day.add(const Duration(minutes: 20)),
      );

      final stats = DailyComboTaskRules.statsForDay([cheated], day, now: day);
      expect(stats.total, 0);
      expect(stats.completed, 0);
    });
  });
}
