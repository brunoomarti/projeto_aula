import 'package:flutter_test/flutter_test.dart';

import 'package:tasker_project/features/achievements/domain/achievement_catalog.dart';
import 'package:tasker_project/features/achievements/domain/achievement_progress_applier.dart';
import 'package:tasker_project/features/achievements/domain/achievement_progress_state.dart';
import 'package:tasker_project/features/achievements/domain/achievement_trail_id.dart';
import 'package:tasker_project/features/achievements/domain/rules/tasks_created_trail_rules.dart';
import 'package:tasker_project/features/tasks/domain/task.dart';
import 'package:tasker_project/features/tasks/presentation/state/task_store.dart';

void main() {
  final day = DateTime(2026, 6, 18);
  final dayYmd = TaskStore.formatDateYmd(day);

  Task task({required String id, bool deleted = false}) {
    return Task(
      id: id,
      title: 'Tarefa $id',
      data: dayYmd,
      hora: '10:00',
      createdAt: day,
      lastUpdated: day,
      deleted: deleted,
    );
  }

  group('TasksCreatedTrailRules', () {
    test('gera evento para tarefa nova', () {
      final event = TasksCreatedTrailRules.eventForNewTask(task(id: '1'));
      expect(event, isNotNull);
      expect(event!.trail, AchievementTrailId.tasksCreated);
      expect(event.eventKey, 'tasks_created:task:1');
    });

    test('ignora tarefa excluída', () {
      expect(
        TasksCreatedTrailRules.eventForNewTask(task(id: '1', deleted: true)),
        isNull,
      );
    });
  });

  group('pontos irreversíveis', () {
    test('aplicar evento não remove pontos ao excluir tarefa depois', () {
      final event = TasksCreatedTrailRules.eventForNewTask(task(id: '1'))!;
      final after = AchievementProgressApplier.applyEvents(
        const AchievementProgressState(),
        [event],
      );
      expect(after.pointsFor(AchievementTrailId.tasksCreated), 1);

      // Simula nova avaliação sem novo evento — pontos permanecem.
      final again = AchievementProgressApplier.applyEvents(after, const []);
      expect(again.pointsFor(AchievementTrailId.tasksCreated), 1);
    });

    test('desbloqueia medalhas pelo catálogo', () {
      final events = List.generate(
        10,
        (i) => TasksCreatedTrailRules.eventForNewTask(task(id: '$i'))!,
      );
      final state = AchievementProgressApplier.applyEvents(
        const AchievementProgressState(),
        events,
      );
      expect(state.isMedalUnlocked('tasks_created_10'), isTrue);
      expect(state.isMedalUnlocked('tasks_created_25'), isFalse);
      expect(
        AchievementCatalog.unlockedMedalIds(
          state.pointsByTrail,
          recordedEventKeys: state.recordedEventKeys,
        ),
        contains('tasks_created_10'),
      );
    });
  });
}
