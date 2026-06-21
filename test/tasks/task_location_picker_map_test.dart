import 'package:flutter_test/flutter_test.dart';

import 'package:tasker_project/features/tasks/domain/task.dart';
import 'package:tasker_project/features/tasks/presentation/widgets/task_location_picker_map.dart';

void main() {
  group('TaskLocationPickerMap.resolveSelectedLocation', () {
    const placeFromSearch = TaskLocation(
      lat: -19.5,
      lng: -40.6,
      name: 'Extra Bom',
      formattedAddress: 'Colatina, ES',
      placeId: 'place-1',
    );

    test('retorna busca Places quando mapa ainda não tem centro', () {
      final location = TaskLocationPickerMapState.resolveSelectedLocation(
        placeCacheFromSearch: placeFromSearch,
        mapCenter: null,
        selectedPlaceName: 'Extra Bom',
      );

      expect(location, placeFromSearch);
    });

    test('retorna centro do mapa quando não há busca', () {
      const mapCenter = TaskLocation(lat: -23.5, lng: -46.6);

      final location = TaskLocationPickerMapState.resolveSelectedLocation(
        placeCacheFromSearch: null,
        mapCenter: mapCenter,
        selectedPlaceName: null,
      );

      expect(location, mapCenter);
    });

    test('prioriza pin quando usuário moveu o mapa longe da busca', () {
      const mapCenter = TaskLocation(lat: -23.5, lng: -46.6);

      final location = TaskLocationPickerMapState.resolveSelectedLocation(
        placeCacheFromSearch: placeFromSearch,
        mapCenter: mapCenter,
        selectedPlaceName: 'Outro lugar',
      );

      expect(location?.lat, -23.5);
      expect(location?.name, 'Outro lugar');
      expect(location?.formattedAddress, isNull);
    });
  });
}
