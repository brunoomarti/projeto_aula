import 'package:flutter_test/flutter_test.dart';

import 'package:tasker_project/features/achievements/domain/achievement_progress_state.dart';
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

      final events = CuriositiesTrailRules.eventsForNewTask(task);
      expect(events, hasLength(1));
      expect(events.first.trail, AchievementTrailId.curiosities);
      expect(events.first.eventKey, 'curiosities:flag_day:flag1');
    });

    test('aceita título com caixa diferente', () {
      final task = Task(
        id: 'flag2',
        title: '  ORDEM E PROGRESSO  ',
        data: '2026-11-19',
        hora: '10:00',
        createdAt: DateTime(2026, 11, 19),
      );

      expect(CuriositiesTrailRules.eventsForNewTask(task), isNotEmpty);
    });

    test('ignora fora do dia da bandeira', () {
      final task = Task(
        id: 'flag3',
        title: 'Ordem e progresso',
        data: '2026-11-18',
        hora: '10:00',
        createdAt: DateTime(2026, 11, 18),
      );

      expect(CuriositiesTrailRules.eventsForNewTask(task), isEmpty);
    });

    test('ignora título incorreto no dia certo', () {
      final task = Task(
        id: 'flag4',
        title: 'Outra coisa',
        data: '2026-11-19',
        hora: '10:00',
        createdAt: DateTime(2026, 11, 19),
      );

      expect(CuriositiesTrailRules.eventsForNewTask(task), isEmpty);
    });

    test('conta sequência de voz a partir das tarefas mais recentes', () {
      final tasks = [
        Task(
          id: '1',
          title: 'A',
          data: '2026-01-01',
          hora: '08:00',
          createdAt: DateTime(2026, 1, 1, 8),
          createdViaMagic: true,
          createdViaVoice: true,
        ),
        Task(
          id: '2',
          title: 'B',
          data: '2026-01-01',
          hora: '09:00',
          createdAt: DateTime(2026, 1, 1, 9),
          createdViaMagic: true,
        ),
        Task(
          id: '3',
          title: 'C',
          data: '2026-01-01',
          hora: '10:00',
          createdAt: DateTime(2026, 1, 1, 10),
          createdViaMagic: true,
          createdViaVoice: true,
        ),
      ];

      expect(CuriositiesTrailRules.currentVoiceCreationStreak(tasks), 1);
    });

    test('desbloqueia após 10 tarefas seguidas por voz', () {
      final tasks = List.generate(
        10,
        (i) => Task(
          id: 'v$i',
          title: 'Tarefa $i',
          data: '2026-06-01',
          hora: '10:00',
          createdAt: DateTime(2026, 6, 1, 10, i),
          createdViaMagic: true,
          createdViaVoice: true,
        ),
      );

      const state = AchievementProgressState();
      final event = CuriositiesTrailRules.eventForVoiceStreak(
        tasks: tasks,
        state: state,
      );

      expect(event, isNotNull);
      expect(event!.eventKey, CuriositiesTrailRules.voiceStreak10EventKey);
    });

    test('não repete evento de sequência de voz', () {
      final tasks = List.generate(
        10,
        (i) => Task(
          id: 'v$i',
          title: 'Tarefa $i',
          data: '2026-06-01',
          hora: '10:00',
          createdAt: DateTime(2026, 6, 1, 10, i),
          createdViaMagic: true,
          createdViaVoice: true,
        ),
      );

      const state = AchievementProgressState(
        recordedEventKeys: {CuriositiesTrailRules.voiceStreak10EventKey},
      );

      expect(
        CuriositiesTrailRules.eventForVoiceStreak(tasks: tasks, state: state),
        isNull,
      );
    });

    test('conta conclusões sem adiamento e zera ao adiar', () {
      final tasks = [
        Task(
          id: 'c1',
          title: 'A',
          data: '2026-01-01',
          hora: '08:00',
          done: true,
          createdAt: DateTime(2026, 1, 1, 8),
          completedAt: DateTime(2026, 1, 1, 9),
        ),
        Task(
          id: 'c2',
          title: 'B',
          data: '2026-01-02',
          hora: '08:00',
          done: true,
          postponed: true,
          createdAt: DateTime(2026, 1, 2, 8),
          lastUpdated: DateTime(2026, 1, 2, 10),
          completedAt: DateTime(2026, 1, 2, 11),
        ),
        Task(
          id: 'c3',
          title: 'C',
          data: '2026-01-03',
          hora: '08:00',
          done: true,
          createdAt: DateTime(2026, 1, 3, 8),
          completedAt: DateTime(2026, 1, 3, 9),
        ),
      ];

      expect(CuriositiesTrailRules.currentCleanCompletionStreak(tasks), 1);
    });

    test('desbloqueia após 100 conclusões sem adiar', () {
      final tasks = List.generate(
        100,
        (i) => Task(
          id: 's$i',
          title: 'Tarefa $i',
          data: '2026-06-01',
          hora: '10:00',
          done: true,
          createdAt: DateTime(2026, 6, 1, 8, i),
          completedAt: DateTime(2026, 6, 1, 9, i),
        ),
      );

      const state = AchievementProgressState();
      final event = CuriositiesTrailRules.eventForStampCollector(
        tasks: tasks,
        state: state,
      );

      expect(event, isNotNull);
      expect(event!.eventKey, CuriositiesTrailRules.stampCollector100EventKey);
    });

    test('reinicia contagem quando há adiamento no meio', () {
      final tasks = <Task>[
        ...List.generate(
          50,
          (i) => Task(
            id: 'ok$i',
            title: 'Ok $i',
            data: '2026-06-01',
            hora: '10:00',
            done: true,
            createdAt: DateTime(2026, 6, 1, 8, i),
            completedAt: DateTime(2026, 6, 1, 9, i),
          ),
        ),
        Task(
          id: 'delay',
          title: 'Adiada',
          data: '2026-06-02',
          hora: '10:00',
          postponed: true,
          createdAt: DateTime(2026, 6, 2, 8),
          lastUpdated: DateTime(2026, 6, 2, 12),
        ),
        ...List.generate(
          60,
          (i) => Task(
            id: 'after$i',
            title: 'Depois $i',
            data: '2026-06-03',
            hora: '10:00',
            done: true,
            createdAt: DateTime(2026, 6, 3, 8, i),
            completedAt: DateTime(2026, 6, 3, 9, i),
          ),
        ),
      ];

      expect(
        CuriositiesTrailRules.currentCleanCompletionStreak(tasks),
        60,
      );
      expect(
        CuriositiesTrailRules.eventForStampCollector(
          tasks: tasks,
          state: const AchievementProgressState(),
        ),
        isNull,
      );
    });

    test('conta adiantamentos registrados por tarefa', () {
      final keys = List.generate(
        13,
        (i) => 'task_advance:apollo:2026-06-0${i + 1}->2026-06-0${i + 2}',
      ).toSet();

      expect(
        CuriositiesTrailRules.advanceCountForTask('apollo', keys),
        13,
      );
      expect(
        CuriositiesTrailRules.advanceCountForTask('other', keys),
        0,
      );
    });

    test('desbloqueia ao concluir tarefa com 13 adiantamentos', () {
      final advanceKeys = List.generate(
        13,
        (i) => 'task_advance:apollo:2026-06-0${i + 1}->2026-06-0${i + 2}',
      );

      final tasks = [
        Task(
          id: 'apollo',
          title: 'Missão lunar',
          data: '2026-06-14',
          hora: '10:00',
          done: true,
          createdAt: DateTime(2026, 6, 1, 8),
          completedAt: DateTime(2026, 6, 14, 10),
        ),
      ];

      final state = AchievementProgressState(
        recordedEventKeys: advanceKeys.toSet(),
      );

      final event = CuriositiesTrailRules.eventForApollo13(
        tasks: tasks,
        state: state,
      );

      expect(event, isNotNull);
      expect(event!.eventKey, CuriositiesTrailRules.apollo13EventKey);
    });

    test('não desbloqueia com menos de 13 adiantamentos', () {
      final advanceKeys = List.generate(
        12,
        (i) => 'task_advance:apollo:2026-06-0${i + 1}->2026-06-0${i + 2}',
      );

      final tasks = [
        Task(
          id: 'apollo',
          title: 'Missão lunar',
          data: '2026-06-13',
          hora: '10:00',
          done: true,
          createdAt: DateTime(2026, 6, 1, 8),
          completedAt: DateTime(2026, 6, 13, 10),
        ),
      ];

      expect(
        CuriositiesTrailRules.eventForApollo13(
          tasks: tasks,
          state: AchievementProgressState(
            recordedEventKeys: advanceKeys.toSet(),
          ),
        ),
        isNull,
      );
    });

    test('não desbloqueia se a tarefa ainda não foi concluída', () {
      final advanceKeys = List.generate(
        13,
        (i) => 'task_advance:apollo:2026-06-0${i + 1}->2026-06-0${i + 2}',
      );

      final tasks = [
        Task(
          id: 'apollo',
          title: 'Missão lunar',
          data: '2026-06-14',
          hora: '10:00',
          createdAt: DateTime(2026, 6, 1, 8),
        ),
      ];

      expect(
        CuriositiesTrailRules.eventForApollo13(
          tasks: tasks,
          state: AchievementProgressState(
            recordedEventKeys: advanceKeys.toSet(),
          ),
        ),
        isNull,
      );
    });

    test('não repete evento Apollo 13', () {
      final advanceKeys = List.generate(
        13,
        (i) => 'task_advance:apollo:2026-06-0${i + 1}->2026-06-0${i + 2}',
      );

      final tasks = [
        Task(
          id: 'apollo',
          title: 'Missão lunar',
          data: '2026-06-14',
          hora: '10:00',
          done: true,
          createdAt: DateTime(2026, 6, 1, 8),
          completedAt: DateTime(2026, 6, 14, 10),
        ),
      ];

      expect(
        CuriositiesTrailRules.eventForApollo13(
          tasks: tasks,
          state: AchievementProgressState(
            recordedEventKeys: {
              ...advanceKeys,
              CuriositiesTrailRules.apollo13EventKey,
            },
          ),
        ),
        isNull,
      );
    });
  });
}
