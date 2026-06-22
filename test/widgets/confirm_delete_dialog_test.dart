import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tasker_project/features/tasks/presentation/widgets/confirm_delete_dialog.dart';

void main() {
  testWidgets('ConfirmDeleteDialog exibe título da tarefa', (tester) async {
    var confirmed = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ConfirmDeleteDialog(
            open: true,
            taskTitle: 'Comprar pão',
            onCancel: () {},
            onConfirm: () async {
              confirmed = true;
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Excluir tarefa?'), findsOneWidget);
    expect(find.textContaining('Comprar pão'), findsOneWidget);

    await tester.tap(find.text('Excluir'));
    await tester.pumpAndSettle();

    expect(confirmed, isTrue);
  });

  testWidgets('ConfirmDeleteDialog cancela ao tocar fora', (tester) async {
    var cancelled = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ConfirmDeleteDialog(
            open: true,
            taskTitle: 'Teste',
            onCancel: () => cancelled = true,
            onConfirm: () async {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    expect(cancelled, isTrue);
  });
}
