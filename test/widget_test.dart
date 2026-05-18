import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:projeto_aula/main.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await initializeDateFormatting('pt_BR');
  });

  testWidgets('App inicia na home com dock', (tester) async {
    await tester.pumpWidget(const TaskerApp());
    await tester.pump();
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      if (find.byType(CircularProgressIndicator).evaluate().isEmpty) {
        break;
      }
    }

    expect(find.text('Usuário'), findsOneWidget);
    expect(find.text('Nenhuma tarefa para hoje.'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.dashboard_outlined));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Tarefas concluídas'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.person_outline));
    await tester.pump();

    expect(find.text('Perfil'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.home_outlined));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Nenhuma tarefa para hoje.'), findsOneWidget);
  });
}
