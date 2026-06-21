import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tasker_nlp/tasker_nlp.dart';

void main() {
  group('GeminiMagicTaskParser.parseTaskFromText — REST', () {
    final ref = DateTime(2026, 5, 24);

    test('consome POST generateContent e interpreta JSON', () async {
      final client = MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.host, 'generativelanguage.googleapis.com');
        expect(request.url.path, contains('generateContent'));
        expect(request.url.queryParameters['key'], 'gemini-test-key');

        final body = jsonDecode(request.body) as Map<String, dynamic>;
        final prompt =
            (body['contents'] as List).first['parts'].first['text'] as String;
        expect(prompt, contains('reunião na sapion amanhã'));

        return http.Response(
          jsonEncode({
            'candidates': [
              {
                'content': {
                  'parts': [
                    {
                      'text': jsonEncode({
                        'title': 'Reunião',
                        'dateYmd': '2026-05-25',
                        'timeHHMM': '14:00',
                        'placeSearchQuery': 'Sapion',
                        'placeSkipGeocoding': false,
                        'errandItems': [],
                        'iconKey': 'work',
                      }),
                    },
                  ],
                },
              },
            ],
          }),
          200,
        );
      });

      final result = await GeminiMagicTaskParser.parseTaskFromText(
        transcript: 'reunião na sapion amanhã 14h',
        referenceDate: ref,
        apiKey: 'gemini-test-key',
        httpClient: client,
      );

      expect(result.title.toLowerCase(), contains('reuni'));
      expect(result.dateYmd, '2026-05-25');
      expect(result.placeSearchQuery, 'Sapion');
    });

    test('falha com chave vazia', () async {
      expect(
        () => GeminiMagicTaskParser.parseTaskFromText(
          transcript: 'comprar leite',
          referenceDate: ref,
          apiKey: '  ',
        ),
        throwsA(isA<GeminiMagicTaskParserException>()),
      );
    });

    test('falha quando API retorna HTTP de erro', () async {
      final client = MockClient((request) async {
        return http.Response('API key invalid', 403);
      });

      expect(
        () => GeminiMagicTaskParser.parseTaskFromText(
          transcript: 'comprar leite',
          referenceDate: ref,
          apiKey: 'gemini-test-key',
          httpClient: client,
        ),
        throwsA(
          isA<GeminiMagicTaskParserException>().having(
            (e) => e.message,
            'message',
            contains('Gemini HTTP 403'),
          ),
        ),
      );
    });
  });
}
