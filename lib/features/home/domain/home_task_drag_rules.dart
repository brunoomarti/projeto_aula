import '../../tasks/domain/task.dart';
import '../../tasks/presentation/state/task_store.dart';

/// Regras puras de arrastar tarefas entre dias e empilhar na home.
abstract final class HomeTaskDragRules {
  /// Tarefa pode ser solta em [day] (dia diferente do agendamento atual).
  static bool canDropTaskOnDay(
    Task task,
    DateTime day, {
    DateTime? now,
  }) {
    final targetYmd = TaskStore.formatDateYmd(day);
    final todayYmd = TaskStore.formatDateYmd(now ?? DateTime.now());
    final taskYmd = task.data.isEmpty ? todayYmd : task.data;
    return taskYmd != targetYmd;
  }

  static bool taskHasValidPilha(
    Task task, {
    required bool Function(String pilhaId) pilhaExists,
  }) {
    final pilhaId = task.pilhaId;
    return pilhaId != null && pilhaId.isNotEmpty && pilhaExists(pilhaId);
  }

  /// Aceita soltar [dragged] em outra tarefa ou em pilha existente.
  static bool canAcceptStackDrop({
    required Task dragged,
    Task? targetTask,
    String? targetPilhaId,
    List<Task>? pilhaTasks,
    required bool Function(String pilhaId) pilhaExists,
  }) {
    if (targetTask != null) {
      if (dragged.id == targetTask.id) return false;
      if (taskHasValidPilha(targetTask, pilhaExists: pilhaExists)) {
        return false;
      }
      return true;
    }

    if (targetPilhaId != null && pilhaTasks != null) {
      if (pilhaTasks.any((t) => t.id == dragged.id)) return false;
      if (dragged.pilhaId == targetPilhaId) return false;
      return true;
    }

    return false;
  }
}
