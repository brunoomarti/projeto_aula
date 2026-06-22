import 'package:flutter_test/flutter_test.dart';

import 'package:tasker_project/features/achievements/domain/achievement_progress_state.dart';
import 'package:tasker_project/features/achievements/domain/achievement_trail_id.dart';

void main() {
  test('toLocalJson e fromLocalJson preservam estado', () {
    final original = AchievementProgressState(
      pointsByTrail: {
        AchievementTrailId.tasksCreated: 7,
        AchievementTrailId.pilhasCreated: 2,
      },
      recordedEventKeys: {'event:a', 'event:b'},
      unlockedMedalIds: {'tasks_created_1'},
      synced: false,
    );

    final restored = AchievementProgressState.fromLocalJson(original.toLocalJson());

    expect(restored.pointsFor(AchievementTrailId.tasksCreated), 7);
    expect(restored.pointsFor(AchievementTrailId.pilhasCreated), 2);
    expect(restored.recordedEventKeys, containsAll(['event:a', 'event:b']));
    expect(restored.isMedalUnlocked('tasks_created_1'), isTrue);
    expect(restored.synced, isFalse);
  });

  test('copyWith atualiza campos', () {
    const state = AchievementProgressState();
    final next = state.copyWith(
      pointsByTrail: {AchievementTrailId.magicInput: 3},
      synced: false,
    );

    expect(next.pointsFor(AchievementTrailId.magicInput), 3);
    expect(next.synced, isFalse);
  });
}
