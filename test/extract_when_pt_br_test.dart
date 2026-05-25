import 'package:flutter_test/flutter_test.dart';
import 'package:tasker_project/core/nlp/extract_when_pt_br.dart';

void main() {
  /// Domingo, 24/05/2026 — referência fixa para datas relativas.
  final now = DateTime(2026, 5, 24, 12, 0);

  String ymd(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  group('extractWhenPTBR', () {
    test('Levar meu pet ao veterinário amanhã', () {
      final r = extractWhenPTBR('Levar meu pet ao veterinário amanhã', now);

      expect(r.title.toLowerCase(), contains('pet'));
      expect(r.dateYmd, ymd(now.add(const Duration(days: 1))));
      expect(r.timeHHMM, isNull);
    });

    test('Reunião com Ana quinta às 14h', () {
      final r = extractWhenPTBR('Reunião com Ana quinta às 14h', now);

      expect(r.title.toLowerCase(), contains('reuni'));
      expect(r.timeHHMM, '14:00');
      expect(r.dateYmd, isNotNull);
    });

    test('Ir à academia às 07:30', () {
      final r = extractWhenPTBR('Ir à academia às 07:30', now);

      expect(r.timeHHMM, '07:30');
    });

    test('Enviar relatório hoje às 18h', () {
      final r = extractWhenPTBR('Enviar relatório hoje às 18h', now);

      expect(r.dateYmd, ymd(now));
      expect(r.timeHHMM, '18:00');
    });

    test('Marcar dentista para terça de manhã', () {
      final r = extractWhenPTBR('Marcar dentista para terça de manhã', now);

      expect(r.timeHHMM, '09:00');
      expect(r.dateYmd, isNotNull);
      expect(r.title.toLowerCase(), contains('dentista'));
    });

    test('dentista 2 e meia da tarde', () {
      final r = extractWhenPTBR('dentista 2 e meia da tarde', now);

      expect(r.timeHHMM, '14:30');
      expect(r.title.toLowerCase(), 'dentista');
    });

    test('dentista duas e meia da tarde', () {
      final r = extractWhenPTBR('dentista duas e meia da tarde', now);

      expect(r.timeHHMM, '14:30');
      expect(r.title.toLowerCase(), 'dentista');
    });

    test('remedio 10 e trinta', () {
      final r = extractWhenPTBR('remedio 10 e trinta', now);

      expect(r.timeHHMM, '10:30');
      expect(r.title.toLowerCase(), 'remedio');
    });

    test('ligar para o pedro cinco e meia', () {
      final r = extractWhenPTBR('ligar para o pedro cinco e meia', now);

      expect(r.timeHHMM, '05:30');
      expect(r.title.toLowerCase(), 'ligar o pedro');
    });

    test('dentista 15 pras 6', () {
      final r = extractWhenPTBR('dentista 15 pras 6', now);

      expect(r.timeHHMM, '05:45');
      expect(r.title.toLowerCase(), 'dentista');
    });

    test('reuniao 6 menos 15 da tarde', () {
      final r = extractWhenPTBR('reuniao 6 menos 15 da tarde', now);

      expect(r.timeHHMM, '17:45');
      expect(r.title.toLowerCase(), 'reuniao');
    });

    test('cortar meu cabelo hoje ao meio dia', () {
      final r = extractWhenPTBR('cortar meu cabelo hoje ao meio dia', now);

      expect(r.title.toLowerCase(), contains('cabelo'));
      expect(r.title.toLowerCase(), isNot(contains('meio')));
      expect(r.title.toLowerCase(), isNot(contains(' ao')));
      expect(r.dateYmd, ymd(now));
      expect(r.timeHHMM, '12:00');
    });

    test('reuniao dia 29 na sapion nova educacao', () {
      final r = extractWhenPTBR('reuniao dia 29 na sapion nova educacao', now);

      expect(r.dateYmd, '2026-05-29');
      expect(r.timeHHMM, isNull);
      expect(r.title.toLowerCase(), contains('reuni'));
      expect(r.title.toLowerCase(), isNot(contains('dia')));
      expect(r.title.toLowerCase(), isNot(contains('29')));
    });

    test('consulta no dia 15', () {
      final r = extractWhenPTBR('consulta no dia 15', now);

      // Referência 24/05 → dia 15 já passou no mês → junho.
      expect(r.dateYmd, '2026-06-15');
      expect(r.title.toLowerCase(), contains('consulta'));
      expect(r.title.toLowerCase(), isNot(contains('dia')));
    });

    test('dia 20 apos referencia usa proximo mes', () {
      final r = extractWhenPTBR('dentista dia 20', now);

      expect(r.dateYmd, '2026-06-20');
    });

    test('dia 29 as 14h mantem hora e data', () {
      final r = extractWhenPTBR('reuniao dia 29 as 14h', now);

      expect(r.dateYmd, '2026-05-29');
      expect(r.timeHHMM, '14:00');
    });
  });

  group('resolveDayOfMonth', () {
    final ref = DateTime(2026, 5, 24);

    test('mesmo mes futuro', () {
      expect(resolveDayOfMonth(29, ref), DateTime(2026, 5, 29));
    });

    test('proximo mes quando dia ja passou', () {
      expect(resolveDayOfMonth(20, ref), DateTime(2026, 6, 20));
    });
  });
}
