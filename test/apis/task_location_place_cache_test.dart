import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
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

  test('getAddressCached usa formattedAddress persistido sem HTTP', () async {
    GeocodeService.httpClientOverride = MockClient((request) async {
      fail('Não deve chamar a API quando o endereço já está na tarefa');
    });

    const loc = TaskLocation(
      lat: -19.5,
      lng: -40.6,
      name: 'Extra Bom',
      formattedAddress: 'Av. Jerônimo Monteiro, 1000 - Colatina, ES',
      placeId: 'place-123',
    );

    final address = await GeocodeService.getAddressCached(loc);
    expect(address, 'Av. Jerônimo Monteiro, 1000 - Colatina, ES');
  });

  test('TaskLocation persiste formatted_address no JSON da tarefa', () {
    const loc = TaskLocation(
      lat: -19.5,
      lng: -40.6,
      name: 'Sapion',
      formattedAddress: 'Colatina, ES',
      placeId: 'pid-1',
    );

    final json = loc.toJson();
    expect(json['formatted_address'], 'Colatina, ES');
    expect(json['place_id'], 'pid-1');

    final restored = TaskLocation.fromJson(json);
    expect(restored, loc);
    expect(restored.hasPersistedAddress, isTrue);
  });

  test('enrichLocationIfNeeded não chama API quando endereço já existe', () async {
    GeocodeService.httpClientOverride = MockClient((request) async {
      fail('Não deve chamar a API');
    });

    const loc = TaskLocation(
      lat: -19.5,
      lng: -40.6,
      formattedAddress: 'Endereço salvo',
    );

    final enriched = await GeocodeService.enrichLocationIfNeeded(loc);
    expect(enriched.formattedAddress, 'Endereço salvo');
  });
}
