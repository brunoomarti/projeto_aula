import 'package:flutter_test/flutter_test.dart';

import 'package:tasker_project/features/home/domain/home_task_drag_rules.dart';
import 'package:tasker_project/features/tasks/presentation/state/task_store.dart';

import '../support/test_tasks.dart';

void main() {
  final today = DateTime(2026, 6, 21);
  final tomorrow = DateTime(2026, 6, 22);

  group('canDropTaskOnDay', () {
    test('permite soltar em outro dia', () {
      final task = testTask(
        id: '1',
        title: 'A',
        data: TaskStore.formatDateYmd(today),
      );

      expect(
        HomeTaskDragRules.canDropTaskOnDay(task, tomorrow, now: today),
        isTrue,
      );
    });

    test('bloqueia soltar no mesmo dia', () {
      final task = testTask(
        id: '1',
        title: 'A',
        data: TaskStore.formatDateYmd(today),
      );

      expect(
        HomeTaskDragRules.canDropTaskOnDay(task, today, now: today),
        isFalse,
      );
    });

    test('tarefa sem data usa hoje como referência', () {
      final task = testTask(id: '1', title: 'A', data: '');

      expect(
        HomeTaskDragRules.canDropTaskOnDay(task, tomorrow, now: today),
        isTrue,
      );
      expect(
        HomeTaskDragRules.canDropTaskOnDay(task, today, now: today),
        isFalse,
      );
    });
  });

  group('canAcceptStackDrop', () {
    final dragged = testTask(id: 'a', title: 'A');
    final target = testTask(id: 'b', title: 'B');
    bool pilhaExists(String id) => id == 'p1';

    test('rejeita arrastar sobre si mesma', () {
      expect(
        HomeTaskDragRules.canAcceptStackDrop(
          dragged: dragged,
          targetTask: dragged,
          pilhaExists: pilhaExists,
        ),
        isFalse,
      );
    });

    test('aceita empilhar em tarefa avulsa', () {
      expect(
        HomeTaskDragRules.canAcceptStackDrop(
          dragged: dragged,
          targetTask: target,
          pilhaExists: pilhaExists,
        ),
        isTrue,
      );
    });

    test('rejeita empilhar em tarefa que já está em pilha', () {
      final inPilha = testTask(id: 'b', title: 'B', pilhaId: 'p1');

      expect(
        HomeTaskDragRules.canAcceptStackDrop(
          dragged: dragged,
          targetTask: inPilha,
          pilhaExists: pilhaExists,
        ),
        isFalse,
      );
    });

    test('aceita soltar em pilha existente', () {
      final pilhaTasks = [
        testTask(id: 'x', title: 'X', pilhaId: 'p1'),
        testTask(id: 'y', title: 'Y', pilhaId: 'p1'),
      ];

      expect(
        HomeTaskDragRules.canAcceptStackDrop(
          dragged: dragged,
          targetPilhaId: 'p1',
          pilhaTasks: pilhaTasks,
          pilhaExists: pilhaExists,
        ),
        isTrue,
      );
    });

    test('rejeita tarefa já na pilha alvo', () {
      final draggedInPilha = testTask(id: 'x', title: 'X', pilhaId: 'p1');
      final pilhaTasks = [
        draggedInPilha,
        testTask(id: 'y', title: 'Y', pilhaId: 'p1'),
      ];

      expect(
        HomeTaskDragRules.canAcceptStackDrop(
          dragged: draggedInPilha,
          targetPilhaId: 'p1',
          pilhaTasks: pilhaTasks,
          pilhaExists: pilhaExists,
        ),
        isFalse,
      );
    });
  });
}
