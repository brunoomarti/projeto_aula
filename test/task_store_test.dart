import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:projeto_aula/features/tasks/data/task_local_repository.dart';
import 'package:projeto_aula/features/tasks/domain/task.dart';
import 'package:projeto_aula/features/tasks/presentation/state/task_store.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  Task _task({
    required String id,
    required String title,
    String? data,
    String hora = '10:00',
    bool done = false,
  }) {
    final now = DateTime.now();
    return Task(
      id: id,
      title: title,
      data: data ?? TaskStore.formatDateYmd(now),
      hora: hora,
      done: done,
      createdAt: now,
      lastUpdated: now,
    );
  }

  test('initialize carrega tarefas do repositório', () async {
    await TaskLocalRepository.instance.addTask(_task(id: '1', title: 'A'));

    final store = TaskStore();
    await store.initialize();

    expect(store.tasks, hasLength(1));
    expect(store.taskById('1')?.title, 'A');
  });

  test('addTask reflete imediatamente em todayTasks', () async {
    final store = TaskStore();
    await store.initialize();

    await store.addTask(_task(id: '2', title: 'Hoje', hora: '08:00'));

    expect(store.todayTasks(), hasLength(1));
    expect(store.todayTasks().first.title, 'Hoje');
  });

  test('updateTaskDone move tarefa para completedTasks', () async {
    final store = TaskStore();
    await store.initialize();
    await store.addTask(_task(id: '3', title: 'Fechar'));

    await store.updateTaskDone('3', true);

    expect(store.taskById('3')?.done, isTrue);
    expect(store.completedTasks, hasLength(1));
    expect(store.todayTasks().single.done, isTrue);
  });

  test('todayTasks reordena pendentes por hora ao desfazer conclusão', () async {
    final store = TaskStore();
    await store.initialize();

    await store.addTask(_task(id: 'a', title: 'A', hora: '08:00'));
    await store.addTask(_task(id: 'b', title: 'B', hora: '09:00'));
    await store.addTask(_task(id: 'c', title: 'C', hora: '10:00'));

    await store.updateTaskDone('b', true);
    expect(store.todayTasks().map((t) => t.id), ['a', 'c', 'b']);

    await store.updateTaskDone('b', false);
    expect(store.todayTasks().map((t) => t.id), ['a', 'b', 'c']);
  });

  test('markTaskDeleted remove da contagem ativa', () async {
    final store = TaskStore();
    await store.initialize();
    await store.addTask(_task(id: '4', title: 'Apagar'));

    await store.markTaskDeleted('4');

    expect(store.totalActiveCount, 0);
    expect(store.taskById('4')?.deleted, isTrue);
  });
}
