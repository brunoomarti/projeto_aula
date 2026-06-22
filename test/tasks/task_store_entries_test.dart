import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:tasker_project/features/tasks/domain/home_list_entry.dart';
import 'package:tasker_project/features/tasks/presentation/state/task_store.dart';

import '../support/test_task_store.dart';
import '../support/test_tasks.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  final fixedNow = DateTime(2026, 6, 21, 12);
  final ymd = TaskStore.formatDateYmd(fixedNow);

  test('entriesForDate agrupa pilha e mantém avulsas', () async {
    final store = await readyTaskStoreForTest();
    await store.addTask(testTask(id: 'a', title: 'A', hora: '08:00', data: ymd));
    await store.addTask(testTask(id: 'b', title: 'B', hora: '09:00', data: ymd));
    await store.addTask(testTask(id: 'c', title: 'C', hora: '10:00', data: ymd));
    await store.createPilhaWithTasks(name: 'Pilha', taskIds: ['a', 'b']);

    final entries = store.entriesForDate(fixedNow, now: fixedNow);

    expect(entries, hasLength(2));
    expect(entries[0], isA<HomePilhaEntry>());
    expect(entries[1], isA<HomeSingleTaskEntry>());
    final pilhaEntry = entries[0] as HomePilhaEntry;
    expect(pilhaEntry.tasks, hasLength(2));
  });

  test('taskStatsForDate conta concluídas', () async {
    final store = await readyTaskStoreForTest();
    await store.addTask(
      testTask(id: 'a', title: 'A', data: ymd, done: true),
    );
    await store.addTask(testTask(id: 'b', title: 'B', data: ymd));

    final stats = store.taskStatsForDate(fixedNow, now: fixedNow);

    expect(stats.total, 2);
    expect(stats.completed, 1);
  });

  test('tasksForDate inclui tarefas sem data no dia atual', () async {
    final store = await readyTaskStoreForTest();
    await store.addTask(testTask(id: 'legacy', title: 'Legado', data: ''));

    final tasks = store.tasksForDate(fixedNow, now: fixedNow);

    expect(tasks, hasLength(1));
    expect(tasks.first.title, 'Legado');
  });

  test('horaSortKey ordena por minutos', () {
    expect(TaskStore.horaSortKey('08:30'), lessThan(TaskStore.horaSortKey('09:00')));
    expect(TaskStore.horaSortKey('invalid'), 0);
  });

  test('formatDateYmd e dateOnly', () {
    final d = DateTime(2026, 6, 5);
    expect(TaskStore.formatDateYmd(d), '2026-06-05');
    expect(TaskStore.dateOnly(DateTime(2026, 6, 5, 15, 30)), DateTime(2026, 6, 5));
  });
}
