import 'package:test/test.dart';
import 'package:tasker_nlp/tasker_nlp.dart';

void main() {
  group('inferPeriodTimePTBR / períodos do dia', () {
    test('início da noite → 18:00', () {
      final r = inferPeriodTimePTBR('comprar pao na digrano no inicio da noite');
      expect(r?.time, '18:00');
    });

    test('entardecer e pôr do sol → 18:00', () {
      expect(inferPeriodTimePTBR('reuniao no por do sol')?.time, '18:00');
      expect(inferPeriodTimePTBR('quando escurece')?.time, '18:00');
    });

    test('fim da tarde → 17:30', () {
      expect(inferPeriodTimePTBR('encontro no fim da tarde')?.time, '17:30');
    });

    test('meio da tarde → 15:00', () {
      expect(inferPeriodTimePTBR('almoco no meio da tarde')?.time, '15:00');
    });

    test('de noite genérico → 20:00 (não 23:59)', () {
      expect(inferPeriodTimePTBR('cinema de noite')?.time, '20:00');
    });

    test('hora do jantar → 19:00', () {
      expect(inferPeriodTimePTBR('jantar horario de jantar')?.time, '19:00');
    });

    test('fim da noite → 22:00', () {
      expect(inferPeriodTimePTBR('ligar para mae no fim da noite')?.time, '22:00');
    });
  });

  group('extractWhenPTBR + períodos', () {
    test('comprar pao na digrano no inicio da noite', () {
      final r = extractWhenPTBR('comprar pao na digrano no inicio da noite');

      expect(r.timeHHMM, '18:00');
      expect(r.title.toLowerCase(), contains('comprar'));
      expect(r.title.toLowerCase(), contains('pao'));
      expect(r.title.toLowerCase(), isNot(contains('digrano')));
      expect(r.title.toLowerCase(), isNot(contains('inicio')));
      expect(r.title.toLowerCase(), isNot(contains('noite')));
    });
  });

  group('extractPlacePTBR + nome próprio', () {
    test('na digrano para antes de período temporal', () {
      final p = extractPlacePTBR('comprar pao na digrano no inicio da noite');
      expect(p, isNotNull);
      expect(p!.searchQuery.toLowerCase(), contains('digrano'));
      expect(p.matchedText.toLowerCase(), contains('digrano'));
    });

    test('na padaria Central ao entardecer', () {
      final p = extractPlacePTBR('buscar bolo na padaria Central ao entardecer');
      expect(p, isNotNull);
      expect(p!.searchQuery.toLowerCase(), contains('padaria'));
      expect(p.searchQuery.toLowerCase(), contains('central'));
    });
  });

  group('extractCoreActionTitlePTBR', () {
    test('extrai só a ação com local nomeado', () {
      final place = extractPlacePTBR('comprar pao na digrano no inicio da noite');
      final title = extractCoreActionTitlePTBR(
        'comprar pao na digrano no inicio da noite',
        place: place,
      );
      expect(title?.toLowerCase(), contains('comprar'));
      expect(title?.toLowerCase(), contains('pao'));
      expect(title?.toLowerCase(), isNot(contains('digrano')));
    });
  });

  group('GeminiMagicTaskParser.refineWithLocalSignals', () {
    test('corrige hora e título para digrano + início da noite', () {
      const gemini = GeminiMagicTaskParseResult(
        title: 'Comprar pao na digrano no inicio',
        timeHHMM: '23:59',
        placeSearchQuery: 'Digrano',
        placeDisplayName: 'Digrano',
        iconKey: 'market',
      );

      final refined = GeminiMagicTaskParser.refineWithLocalSignals(
        gemini: gemini,
        transcript: 'comprar pao na digrano no inicio da noite',
        referenceDate: DateTime(2026, 5, 24),
      );

      expect(refined.timeHHMM, '18:00');
      expect(refined.title.toLowerCase(), contains('comprar'));
      expect(refined.title.toLowerCase(), contains('pao'));
      expect(refined.title.toLowerCase(), isNot(contains('digrano')));
      expect(refined.title.toLowerCase(), isNot(contains('inicio')));
      expect(refined.placeSearchQuery?.toLowerCase(), contains('digrano'));
    });
  });
}
