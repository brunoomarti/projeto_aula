import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tasker_project/core/widgets/profile_initials_avatar.dart';
import 'package:tasker_project/core/widgets/tasker_sliding_segmented_control.dart';
import 'package:tasker_project/features/tasks/domain/task_icon_catalog.dart';
import 'package:tasker_project/features/tasks/presentation/widgets/complete_input.dart';
import 'package:tasker_project/features/tasks/presentation/widgets/task_icon_picker_section.dart';
import 'package:tasker_project/features/tasks/presentation/widgets/task_page_header.dart';
import 'package:tasker_project/features/tasks/presentation/widgets/task_stack_drag.dart';

import '../support/test_tasks.dart';

void main() {
  group('profileInitialsFromName', () {
    test('duas palavras', () {
      expect(profileInitialsFromName('Ana Silva'), 'AS');
    });

    test('palavra única longa', () {
      expect(profileInitialsFromName('Bruno'), 'BR');
    });

    test('vazio', () {
      expect(profileInitialsFromName('  '), '?');
    });
  });

  testWidgets('ProfileInitialsAvatar exibe iniciais', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ProfileInitialsAvatar(initials: 'AB', size: 40),
        ),
      ),
    );

    expect(find.text('AB'), findsOneWidget);
  });

  testWidgets('TaskPageHeader exibe título e volta', (tester) async {
    var back = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TaskPageHeader(
            title: 'Nova tarefa',
            subtitle: 'Passo 1',
            onBack: () => back = true,
          ),
        ),
      ),
    );

    expect(find.text('Nova tarefa'), findsOneWidget);
    expect(find.text('Passo 1'), findsOneWidget);

    await tester.tap(find.byType(InkWell).first);
    await tester.pump();

    expect(back, isTrue);
  });

  testWidgets('TaskerSlidingSegmentedControl alterna seleção', (tester) async {
    var selected = 'a';

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            return Scaffold(
              body: TaskerSlidingSegmentedControl<String>(
                selected: selected,
                onChanged: (v) => setState(() => selected = v),
                segments: const [
                  TaskerSegment(value: 'a', label: 'Opção A'),
                  TaskerSegment(value: 'b', label: 'Opção B'),
                ],
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Opção B'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(selected, 'b');
  });

  testWidgets('CompleteInput envolve campo com label', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CompleteInput(
            label: 'Título',
            child: TextField(
              decoration: TaskerFieldDecoration.decoration(hintText: 'Digite'),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Título'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('TaskIconPickerSection expande grade', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TaskIconPickerSection(
            iconKey: TaskIconCatalog.defaultIconKey,
            backgroundArgb: TaskIconCatalog.defaultColor.backgroundArgb,
            onIconChanged: (_) {},
            onColorChanged: (_) {},
          ),
        ),
      ),
    );

    await tester.tap(find.byType(InkWell).first);
    await tester.pumpAndSettle();

    expect(find.text('Ícone'), findsOneWidget);
  });

  testWidgets('TaskDragWrapper desabilitado mostra filho', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TaskDragWrapper(
            enabled: false,
            task: testTask(id: '1', title: 'Arrastar'),
            child: const Text('Conteúdo'),
          ),
        ),
      ),
    );

    expect(find.text('Conteúdo'), findsOneWidget);
  });

  test('TaskDragData transporta tarefa', () {
    final task = testTask(id: '1', title: 'X');
    final data = TaskDragData(task);
    expect(data.task.id, '1');
  });
}
