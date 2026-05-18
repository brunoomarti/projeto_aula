import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../../features/tasks/domain/task.dart';

/// Equivalente a [tasker-main/src/utils/native.js] `getUserLocation`.
/// Nunca lança: falha de GPS/permissão retorna `null` (a tarefa ainda é salva).
class LocationService {
  const LocationService._();

  static const _timeout = Duration(seconds: 6);

  static Future<TaskLocation?> getCurrentLocation() async {
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) return null;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return null;
      }
      if (permission == LocationPermission.deniedForever) {
        return null;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: _timeout,
        ),
      ).timeout(_timeout);

      final lat = position.latitude;
      final lng = position.longitude;
      if (!lat.isFinite || !lng.isFinite) return null;

      return TaskLocation(lat: lat, lng: lng);
    } catch (e, st) {
      debugPrint('LocationService.getCurrentLocation: $e\n$st');
      return null;
    }
  }
}
