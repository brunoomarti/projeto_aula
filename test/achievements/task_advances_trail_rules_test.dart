import 'package:flutter_test/flutter_test.dart';

import 'package:tasker_project/features/achievements/domain/achievement_trail_id.dart';
import 'package:tasker_project/features/achievements/domain/rules/task_advances_trail_rules.dart';
import 'package:tasker_project/features/tasks/domain/task.dart';
import 'package:tasker_project/features/tasks/presentation/state/task_store.dart';

void main() {
  final created = DateTime(2026, 6, 18, 10, 0);
  final mondayYmd = '2026-06-18';
  final wednesdayYmd = '2026-06-20';
  final tuesdayYmd = '2026-06-19';

  Task base({required String data}) {
    return Task(
      id: 't1',
      title: 'Tarefa',
      data: data,
      hora: '10:00',
      createdAt: created,
      lastUpdated: created,
    );
  }

  group('TaskAdvancesTrailRules', () {
    test('conta adiantamento após 1 h da criação', () {
      final previous = base(data: mondayYmd);
      final updated = base(data: wednesdayYmd);
      final now = created.add(const Duration(hours: 2));

      final event = TaskAdvancesTrailRules.eventForDateChange(
        previous: previous,
        updated: updated,
        now: now,
      );

      expect(event, isNotNull);
      expect(event!.trail, AchievementTrailId.taskAdvances);
    });

    test('ignora edição dentro de 1 h', () {
      final previous = base(data: mondayYmd);
      final updated = base(data: wednesdayYmd);
      final now = created.add(const Duration(minutes: 30));

      expect(
        TaskAdvancesTrailRules.eventForDateChange(
          previous: previous,
          updated: updated,
          now: now,
        ),
        isNull,
      );
    });

    test('ignora retrocesso de data', () {
      final previous = base(data: wednesdayYmd);
      final updated = base(data: mondayYmd);
      final now = created.add(const Duration(hours: 3));

      expect(
        TaskAdvancesTrailRules.eventForDateChange(
          previous: previous,
          updated: updated,
          now: now,
        ),
        isNull,
      );
    });

    test('aceita avanço de um dia', () {
      final previous = base(data: mondayYmd);
      final updated = base(data: tuesdayYmd);
      final now = created.add(const Duration(hours: 2));

      expect(
        TaskAdvancesTrailRules.eventForDateChange(
          previous: previous,
          updated: updated,
          now: now,
        ),
        isNotNull,
      );
    });
  });
}
