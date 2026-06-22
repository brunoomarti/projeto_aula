import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hugeicons/hugeicons.dart';

import 'package:tasker_project/features/tasks/domain/task.dart';
import 'package:tasker_project/features/tasks/presentation/widgets/task_card.dart';

import '../support/test_tasks.dart';

void main() {
  Future<void> pumpCard(WidgetTester tester, Task task) async {
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
  }

  testWidgets('formato de hora sem minutos', (tester) async {
    await pumpCard(tester, testTask(id: '1', title: 'A', hora: '09:00'));
    expect(find.textContaining('09h'), findsOneWidget);
  });

  testWidgets('formato de hora com minutos', (tester) async {
    await pumpCard(tester, testTask(id: '1', title: 'A', hora: '09:15'));
    expect(find.textContaining('09h15'), findsOneWidget);
  });

  testWidgets('hora vazia mostra travessão', (tester) async {
    await pumpCard(tester, testTask(id: '1', title: 'A', hora: ''));
    expect(find.text('—'), findsOneWidget);
  });

  testWidgets('tarefa concluída exibe opacidade', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TaskCard(
            task: testTask(id: '1', title: 'Feita', done: true),
            onOpenDetails: () {},
            onToggleDone: () {},
          ),
        ),
      ),
    );

    expect(find.bySemanticsLabel('Marcar como pendente'), findsOneWidget);
  });

  testWidgets('TaskCardIconBox renderiza ícone', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: TaskCardIconBox(
            icon: HugeIcons.strokeRoundedGuestHouse,
          ),
        ),
      ),
    );

    expect(find.byType(TaskCardIconBox), findsOneWidget);
  });
}
