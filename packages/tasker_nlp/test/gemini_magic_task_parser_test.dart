import 'package:test/test.dart';
import 'package:tasker_nlp/tasker_nlp.dart';

void main() {
  /// Domingo, 24/05/2026.
  final ref = DateTime(2026, 5, 24);

  group('GeminiMagicTaskParser.decodeGeminiTaskJson', () {
    test('parseia JSON puro', () {
      final map = GeminiMagicTaskParser.decodeGeminiTaskJson('''
{"title":"Reunião","dateYmd":"2026-05-29","timeHHMM":null,"placeSearchQuery":"Sapion Nova Educação","placeSkipGeocoding":false,"errandItems":[],"iconKey":"work"}
''');

      expect(map['title'], 'Reunião');
      expect(map['dateYmd'], '2026-05-29');
    });

    test('remove cercas markdown', () {
      final map = GeminiMagicTaskParser.decodeGeminiTaskJson('''
```json
{"title":"Compras","dateYmd":null,"timeHHMM":null,"placeSearchQuery":null,"placeSkipGeocoding":false,"errandItems":["leite"],"iconKey":"market"}
```
''');

      expect(map['title'], 'Compras');
      expect(map['errandItems'], ['leite']);
    });
  });

  group('inferColloquialTimePtBr', () {
    test('duas da tarde', () {
      expect(
        GeminiMagicTaskParser.inferColloquialTimePtBr(
          'reuniao de negocios na sapion amanha duas da tarde',
        ),
        '14:00',
      );
    });

    test('tres da tarde', () {
      expect(
        GeminiMagicTaskParser.inferColloquialTimePtBr('consulta tres da tarde'),
        '15:00',
      );
    });

    test('frase completa com acentos', () {
      expect(
        GeminiMagicTaskParser.inferColloquialTimePtBr(
          'reunião de negócios na sapion amanhã duas da tarde',
        ),
        '14:00',
      );
    });

    test('as duas da tarde', () {
      expect(
        GeminiMagicTaskParser.inferColloquialTimePtBr(
          'reuniao as duas da tarde',
        ),
        '14:00',
      );
    });

    test('2 e meia da tarde', () {
      expect(
        GeminiMagicTaskParser.inferColloquialTimePtBr(
          'dentista 2 e meia da tarde',
        ),
        '14:30',
      );
    });

    test('10 e trinta', () {
      expect(
        GeminiMagicTaskParser.inferColloquialTimePtBr('remedio 10 e trinta'),
        '10:30',
      );
    });

    test('15 pras 6', () {
      expect(
        GeminiMagicTaskParser.inferColloquialTimePtBr('dentista 15 pras 6'),
        '05:45',
      );
    });
  });

  group('refineWithLocalSignals', () {
    test('corrige titulo e hora quando gemini veio contaminado', () {
      final gemini = const GeminiMagicTaskParseResult(
        title: 'Reuniao de negocios duas',
        dateYmd: '2026-05-25',
        timeHHMM: '15:00',
        placeSearchQuery: 'Sapion',
      );

      final refined = GeminiMagicTaskParser.refineWithLocalSignals(
        gemini: gemini,
        transcript: 'reuniao de negocios na sapion amanha duas da tarde',
        referenceDate: ref,
      );

      expect(refined.timeHHMM, '14:00');
      expect(refined.dateYmd, '2026-05-25');
      expect(refined.placeSearchQuery, 'Sapion');
      expect(refined.title.toLowerCase(), isNot(contains('duas')));
      expect(refined.title.toLowerCase(), contains('reuni'));
    });

    test('corrige horario numerico coloquial e limpa titulo', () {
      final gemini = const GeminiMagicTaskParseResult(
        title: 'Dentista 2 e meia',
        timeHHMM: '15:00',
      );

      final refined = GeminiMagicTaskParser.refineWithLocalSignals(
        gemini: gemini,
        transcript: 'dentista 2 e meia da tarde',
        referenceDate: ref,
      );

      expect(refined.timeHHMM, '14:30');
      expect(refined.title, 'Dentista');
    });

    test(
      'corrige horarios brasileiros variados antes do retorno do gemini',
      () {
        final gemini = const GeminiMagicTaskParseResult(
          title: 'Dentista 15 pras 6',
          timeHHMM: '15:00',
        );

        final refined = GeminiMagicTaskParser.refineWithLocalSignals(
          gemini: gemini,
          transcript: 'dentista 15 pras 6',
          referenceDate: ref,
        );

        expect(refined.timeHHMM, '05:45');
        expect(refined.title, 'Dentista');
      },
    );

    test('prioriza lista de acoes corrigida do gemini', () {
      final gemini = const GeminiMagicTaskParseResult(
        title: 'Ir na rua',
        errandItems: [
          'Pagar uma conta no Mercadão',
          'Comprar linhaça',
          'Buscar um condicional na Musa',
        ],
      );

      final refined = GeminiMagicTaskParser.refineWithLocalSignals(
        gemini: gemini,
        transcript:
            'preciso ir na rua para pagar uma conta no mercadao, comprar linhaca, buscar um condicional na musa',
        referenceDate: ref,
      );

      expect(refined.title, 'Ir na rua');
      expect(refined.errandItems.length, 3);
      expect(refined.errandItems[0], contains('Mercad'));
      expect(refined.errandItems[1].toLowerCase(), contains('linha'));
      expect(refined.errandItems[2].toLowerCase(), contains('musa'));
    });

    test('usa lista local quando gemini omitiu acoes', () {
      final gemini = const GeminiMagicTaskParseResult(
        title: 'Ir na rua',
        errandItems: [],
      );

      final refined = GeminiMagicTaskParser.refineWithLocalSignals(
        gemini: gemini,
        transcript:
            'preciso ir na rua para pagar uma conta no mercadao, comprar linhaca, buscar um condicional na musa',
        referenceDate: ref,
      );

      expect(refined.title, 'Ir na rua');
      expect(refined.errandItems.length, greaterThanOrEqualTo(2));
    });

    test('enriquece titulo e placeDisplayName para veterinario', () {
      final gemini = const GeminiMagicTaskParseResult(
        title: 'Levar gata',
        timeHHMM: '14:00',
        placeSearchQuery: 'Ama Hospital Veterinário',
        placeDisplayName: 'Ama Hospital Veterinário',
        iconKey: 'pets',
      );

      final refined = GeminiMagicTaskParser.refineWithLocalSignals(
        gemini: gemini,
        transcript: 'levar gata no ama hospital vetrinario as 14h',
        referenceDate: ref,
      );

      expect(refined.title.toLowerCase(), contains('veterin'));
      expect(refined.placeDisplayName, isNotNull);
      expect(refined.placeDisplayName!.toLowerCase(), contains('ama'));
      expect(refined.timeHHMM, '14:00');
    });

    test('usa contexto do detran para carteira de motorista', () {
      final gemini = const GeminiMagicTaskParseResult(
        title: 'Carteira',
        placeSearchQuery: 'Detran',
        placeDisplayName: 'Detran',
        iconKey: 'task',
      );

      final refined = GeminiMagicTaskParser.refineWithLocalSignals(
        gemini: gemini,
        transcript: 'ir no detran renovar a carteira',
        referenceDate: ref,
      );

      expect(refined.title.toLowerCase(), contains('renovar'));
      expect(refined.title.toLowerCase(), contains('motorista'));
      expect(refined.placeSearchQuery, 'Detran');
    });
  });

  group('resolveErrandItemsForTest', () {
    test('prefere gemini quando completo', () {
      expect(
        GeminiMagicTaskParser.resolveErrandItemsForTest(
          geminiItems: ['mamão', 'banana'],
          localItems: ['mamao', 'banana'],
        ),
        ['mamão', 'banana'],
      );
    });
  });
}
