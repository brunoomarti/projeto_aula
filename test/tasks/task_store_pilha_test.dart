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

  test('addPilha cria e persiste pilha', () async {
    final store = await readyTaskStoreForTest();

    final pilha = await store.addPilha('  Estudos  ');

    expect(pilha.name, 'Estudos');
    expect(store.pilhaById(pilha.id)?.name, 'Estudos');
  });

  test('addPilha rejeita nome vazio', () async {
    final store = await readyTaskStoreForTest();

    expect(() => store.addPilha('   '), throwsArgumentError);
  });

  test('createPilhaWithTasks agrupa tarefas', () async {
    final store = await readyTaskStoreForTest();
    await store.addTask(testTask(id: 'a', title: 'A', hora: '08:00'));
    await store.addTask(testTask(id: 'b', title: 'B', hora: '09:00'));

    final pilha = await store.createPilhaWithTasks(
      name: 'Manhã',
      taskIds: ['a', 'b'],
    );

    expect(store.taskById('a')?.pilhaId, pilha.id);
    expect(store.taskById('b')?.pilhaId, pilha.id);
  });

  test('createPilhaWithTasks exige ao menos duas tarefas', () async {
    final store = await readyTaskStoreForTest();
    await store.addTask(testTask(id: 'a', title: 'A'));

    expect(
      () => store.createPilhaWithTasks(name: 'Solo', taskIds: ['a']),
      throwsArgumentError,
    );
  });

  test('assignTaskToPilha move tarefa para pilha', () async {
    final store = await readyTaskStoreForTest();
    await store.addTask(testTask(id: 'a', title: 'A'));
    await store.addTask(testTask(id: 'b', title: 'B'));
    final pilha = await store.createPilhaWithTasks(
      name: 'Grupo',
      taskIds: ['a', 'b'],
    );
    await store.addTask(testTask(id: 'c', title: 'C'));

    await store.assignTaskToPilha('c', pilha.id);

    expect(store.taskById('c')?.pilhaId, pilha.id);
  });

  test('removeTaskFromPilha dissolve pilha órfã', () async {
    final store = await readyTaskStoreForTest();
    await store.addTask(testTask(id: 'a', title: 'A'));
    await store.addTask(testTask(id: 'b', title: 'B'));
    final pilha = await store.createPilhaWithTasks(
      name: 'Par',
      taskIds: ['a', 'b'],
    );

    await store.removeTaskFromPilha('a');
    await store.removeTaskFromPilha('b');

    expect(store.pilhaById(pilha.id), isNull);
    expect(store.taskById('a')?.pilhaId, isNull);
    expect(store.taskById('b')?.pilhaId, isNull);
  });
}
