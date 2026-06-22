import 'package:flutter_test/flutter_test.dart';

import 'package:tasker_project/features/achievements/domain/achievement_catalog.dart';
import 'package:tasker_project/features/achievements/domain/achievement_evaluator.dart';
import 'package:tasker_project/features/achievements/domain/achievement_progress_state.dart';
import 'package:tasker_project/features/achievements/domain/achievement_trail_id.dart';

import '../support/test_tasks.dart';

void main() {
  test('AchievementCatalog desbloqueia medalha ao atingir limiar', () {
    final points = {AchievementTrailId.tasksCreated: 10};
    final unlocked = AchievementCatalog.unlockedMedalIds(points);

    expect(unlocked, contains('tasks_created_10'));
    expect(unlocked, contains('tasks_created_1'));
  });

  test('activeTrails respeita flags', () {
    expect(AchievementCatalog.activeTrails, isNotEmpty);
    expect(AchievementCatalog.medalsById['tasks_created_1']?.title, 'Primeira Tarefa');
  });

  test('eventsForScheduledDayChecks detecta dia concluído', () {
    final day = DateTime(2026, 6, 20);
    final ymd = '2026-06-20';
    final tasks = [
      testTask(
        id: '1',
        title: 'A',
        data: ymd,
        done: true,
        createdAt: day,
      ),
    ];
    const state = AchievementProgressState();

    final events = AchievementEvaluator.eventsForScheduledDayChecks(
      tasks: tasks,
      now: DateTime(2026, 6, 21, 10),
      state: state,
      accountStartedOn: DateTime(2026, 6, 1),
    );

    expect(events, isNotEmpty);
  });

  test('applyAll acumula pontos', () {
    const state = AchievementProgressState();
    final task = testTask(id: '1', title: 'Nova');
    final events = AchievementEvaluator.eventsForTaskCreated(task);

    final next = AchievementEvaluator.applyAll(state, events);

    expect(next.pointsFor(AchievementTrailId.tasksCreated), greaterThan(0));
  });
}
