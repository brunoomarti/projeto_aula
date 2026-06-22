import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tasker_project/core/layout/tasker_breakpoints.dart';

void main() {
  group('TaskerBreakpoints', () {
    test('isCompact e isWide', () {
      expect(TaskerBreakpoints.isCompact(400), isTrue);
      expect(TaskerBreakpoints.isWide(1000), isTrue);
      expect(TaskerBreakpoints.isCompact(800), isFalse);
    });

    test('contentMaxWidth', () {
      expect(TaskerBreakpoints.contentMaxWidth(400), TaskerBreakpoints.formMaxWidth);
      expect(
        TaskerBreakpoints.contentMaxWidth(1200),
        TaskerBreakpoints.formWideMaxWidth,
      );
    });

    test('mapHeight escala com largura', () {
      expect(TaskerBreakpoints.mapHeight(400), 200);
      expect(TaskerBreakpoints.mapHeight(700), 280);
      expect(TaskerBreakpoints.mapHeight(1000), 360);
    });

    test('horizontalInset centraliza em telas largas', () {
      final inset = TaskerBreakpoints.horizontalInset(1200);
      expect(inset, greaterThan(0));
    });
  });

  testWidgets('TaskerResponsiveContent limita largura', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 1200,
            child: TaskerResponsiveContent(
              width: 1200,
              child: const Text('Conteúdo'),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Conteúdo'), findsOneWidget);
    final box = tester.renderObject<RenderBox>(find.text('Conteúdo'));
    expect(box.size.width, lessThanOrEqualTo(TaskerBreakpoints.formWideMaxWidth));
  });
}
