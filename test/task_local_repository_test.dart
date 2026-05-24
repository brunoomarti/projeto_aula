import 'dart:convert';

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

  test('location sobrevive round-trip via jsonEncode', () async {
    final now = DateTime.now();
    final task = Task(
      id: 'loc-id',
      title: 'Com GPS',
      data: '2026-05-21',
      hora: '12:00',
      createdAt: now,
      lastUpdated: now,
      location: const TaskLocation(lat: -23.5505, lng: -46.6333),
    );

    await TaskLocalRepository.instance.addTask(task);
    final raw = (await SharedPreferences.getInstance())
        .getString('tasker_tasks_json');
    expect(raw, isNotNull);

    final list = jsonDecode(raw!) as List;
    final item = list.first;
    final loaded = Task.fromJson(
      Map<String, dynamic>.from(item as Map<dynamic, dynamic>),
    );

    expect(loaded.location?.lat, closeTo(-23.5505, 0.0001));
    expect(loaded.location?.lng, closeTo(-46.6333, 0.0001));
  });
}
