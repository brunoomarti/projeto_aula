import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:tasker_project/features/tasks/domain/task.dart';
import 'package:tasker_project/features/tasks/presentation/state/task_store.dart';

import '../auth/fake_repositories.dart';
import '../support/fake_connectivity_service.dart';
import '../support/test_task_store.dart';
import '../support/test_tasks.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<void> waitForMicrotasks() async {
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }

  test('clear remove tarefas e pilhas', () async {
    final store = await readyTaskStoreForTest();
    await store.addTask(testTask(id: '1', title: 'A'));
    await store.addPilha('P');

    await store.clear();

    expect(store.isInitialized, isFalse);
    expect(store.totalActiveCount, 0);
    expect(store.pilhas, isEmpty);
  });

  test('sync com nuvem mescla tarefas remotas', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final repo = FakeTaskRepository();
    repo.tasks.add(
      testTask(id: 'remote', title: 'Da nuvem').copyWith(synced: true),
    );

    final store = TaskStore(
      repository: repo,
      connectivity: FakeConnectivityService(),
      firebaseAuth: MockFirebaseAuth(signedIn: false),
    );
    store.setCloudSyncEnabled(true);
    await store.reload();
    await waitForMicrotasks();

    expect(store.taskById('remote')?.title, 'Da nuvem');
    store.dispose();
  });

  test('persistTaskLocationAddress grava endereço', () async {
    final store = await readyTaskStoreForTest();
    await store.addTask(
      testTask(id: 'loc', title: 'Ir').copyWith(
        location: const TaskLocation(lat: -23.0, lng: -46.0),
      ),
    );

    await store.persistTaskLocationAddress('loc', 'Av. Paulista, 1000');

    expect(
      store.taskById('loc')?.location?.formattedAddress,
      'Av. Paulista, 1000',
    );
  });

  test('completedTasks ordena por hora decrescente', () async {
    final store = await readyTaskStoreForTest();
    await store.addTask(testTask(id: 'a', title: 'A', hora: '08:00', done: true));
    await store.addTask(testTask(id: 'b', title: 'B', hora: '12:00', done: true));

    expect(store.completedTasks.map((t) => t.id), ['b', 'a']);
  });

  test('refreshFromDisk recarrega do SharedPreferences', () async {
    final store = await readyTaskStoreForTest();
    await store.addTask(testTask(id: 'disk', title: 'Disco'));

    final other = await readyTaskStoreForTest();
    await other.refreshFromDisk();

    expect(other.taskById('disk')?.title, 'Disco');
    other.dispose();
  });
}
