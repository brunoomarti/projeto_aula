import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tasker_project/features/tasks/domain/pilha.dart';
import 'package:tasker_project/features/tasks/presentation/widgets/pilha_stack_card.dart';
import 'package:tasker_project/features/tasks/presentation/widgets/task_card.dart';

import '../support/test_tasks.dart';

void main() {
  testWidgets('PilhaStackCard exibe nome da pilha fechada', (tester) async {
    final pilha = Pilha(id: 'p1', name: 'Manhã produtiva');
    final tasks = [
      testTask(id: 'a', title: 'Café', hora: '07:00'),
      testTask(id: 'b', title: 'Emails', hora: '08:00'),
    ];
    var expanded = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PilhaStackCard(
            pilha: pilha,
            tasks: tasks,
            expanded: expanded,
            onToggleExpanded: () => expanded = !expanded,
            taskCardBuilder: (task) => TaskCard(
              task: task,
              onOpenDetails: () {},
              onToggleDone: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Manhã produtiva'), findsOneWidget);
    expect(find.byType(PilhaStackCard), findsOneWidget);
  });

  testWidgets('PilhaStackCard expandida lista tarefas', (tester) async {
    final pilha = Pilha(id: 'p1', name: 'Rotina');
    final tasks = [
      testTask(id: 'a', title: 'Alongar', hora: '07:00'),
      testTask(id: 'b', title: 'Meditação', hora: '07:30'),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PilhaStackCard(
            pilha: pilha,
            tasks: tasks,
            expanded: true,
            onToggleExpanded: () {},
            taskCardBuilder: (task) => TaskCard(
              task: task,
              onOpenDetails: () {},
              onToggleDone: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Alongar'), findsOneWidget);
    expect(find.text('Meditação'), findsOneWidget);
  });

  testWidgets('PilhaStackCard alterna expansão', (tester) async {
    final pilha = Pilha(id: 'p1', name: 'Rotina');
    final tasks = [
      testTask(id: 'a', title: 'Alongar', hora: '07:00'),
      testTask(id: 'b', title: 'Meditação', hora: '07:30'),
    ];
    var expanded = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PilhaStackCard(
            pilha: pilha,
            tasks: tasks,
            expanded: expanded,
            onToggleExpanded: () => expanded = !expanded,
            taskCardBuilder: (task) => TaskCard(
              task: task,
              onOpenDetails: () {},
              onToggleDone: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Rotina'));
    await tester.pump();

    expect(expanded, isTrue);
  });
}
