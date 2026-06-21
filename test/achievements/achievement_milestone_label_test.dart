import 'package:flutter_test/flutter_test.dart';

import 'package:tasker_project/features/achievements/domain/achievement_milestone_label.dart';
import 'package:tasker_project/features/achievements/domain/achievement_trail_id.dart';

void main() {
  group('AchievementMilestoneLabel', () {
    test('pendências usa marco curto por threshold', () {
      expect(
        AchievementMilestoneLabel.forMedal(
          trail: AchievementTrailId.unfinishedTasks,
          threshold: 1,
        ),
        '1 dia com pendências',
      );
      expect(
        AchievementMilestoneLabel.forMedal(
          trail: AchievementTrailId.unfinishedTasks,
          threshold: 5,
        ),
        'Acumule 5 dias com pendências',
      );
    });

    test('tarefas criadas pluraliza corretamente', () {
      expect(
        AchievementMilestoneLabel.forMedal(
          trail: AchievementTrailId.tasksCreated,
          threshold: 10,
        ),
        '10 tarefas criadas',
      );
    });
  });
}
