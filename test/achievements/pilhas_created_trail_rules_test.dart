import 'package:flutter_test/flutter_test.dart';

import 'package:tasker_project/features/achievements/domain/achievement_trail_id.dart';
import 'package:tasker_project/features/achievements/domain/rules/pilhas_created_trail_rules.dart';
import 'package:tasker_project/features/tasks/domain/pilha.dart';

void main() {
  group('PilhasCreatedTrailRules', () {
    test('gera evento por pilha criada', () {
      final pilha = Pilha(
        id: 'p1',
        name: 'Estudos',
        createdAt: DateTime(2026, 6, 18),
      );
      final event = PilhasCreatedTrailRules.eventForNewPilha(pilha);
      expect(event.trail, AchievementTrailId.pilhasCreated);
      expect(event.eventKey, 'pilhas_created:pilha:p1');
    });
  });
}
