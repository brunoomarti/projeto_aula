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

    test('cortar meu cabelo hoje ao meio dia', () {
      final r = extractWhenPTBR('cortar meu cabelo hoje ao meio dia', now);

      expect(r.title.toLowerCase(), contains('cabelo'));
      expect(r.title.toLowerCase(), isNot(contains('meio')));
      expect(r.title.toLowerCase(), isNot(contains(' ao')));
      expect(r.dateYmd, ymd(now));
      expect(r.timeHHMM, '12:00');
    });
  });
}
