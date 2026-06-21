import '../domain/task.dart';

/// Persistência de tarefas (Supabase).
abstract class TaskRepository {
  Future<List<Task>> fetchAll();

  Future<void> upsertTask(Task task);
}
