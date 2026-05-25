import 'package:flutter_test/flutter_test.dart';
import 'package:tasker_project/features/tasks/domain/address_suggestion.dart';
import 'package:tasker_project/features/tasks/domain/task.dart';

void main() {
  group('AddressSuggestion.fromGooglePlace', () {
    test('preserva nome do estabelecimento na TaskLocation', () {
      final suggestion = AddressSuggestion.fromGooglePlace({
        'displayName': {'text': 'Extra Bom'},
        'formattedAddress': 'Av. Jerônimo Monteiro, 1000 - Colatina, ES',
        'location': {'latitude': -19.5, 'longitude': -40.6},
        'types': ['supermarket', 'store'],
        'primaryType': 'supermarket',
      });

      expect(suggestion.establishmentName, 'Extra Bom');
      expect(suggestion.location.name, 'Extra Bom');
      expect(suggestion.toTaskLocation().name, 'Extra Bom');
    });

    test('não define nome para endereço de rua', () {
      final suggestion = AddressSuggestion.fromGooglePlace({
        'displayName': {'text': 'Rua das Flores'},
        'formattedAddress': 'Rua das Flores, 123 - Colatina, ES',
        'location': {'latitude': -19.5, 'longitude': -40.6},
        'types': ['street_address'],
        'primaryType': 'street_address',
      });

      expect(suggestion.establishmentName, isNull);
      expect(suggestion.location.name, isNull);
    });
  });

  group('AddressSuggestion.fromGoogleAutocomplete', () {
    test('toTaskLocation usa shortLabel como nome de estabelecimento', () {
      const suggestion = AddressSuggestion(
        displayName: 'Extra Bom, Av. Jerônimo Monteiro - Colatina',
        shortLabel: 'Extra Bom',
        location: TaskLocation(lat: 0, lng: 0),
        categoryLabel: 'Supermercado',
        placeId: 'abc123',
      );

      expect(suggestion.establishmentName, 'Extra Bom');
      expect(suggestion.toTaskLocation().name, 'Extra Bom');
    });
  });
}
