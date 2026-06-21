import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/auth/firebase_user_id.dart';
import '../../../core/bootstrap/app_bootstrap.dart';
import '../domain/task.dart';
import 'task_repository.dart';

class TaskSupabaseRepository implements TaskRepository {
  TaskSupabaseRepository({SupabaseClient? client})
      : _client = client ?? AppBootstrap.supabase;

  final SupabaseClient _client;

  static const _table = 'tasks';

  String? get _userId => currentFirebaseUserId();

  @override
  Future<List<Task>> fetchAll() async {
    final userId = _userId;
    if (userId == null) return [];

    final rows = await _client
        .from(_table)
        .select()
        .eq('user_id', userId)
        .order('last_updated', ascending: false);

    final tasks = <Task>[];
    for (final row in rows) {
      try {
        tasks.add(Task.fromSupabaseRow(Map<String, dynamic>.from(row)));
      } catch (e, st) {
        // ignore: avoid_print
        print('TaskSupabaseRepository: linha ignorada: $e\n$st');
      }
    }
    return tasks;
  }

  @override
  Future<void> upsertTask(Task task) async {
    final userId = _userId;
    if (userId == null) {
      throw StateError('Usuário não autenticado no Supabase.');
    }

    await _client.from(_table).upsert(task.toSupabaseRow(userId));
  }
}
