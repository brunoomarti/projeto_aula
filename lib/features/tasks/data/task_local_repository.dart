import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/task.dart';

/// Armazenamento local no dispositivo (JSON em [SharedPreferences]).
class TaskLocalRepository {
  TaskLocalRepository._();

  static final TaskLocalRepository instance = TaskLocalRepository._();

  static const _tasksKey = 'tasker_tasks_json';

  Future<List<Task>> getAll() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_tasksKey);
      if (raw == null || raw.trim().isEmpty) return [];

      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];

      final tasks = <Task>[];
      for (final item in decoded) {
        if (item is! Map) continue;
        try {
          tasks.add(Task.fromJson(Map<String, dynamic>.from(item)));
        } catch (e, st) {
          debugPrint('TaskLocalRepository: item ignorado: $e\n$st');
        }
      }
      return tasks;
    } on MissingPluginException {
      rethrow;
    } catch (e, st) {
      debugPrint('TaskLocalRepository.getAll: $e\n$st');
      return [];
    }
  }

  Future<void> _saveAll(List<Task> tasks) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(tasks.map((t) => t.toLocalJson()).toList());
    final ok = await prefs.setString(_tasksKey, encoded);
    if (!ok) {
      throw StateError('Não foi possível gravar as tarefas no dispositivo.');
    }
  }

  Future<void> addTask(Task task) async {
    final all = await getAll();
    all.add(task);
    await _saveAll(all);
  }

  Future<void> updateTask(Task task) async {
    final all = await getAll();
    final index = all.indexWhere((t) => t.id == task.id);
    if (index < 0) return;
    all[index] = task;
    await _saveAll(all);
  }

  Future<void> updateTaskDone(String taskId, bool done) async {
    final all = await getAll();
    final index = all.indexWhere((t) => t.id == taskId);
    if (index < 0) return;

    all[index] = all[index].copyWith(
      done: done,
      lastUpdated: DateTime.now(),
    );
    await _saveAll(all);
  }

  Future<List<Task>> getByDate(String dataYmd) async {
    final all = await getAll();
    return all.where((t) => !t.deleted && t.data == dataYmd).toList();
  }

  /// Tarefas de hoje — com fallback igual ao [tasksComponent.jsx] do web.
  Future<List<Task>> getTasksForToday(DateTime now) async {
    final hoje =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    var tasks = await getByDate(hoje);
    if (tasks.isNotEmpty) return tasks;

    final all = await getAll();
    return all.where((t) => !t.deleted && (t.data == hoje || t.data.isEmpty)).toList();
  }

  Future<List<Task>> getCompleted() async {
    final all = await getAll();
    return all.where((t) => !t.deleted && t.done).toList();
  }
}
