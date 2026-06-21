import 'package:flutter_test/flutter_test.dart';
import 'package:tasker_nlp/tasker_nlp.dart';
import 'package:tasker_project/core/nlp/resolve_place_location.dart';
import 'package:tasker_project/features/tasks/domain/address_suggestion.dart';
import 'package:tasker_project/features/tasks/domain/task.dart';

void main() {
  group('pickBestPlaceSuggestion', () {
    final nearColatina = TaskLocation(lat: -19.539, lng: -40.630);

    AddressSuggestion ifesColatina() => AddressSuggestion(
          displayName: 'IFES Campus Colatina, Colatina, ES',
          shortLabel: 'IFES · Colatina',
          location: TaskLocation(lat: -19.5392, lng: -40.6308),
          categoryLabel: 'Universidade',
        );

    AddressSuggestion ifesItapina() => AddressSuggestion(
          displayName: 'IFES Campus Itapina, Colatina, ES',
          shortLabel: 'IFES · Itapina',
          location: TaskLocation(lat: -20.385, lng: -40.308),
          categoryLabel: 'Universidade',
        );

    test('sem campus escolhe o mais próximo', () {
      final place = ExtractPlaceResult(
        searchQuery: 'IFES',
        matchedText: 'no IFES',
      );
      final best = pickBestPlaceSuggestion(
        [ifesItapina(), ifesColatina()],
        place,
        nearColatina,
      );
      expect(best?.shortLabel, contains('Colatina'));
    });

    test('campus explícito prioriza qualificador', () {
      final place = ExtractPlaceResult(
        searchQuery: 'IFES Itapina',
        matchedText: 'no IFES campus Itapina',
        qualifiers: ['itapina'],
      );
      final best = pickBestPlaceSuggestion(
        [ifesColatina(), ifesItapina()],
        place,
        nearColatina,
      );
      expect(best?.shortLabel.toLowerCase(), contains('itapina'));
    });

    test('busca nearby usa restrição primeiro quando ha nearby', () {
      final place = ExtractPlaceResult(
        searchQuery: 'Detran',
        matchedText: 'no detran',
      );
      expect(
        preferredNearbySearchStepsForPlace(place, near: nearColatina),
        [
          (radiusMeters: 15000.0, restrictToNear: true),
          (radiusMeters: 50000.0, restrictToNear: true),
          (radiusMeters: 50000.0, restrictToNear: false),
        ],
      );
    });

    test('geocodeQueriesForPlace inclui variação junta de marca', () {
      final place = ExtractPlaceResult(
        searchQuery: 'Extra Bom',
        matchedText: 'no extra bom',
      );
      final queries = geocodeQueriesForPlace(place);
      expect(queries, contains('ExtraBom'));
    });

    test('textMatchesPlace reconhece extra bom e extrabom', () {
      final place = ExtractPlaceResult(
        searchQuery: 'Extra Bom',
        matchedText: 'no extra bom',
      );
      final suggestion = AddressSuggestion(
        displayName: 'Extrabom Colatina, Colatina, ES',
        shortLabel: 'Extrabom Colatina',
        location: nearColatina,
        categoryLabel: 'Supermercado',
      );
      expect(textMatchesPlace(suggestion, place), isTrue);
    });
  });

  group('TaskLocation helpers', () {
    test('formatAddressLine combina nome e endereço', () {
      const loc = TaskLocation(
        lat: -20.0,
        lng: -40.0,
        name: 'Ama Hospital Veterinário',
      );
      expect(
        TaskLocation.formatAddressLine(
          location: loc,
          streetAddress: 'Rua das Flores, 100',
        ),
        'Ama Hospital Veterinário · Rua das Flores, 100',
      );
    });
  });
}
