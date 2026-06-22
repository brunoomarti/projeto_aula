import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:tasker_project/features/tasks/domain/task_postponement.dart';
import 'package:tasker_project/features/tasks/presentation/state/task_store.dart';

import '../support/test_task_store.dart';
import '../support/test_tasks.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  test('updateTask para outro dia marca scheduleAdjusted', () async {
    final store = await readyTaskStoreForTest();
    final created = DateTime(2026, 6, 21, 8);
    await store.addTask(
      testTask(
        id: '1',
        title: 'Mover',
        data: '2026-06-21',
        createdAt: created,
      ),
    );

    final task = store.taskById('1')!;
    await store.updateTask(task.copyWith(data: '2026-06-22'));

    final updated = store.taskById('1')!;
    expect(updated.data, '2026-06-22');
    expect(updated.scheduleAdjusted, isTrue);
  });

  group('TaskPostponementRules', () {
    test('marca postponed após período de tolerância', () {
      final previous = testTask(
        id: '1',
        title: 'A',
        data: '2026-06-21',
        createdAt: DateTime(2026, 6, 21, 8),
      );
      final updated = previous.copyWith(data: '2026-06-22');
      final now = DateTime(2026, 6, 21, 10);

      final result = TaskPostponementRules.applyDateChange(
        previous: previous,
        updated: updated,
        now: now,
      );

      expect(result.postponed, isTrue);
      expect(result.scheduleAdjusted, isTrue);
    });

    test('dentro de 1h só marca scheduleAdjusted', () {
      final created = DateTime(2026, 6, 21, 9, 30);
      final previous = testTask(
        id: '1',
        title: 'A',
        data: '2026-06-21',
        createdAt: created,
      );
      final updated = previous.copyWith(data: '2026-06-22');
      final now = DateTime(2026, 6, 21, 10);

      final result = TaskPostponementRules.applyDateChange(
        previous: previous,
        updated: updated,
        now: now,
      );

      expect(result.scheduleAdjusted, isTrue);
      expect(result.postponed, isFalse);
    });

    test('sem mudança de data retorna inalterado', () {
      final task = testTask(id: '1', title: 'A', data: '2026-06-21');

      final result = TaskPostponementRules.applyDateChange(
        previous: task,
        updated: task,
        now: DateTime(2026, 6, 21, 12),
      );

      expect(result.scheduleAdjusted, isFalse);
      expect(result.postponed, isFalse);
    });
  });
}
