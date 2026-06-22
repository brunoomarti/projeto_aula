import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:tasker_project/features/home/presentation/widgets/user_dock.dart';
import 'package:tasker_project/features/tasks/presentation/state/task_store.dart';

import 'support/test_task_store.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await initializeDateFormatting('pt_BR');
  });

  testWidgets('UserDock exibe saudação do visitante', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: UserDock(
            displayName: 'Visitante',
            selectedDate: DateTime(2026, 6, 21),
            onProfileTap: () {},
          ),
        ),
      ),
    );

    expect(find.textContaining('Visitante'), findsOneWidget);
  });

  testWidgets('TaskStore vazio não lista tarefas de hoje', (tester) async {
    final store = await readyTaskStoreForTest();
    addTearDown(store.dispose);

    await tester.pumpWidget(
      ChangeNotifierProvider<TaskStore>.value(
        value: store,
        child: MaterialApp(
          home: Builder(
            builder: (context) {
              final today = context.watch<TaskStore>().todayTasks();
              return Text(
                today.isEmpty
                    ? 'Nenhuma tarefa para hoje.'
                    : today.first.title,
              );
            },
          ),
        ),
      ),
    );

    expect(find.text('Nenhuma tarefa para hoje.'), findsOneWidget);
  });
}
