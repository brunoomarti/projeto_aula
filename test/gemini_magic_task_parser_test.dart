import 'package:flutter_test/flutter_test.dart';
import 'package:tasker_project/core/nlp/extract_when_pt_br.dart';
import 'package:tasker_project/core/nlp/gemini_magic_task_parser.dart';

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
  });
}
