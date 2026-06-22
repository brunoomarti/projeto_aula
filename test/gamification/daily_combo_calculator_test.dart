import 'package:flutter_test/flutter_test.dart';

import 'package:tasker_project/features/gamification/domain/daily_combo_calculator.dart';

void main() {
  final today = DateTime(2026, 6, 21);

  group('DailyComboCalculator.dayStatus', () {
    test('dia vazio', () {
      expect(
        DailyComboCalculator.dayStatus(total: 0, completed: 0, isToday: true),
        DailyComboDayStatus.empty,
      );
    });

    test('dia concluído', () {
      expect(
        DailyComboCalculator.dayStatus(total: 3, completed: 3, isToday: false),
        DailyComboDayStatus.cleared,
      );
    });

    test('hoje em progresso', () {
      expect(
        DailyComboCalculator.dayStatus(total: 2, completed: 1, isToday: true),
        DailyComboDayStatus.inProgress,
      );
    });

    test('dia passado com pendências falha', () {
      expect(
        DailyComboCalculator.dayStatus(total: 2, completed: 0, isToday: false),
        DailyComboDayStatus.failed,
      );
    });
  });

  group('DailyComboCalculator.compute', () {
    test('sequência de dias concluídos', () {
      final stats = <DateTime, ({int total, int completed})>{
        DateTime(2026, 6, 21): (total: 2, completed: 2),
        DateTime(2026, 6, 20): (total: 1, completed: 1),
        DateTime(2026, 6, 19): (total: 3, completed: 3),
      };

      final result = DailyComboCalculator.compute(
        today: today,
        statsForDate: (d) =>
            stats[DateTime(d.year, d.month, d.day)] ?? (total: 0, completed: 0),
      );

      expect(result.streak, 3);
      expect(result.streakStartedOn, DateTime(2026, 6, 19));
      expect(result.lastClearedOn, DateTime(2026, 6, 21));
    });

    test('quebra ao encontrar dia falho', () {
      final stats = <DateTime, ({int total, int completed})>{
        DateTime(2026, 6, 21): (total: 1, completed: 1),
        DateTime(2026, 6, 20): (total: 2, completed: 0),
      };

      final result = DailyComboCalculator.compute(
        today: today,
        statsForDate: (d) =>
            stats[DateTime(d.year, d.month, d.day)] ?? (total: 0, completed: 0),
      );

      expect(result.streak, 1);
      expect(result.lastClearedOn, DateTime(2026, 6, 21));
    });

    test('hoje em progresso não quebra sequência anterior', () {
      final stats = <DateTime, ({int total, int completed})>{
        DateTime(2026, 6, 21): (total: 2, completed: 1),
        DateTime(2026, 6, 20): (total: 1, completed: 1),
      };

      final result = DailyComboCalculator.compute(
        today: today,
        statsForDate: (d) =>
            stats[DateTime(d.year, d.month, d.day)] ?? (total: 0, completed: 0),
      );

      expect(result.streak, 1);
    });
  });

  group('DailyComboCalculator.findFirstFailedDay', () {
    test('encontra primeiro dia com falha', () {
      final stats = <DateTime, ({int total, int completed})>{
        DateTime(2026, 6, 18): (total: 1, completed: 1),
        DateTime(2026, 6, 19): (total: 1, completed: 0),
        DateTime(2026, 6, 20): (total: 1, completed: 1),
      };

      final failed = DailyComboCalculator.findFirstFailedDay(
        today: today,
        from: DateTime(2026, 6, 18),
        statsForDate: (d) =>
            stats[DateTime(d.year, d.month, d.day)] ?? (total: 0, completed: 0),
      );

      expect(failed, DateTime(2026, 6, 19));
    });

    test('retorna null sem data inicial', () {
      expect(
        DailyComboCalculator.findFirstFailedDay(
          today: today,
          from: null,
          statsForDate: (_) => (total: 0, completed: 0),
        ),
        isNull,
      );
    });
  });
}
