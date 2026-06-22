import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:tasker_project/features/home/presentation/widgets/animated_task_list.dart';
import 'package:tasker_project/features/home/presentation/widgets/user_dock.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('pt_BR');
  });

  group('homeGreetingFirstName', () {
    test('extrai primeiro nome', () {
      expect(homeGreetingFirstName('bruno martins'), 'Bruno');
    });

    test('fallback para usuário vazio', () {
      expect(homeGreetingFirstName(''), 'Usuário');
    });
  });

  testWidgets('UserDock exibe streak do combo', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: UserDock(
            displayName: 'Ana Silva',
            selectedDate: DateTime(2026, 6, 21),
            dailyComboStreak: 5,
            onProfileTap: () {},
          ),
        ),
      ),
    );

    expect(find.textContaining('Ana'), findsOneWidget);
    expect(find.text('5'), findsOneWidget);
  });

  testWidgets('AnimatedTaskList renderiza itens', (tester) async {
    final items = ['alpha', 'beta', 'gamma'];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AnimatedTaskList<String>(
            items: items,
            itemId: (item) => item,
            itemBuilder: (context, item) => SizedBox(
              height: 80,
              child: Text(item),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('alpha'), findsOneWidget);
    expect(find.text('beta'), findsOneWidget);
    expect(find.text('gamma'), findsOneWidget);
  });

  testWidgets('AnimatedTaskList reordena com animação', (tester) async {
    var items = ['a', 'b'];

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            return Scaffold(
              body: Column(
                children: [
                  ElevatedButton(
                    onPressed: () => setState(() => items = ['b', 'a']),
                    child: const Text('Reordenar'),
                  ),
                  Expanded(
                    child: AnimatedTaskList<String>(
                      items: items,
                      itemId: (item) => item,
                      itemBuilder: (context, item) => SizedBox(
                        height: 60,
                        child: Text(item),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Reordenar'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('a'), findsOneWidget);
    expect(find.text('b'), findsOneWidget);
  });
}
