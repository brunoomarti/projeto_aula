import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tasker_project/features/tasks/presentation/widgets/task_form_footer.dart';

void main() {
  testWidgets('TaskFormStepNavFooter exibe voltar e próximo', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TaskFormStepNavFooter(
            showBack: true,
            onBack: () {},
            onNext: () {},
            nextLabel: 'Próximo',
            backLabel: 'Voltar',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Voltar'), findsOneWidget);
    expect(find.text('Próximo'), findsOneWidget);
  });

  testWidgets('TaskFormStepNavFooter dispara callbacks', (tester) async {
    var back = false;
    var next = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TaskFormStepNavFooter(
            showBack: true,
            onBack: () => back = true,
            onNext: () => next = true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Voltar'));
    await tester.tap(find.text('Próximo'));
    await tester.pump();

    expect(back, isTrue);
    expect(next, isTrue);
  });
}
