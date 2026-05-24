import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:tasker_project/features/tasks/presentation/state/task_store.dart';
import 'package:tasker_project/main.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await initializeDateFormatting('pt_BR');
  });

  testWidgets('App inicia na home e abre perfil', (tester) async {
    final store = TaskStore();
    await store.initialize();

    await tester.pumpWidget(
      ChangeNotifierProvider<TaskStore>.value(
        value: store,
        child: const TaskerApp(),
      ),
    );
    await tester.pump();
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      if (find.byType(CircularProgressIndicator).evaluate().isEmpty) {
        break;
      }
    }

    expect(find.text('Usuário'), findsOneWidget);
    expect(find.text('Nenhuma tarefa para hoje.'), findsOneWidget);

    await tester.tap(find.byTooltip('Meu perfil'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Meu perfil'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);

    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Nenhuma tarefa para hoje.'), findsOneWidget);
  });
}
