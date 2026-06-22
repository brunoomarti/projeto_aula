import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tasker_project/features/achievements/domain/rules/achievement_day_utils.dart';
import 'package:tasker_project/features/tasks/presentation/widgets/task_errand_list_fields.dart';

void main() {
  group('AchievementDayUtils', () {
    test('dateOnly remove hora', () {
      final d = DateTime(2026, 6, 5, 15);
      expect(AchievementDayUtils.dateOnly(d), DateTime(2026, 6, 5));
    });

    test('daysBetween percorre até o dia anterior ao fim', () {
      final start = DateTime(2026, 6, 1);
      final end = DateTime(2026, 6, 3);
      final days = AchievementDayUtils.daysBetween(start: start, end: end).toList();
      expect(days, hasLength(2));
      expect(days.first, DateTime(2026, 6, 1));
    });
  });

  testWidgets('TaskErrandListFields lista itens numerados', (tester) async {
    final controllers = [
      TextEditingController(text: 'Arroz'),
      TextEditingController(text: 'Feijão'),
    ];
    addTearDown(() {
      for (final c in controllers) {
        c.dispose();
      }
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TaskErrandListFields(
            controllers: controllers,
            onAdd: () {},
            onRemove: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('1.'), findsOneWidget);
    expect(find.text('2.'), findsOneWidget);
    expect(find.text('Arroz'), findsOneWidget);
  });
}
