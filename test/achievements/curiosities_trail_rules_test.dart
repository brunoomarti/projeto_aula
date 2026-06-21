import 'package:flutter_test/flutter_test.dart';

import 'package:tasker_project/features/achievements/domain/achievement_trail_id.dart';
import 'package:tasker_project/features/achievements/domain/rules/curiosities_trail_rules.dart';
import 'package:tasker_project/features/tasks/domain/task.dart';
import 'package:tasker_project/features/tasks/presentation/state/task_store.dart';

void main() {
  group('CuriositiesTrailRules', () {
    test('gera evento no dia da bandeira com título correto', () {
      final task = Task(
        id: 'flag1',
        title: 'Ordem e progresso',
        data: TaskStore.formatDateYmd(DateTime(2026, 11, 19)),
        hora: '10:00',
        createdAt: DateTime(2026, 11, 19, 9, 30),
      );

      final event = CuriositiesTrailRules.eventForNewTask(task);
      expect(event, isNotNull);
      expect(event!.trail, AchievementTrailId.curiosities);
      expect(event.eventKey, 'curiosities:flag_day:flag1');
    });

    test('aceita título com caixa diferente', () {
      final task = Task(
        id: 'flag2',
        title: '  ORDEM E PROGRESSO  ',
        data: '2026-11-19',
        hora: '10:00',
        createdAt: DateTime(2026, 11, 19),
      );

      expect(CuriositiesTrailRules.eventForNewTask(task), isNotNull);
    });

    test('ignora fora do dia da bandeira', () {
      final task = Task(
        id: 'flag3',
        title: 'Ordem e progresso',
        data: '2026-11-18',
        hora: '10:00',
        createdAt: DateTime(2026, 11, 18),
      );

      expect(CuriositiesTrailRules.eventForNewTask(task), isNull);
    });

    test('ignora título incorreto no dia certo', () {
      final task = Task(
        id: 'flag4',
        title: 'Outra coisa',
        data: '2026-11-19',
        hora: '10:00',
        createdAt: DateTime(2026, 11, 19),
      );

      expect(CuriositiesTrailRules.eventForNewTask(task), isNull);
    });
  });
}
