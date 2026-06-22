import 'package:flutter_test/flutter_test.dart';

import 'package:tasker_project/features/achievements/domain/achievement_evaluator.dart';
import 'package:tasker_project/features/achievements/domain/achievement_progress_applier.dart';
import 'package:tasker_project/features/achievements/domain/achievement_progress_state.dart';
import 'package:tasker_project/features/achievements/domain/achievement_trail_id.dart';
import 'package:tasker_project/features/tasks/domain/pilha.dart';

import '../support/test_tasks.dart';

void main() {
  test('eventsForTaskCreated inclui trilhas de criação', () {
    final task = testTask(id: 't1', title: 'Nova');

    final events = AchievementEvaluator.eventsForTaskCreated(task);

    expect(events, isNotEmpty);
    expect(events.any((e) => e.trail == AchievementTrailId.tasksCreated), isTrue);
  });

  test('eventForPilhaCreated gera evento de pilha', () {
    final pilha = Pilha(id: 'p1', name: 'Rotina', createdAt: DateTime(2026, 6, 21));
    final event = AchievementEvaluator.eventForPilhaCreated(pilha);

    expect(event.trail, AchievementTrailId.pilhasCreated);
    expect(event.eventKey, contains('p1'));
  });

  test('AchievementProgressApplier não duplica eventos', () {
    const state = AchievementProgressState();
    final task = testTask(id: 't2', title: 'X');
    final events = AchievementEvaluator.eventsForTaskCreated(task);

    final once = AchievementProgressApplier.applyEvents(state, events);
    final twice = AchievementProgressApplier.applyEvents(once, events);

    expect(twice.recordedEventKeys.length, once.recordedEventKeys.length);
  });

  test('AchievementProgressState.merge usa máximo por trilha', () {
    const local = AchievementProgressState(
      pointsByTrail: {AchievementTrailId.tasksCreated: 3},
      recordedEventKeys: {'a'},
    );
    const remote = AchievementProgressState(
      pointsByTrail: {AchievementTrailId.tasksCreated: 5},
      recordedEventKeys: {'b'},
    );

    final merged = AchievementProgressState.merge(local, remote);

    expect(merged.pointsFor(AchievementTrailId.tasksCreated), 5);
    expect(merged.recordedEventKeys, containsAll(['a', 'b']));
  });
}
