import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tasker_project/features/tasks/domain/task_icon_catalog.dart';
import 'package:tasker_project/features/tasks/presentation/widgets/task_card.dart';

import '../support/test_tasks.dart';

void main() {
  testWidgets('TaskCard exibe título da tarefa', (tester) async {
    final task = testTask(id: '1', title: 'Comprar leite', hora: '14:00');

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TaskCard(
            task: task,
            onOpenDetails: () {},
            onToggleDone: () {},
          ),
        ),
      ),
    );

    expect(find.text('Comprar leite'), findsOneWidget);
  });

  testWidgets('TaskCard alterna conclusão ao tocar', (tester) async {
    var toggled = false;
    final task = testTask(id: '1', title: 'Estudar', hora: '09:00');

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TaskCard(
            task: task,
            onOpenDetails: () {},
            onToggleDone: () => toggled = true,
          ),
        ),
      ),
    );

    await tester.tap(find.bySemanticsLabel('Marcar como concluída'));
    await tester.pump();

    expect(toggled, isTrue);
  });

  testWidgets('TaskCardSurface mostra hora formatada', (tester) async {
    final task = testTask(id: '1', title: 'Reunião', hora: '15:30');

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TaskCardSurface(
            task: task,
            showDoneToggle: false,
          ),
        ),
      ),
    );

    expect(find.textContaining('15h30'), findsOneWidget);
  });

  test('TaskIconCatalog resolve ícone padrão', () {
    final task = testTask(id: '1', title: 'A');
    expect(TaskIconCatalog.labelFor(task), 'Casa');
    expect(TaskIconCatalog.optionForKey(null).key, TaskIconCatalog.defaultIconKey);
  });

  test('TaskIconCatalog presetForArgb', () {
    final preset = TaskIconCatalog.presetForArgb(
      TaskIconCatalog.defaultColor.backgroundArgb,
    );
    expect(preset.background, TaskIconCatalog.defaultColor.background);
  });
}
