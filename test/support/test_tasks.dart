import 'package:tasker_project/features/tasks/domain/task.dart';
import 'package:tasker_project/features/tasks/presentation/state/task_store.dart';

Task testTask({
  required String id,
  required String title,
  String? data,
  String hora = '10:00',
  bool done = false,
  String? pilhaId,
  bool postponed = false,
  bool scheduleAdjusted = false,
  DateTime? createdAt,
}) {
  final now = createdAt ?? DateTime(2026, 6, 21, 10);
  return Task(
    id: id,
    title: title,
    data: data ?? TaskStore.formatDateYmd(now),
    hora: hora,
    done: done,
    pilhaId: pilhaId,
    postponed: postponed,
    scheduleAdjusted: scheduleAdjusted,
    createdAt: createdAt ?? now,
    lastUpdated: now,
  );
}
