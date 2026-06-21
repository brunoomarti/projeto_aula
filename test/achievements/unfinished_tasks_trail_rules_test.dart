import 'package:flutter_test/flutter_test.dart';

import 'package:tasker_project/features/achievements/domain/rules/unfinished_tasks_trail_rules.dart';
import 'package:tasker_project/features/tasks/domain/task.dart';
import 'package:tasker_project/features/tasks/presentation/state/task_store.dart';

void main() {
  final monday = DateTime(2026, 6, 15);
  final mondayYmd = TaskStore.formatDateYmd(monday);
  final tuesday = DateTime(2026, 6, 16);

  Task scheduled({
    required String id,
    required String data,
    bool done = false,
    DateTime? completedAt,
  }) {
    return Task(
      id: id,
      title: id,
      data: data,
      hora: '10:00',
      createdAt: monday,
      lastUpdated: monday,
      done: done,
      completedAt: completedAt,
    );
  }

  group('UnfinishedTasksTrailRules', () {
    test('não avalia antes do dia encerrar', () {
      final event = UnfinishedTasksTrailRules.eventForDay(
        day: monday,
        tasks: [scheduled(id: '1', data: mondayYmd)],
        now: monday.add(const Duration(hours: 20)),
      );
      expect(event, isNull);
    });

    test('conta 1 ponto quando há pendência após virar o dia', () {
      final event = UnfinishedTasksTrailRules.eventForDay(
        day: monday,
        tasks: [scheduled(id: '1', data: mondayYmd)],
        now: tuesday,
      );
      expect(event, isNotNull);
      expect(event!.eventKey, contains('2026-06-15'));
    });

    test('máximo 1 ponto por dia mesmo com várias pendências', () {
      final tasks = [
        scheduled(id: '1', data: mondayYmd),
        scheduled(id: '2', data: mondayYmd),
        scheduled(id: '3', data: mondayYmd),
      ];
      expect(
        UnfinishedTasksTrailRules.hadUnfinishedTasksOnDay(
          day: monday,
          tasks: tasks,
        ),
        isTrue,
      );
      final event = UnfinishedTasksTrailRules.eventForDay(
        day: monday,
        tasks: tasks,
        now: tuesday,
      );
      expect(event, isNotNull);
    });

    test('não conta se tarefa foi concluída no mesmo dia', () {
      final event = UnfinishedTasksTrailRules.eventForDay(
        day: monday,
        tasks: [
          scheduled(
            id: '1',
            data: mondayYmd,
            done: true,
            completedAt: monday.add(const Duration(hours: 18)),
          ),
        ],
        now: tuesday,
      );
      expect(event, isNull);
    });

    test('conta se conclusão foi após o dia civil', () {
      final event = UnfinishedTasksTrailRules.eventForDay(
        day: monday,
        tasks: [
          scheduled(
            id: '1',
            data: mondayYmd,
            done: true,
            completedAt: tuesday.add(const Duration(hours: 8)),
          ),
        ],
        now: tuesday,
      );
      expect(event, isNotNull);
    });

    test('tarefa movida para outro dia não aparece em monday', () {
      final tuesdayYmd = TaskStore.formatDateYmd(tuesday);
      final event = UnfinishedTasksTrailRules.eventForDay(
        day: monday,
        tasks: [scheduled(id: '1', data: tuesdayYmd)],
        now: tuesday,
      );
      expect(event, isNull);
    });
  });
}
