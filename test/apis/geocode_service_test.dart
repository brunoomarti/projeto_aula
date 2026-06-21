import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:tasker_project/core/services/geocode_service.dart';
import 'package:tasker_project/features/tasks/domain/task.dart';

void main() {
  setUpAll(() {
    dotenv.loadFromString(
      envString: 'GOOGLE_PLACES_API_KEY=test-places-key',
      isOptional: true,
    );
  });

  tearDown(GeocodeService.resetForTesting);

  group('GeocodeService — Google Places / Geocoding REST', () {
    test('autocompletePlaces consome POST places:autocomplete', () async {
      GeocodeService.httpClientOverride = MockClient((request) async {
        expect(request.method, 'POST');
        expect(
          request.url.host,
          anyOf('places.googleapis.com', contains('googleapis')),
        );
        expect(request.url.path, contains('autocomplete'));
        expect(request.headers['X-Goog-Api-Key'], 'test-places-key');

        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['input'], 'extra colatina');
        expect(body['languageCode'], 'pt-BR');

        return http.Response(
          jsonEncode({
            'suggestions': [
              {
                'placePrediction': {
                  'placeId': 'place-123',
                  'structuredFormat': {
                    'mainText': {'text': 'Extra Bom'},
                    'secondaryText': {'text': 'Colatina, ES'},
                  },
                  'types': ['supermarket'],
                },
              },
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final results = await GeocodeService.autocompletePlaces('extra colatina');

      expect(results, hasLength(1));
      expect(results.first.shortLabel, 'Extra Bom');
      expect(results.first.placeId, 'place-123');
    });

    test('searchAddresses consome autocomplete + GET place details', () async {
      var detailsCalls = 0;

      GeocodeService.httpClientOverride = MockClient((request) async {
        if (request.method == 'POST') {
          return http.Response(
            jsonEncode({
              'suggestions': [
                {
                  'placePrediction': {
                    'placeId': 'pid-1',
                    'structuredFormat': {
                      'mainText': {'text': 'Sapion'},
                      'secondaryText': {'text': 'Colatina'},
                    },
                    'types': ['school'],
                  },
                },
              ],
            }),
            200,
          );
        }

        expect(request.method, 'GET');
        expect(request.url.path, contains('places/pid-1'));
        detailsCalls++;

        return http.Response(
          jsonEncode({
            'id': 'places/pid-1',
            'displayName': {'text': 'Sapion Nova Educação'},
            'formattedAddress': 'Colatina, ES',
            'location': {'latitude': -19.5, 'longitude': -40.6},
            'types': ['school'],
            'primaryType': 'school',
          }),
          200,
        );
      });

      final results = await GeocodeService.searchAddresses('sapion colatina');

      expect(detailsCalls, 1);
      expect(results, hasLength(1));
      expect(results.first.establishmentName, 'Sapion Nova Educação');
      expect(results.first.location.lat, -19.5);
    });

    test('getAddressCached consome GET Geocoding reverse', () async {
      GeocodeService.httpClientOverride = MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.host, 'maps.googleapis.com');
        expect(request.url.path, '/maps/api/geocode/json');
        expect(request.url.queryParameters['latlng'], '-19.5,-40.6');
        expect(request.url.queryParameters['key'], 'test-places-key');

        return http.Response(
          jsonEncode({
            'status': 'OK',
            'results': [
              {'formatted_address': 'Colatina, ES, Brasil'},
            ],
          }),
          200,
        );
      });

      final address = await GeocodeService.getAddressCached(
        const TaskLocation(lat: -19.5, lng: -40.6),
      );

      expect(address, 'Colatina, ES, Brasil');
    });

    test('retorna vazio quando query curta ou API não configurada', () async {
      expect(await GeocodeService.autocompletePlaces('ab'), isEmpty);

      dotenv.loadFromString(envString: 'GOOGLE_PLACES_API_KEY=', isOptional: true);
      expect(await GeocodeService.autocompletePlaces('extra bom'), isEmpty);

      dotenv.loadFromString(
        envString: 'GOOGLE_PLACES_API_KEY=test-places-key',
        isOptional: true,
      );
    });

    test('HTTP de erro retorna lista/endereço vazio sem lançar', () async {
      GeocodeService.httpClientOverride = MockClient((request) async {
        return http.Response('quota exceeded', 403);
      });

      expect(await GeocodeService.autocompletePlaces('mercado central'), isEmpty);

      GeocodeService.httpClientOverride = MockClient((request) async {
        return http.Response(jsonEncode({'status': 'ZERO_RESULTS'}), 200);
      });

      final address = await GeocodeService.getAddressCached(
        const TaskLocation(lat: 0, lng: 0),
      );
      expect(address, isNull);
    });
  });
}
