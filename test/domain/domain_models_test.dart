import 'package:flutter_test/flutter_test.dart';

import 'package:tasker_project/features/gamification/domain/daily_combo_dates.dart';
import 'package:tasker_project/features/tasks/domain/pilha.dart';

void main() {
  group('DailyComboDates', () {
    test('formatYmd e parseYmd', () {
      final date = DateTime(2026, 6, 5);
      final ymd = DailyComboDates.formatYmd(date);
      expect(ymd, '2026-06-05');
      expect(DailyComboDates.parseYmd(ymd), date);
    });

    test('parseYmd inválido retorna null', () {
      expect(DailyComboDates.parseYmd(''), isNull);
      expect(DailyComboDates.parseYmd('invalid'), isNull);
    });

    test('dateOnly remove hora', () {
      final d = DateTime(2026, 6, 5, 14, 30);
      expect(DailyComboDates.dateOnly(d), DateTime(2026, 6, 5));
    });
  });

  group('Pilha', () {
    test('serialização JSON', () {
      final pilha = Pilha(
        id: 'p1',
        name: 'Estudos',
        createdAt: DateTime(2026, 6, 21),
      );

      final restored = Pilha.fromJson(pilha.toJson());

      expect(restored.id, 'p1');
      expect(restored.name, 'Estudos');
      expect(restored.createdAt, pilha.createdAt);
    });
  });
}
