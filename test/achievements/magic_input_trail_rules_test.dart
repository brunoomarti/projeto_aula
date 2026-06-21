import 'package:flutter_test/flutter_test.dart';

import 'package:tasker_project/features/achievements/domain/achievement_trail_id.dart';
import 'package:tasker_project/features/achievements/domain/rules/magic_input_trail_rules.dart';
import 'package:tasker_project/features/tasks/domain/task.dart';
import 'package:tasker_project/features/tasks/presentation/state/task_store.dart';

void main() {
  group('MagicInputTrailRules', () {
    test('gera evento para tarefa criada via magic input', () {
      final task = Task(
        id: 'm1',
        title: 'Comprar leite',
        data: TaskStore.formatDateYmd(DateTime(2026, 6, 18)),
        hora: '10:00',
        createdViaMagic: true,
      );
      final event = MagicInputTrailRules.eventForNewTask(task);
      expect(event, isNotNull);
      expect(event!.trail, AchievementTrailId.magicInput);
    });

    test('ignora tarefa criada manualmente', () {
      final task = Task(
        id: 'm2',
        title: 'Manual',
        data: '2026-06-18',
        hora: '10:00',
      );
      expect(MagicInputTrailRules.eventForNewTask(task), isNull);
    });
  });
}
