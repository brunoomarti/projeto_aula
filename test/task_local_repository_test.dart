import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:projeto_aula/features/tasks/domain/task.dart';
import 'package:projeto_aula/features/tasks/data/task_local_repository.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  test('addTask persiste tarefa localmente', () async {
    final now = DateTime.now();
    final task = Task(
      id: 'test-id',
      title: 'Teste',
      data: '2026-05-18',
      hora: '10:00',
      createdAt: now,
      lastUpdated: now,
      location: const TaskLocation(lat: -23.5, lng: -46.6),
    );

    await TaskLocalRepository.instance.addTask(task);
    final all = await TaskLocalRepository.instance.getAll();

    expect(all, hasLength(1));
    expect(all.first.title, 'Teste');
    expect(all.first.location?.lat, -23.5);
  });
}
