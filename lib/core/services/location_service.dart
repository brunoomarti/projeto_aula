import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../../features/tasks/domain/task.dart';

/// Equivalente a [tasker-main/src/utils/native.js] `getUserLocation`.
class LocationService {
  const LocationService._();

  /// Cache só após [refineLocationForMap] / [getCurrentLocation] com GPS fresco.
  static TaskLocation? _sessionCache;

  /// Pré-visualização imediata no mapa (última posição do SO, sem travar a UI).
  static Future<TaskLocation?> getQuickLocationForMap() async {
    if (!await _hasUsablePermission(requestIfDenied: true)) return null;

    try {
      final lastKnown = await Geolocator.getLastKnownPosition();
      if (lastKnown == null) return null;
      return _fromPosition(lastKnown);
    } catch (e, st) {
      debugPrint('LocationService.getQuickLocationForMap: $e\n$st');
      return null;
    }
  }

  /// Posição atual do GPS (prioridade ao abrir o mapa).
  static Future<TaskLocation?> refineLocationForMap() async {
    if (!await _hasUsablePermission(requestIfDenied: true)) return null;

    final fresh = await _fetchCurrentPositionWithRetry();
    if (fresh != null) {
      _sessionCache = fresh;
      return fresh;
    }

    try {
      final lastKnown = await Geolocator.getLastKnownPosition();
      if (lastKnown != null) {
        final cached = _fromPosition(lastKnown);
        if (cached != null) {
          debugPrint(
            'LocationService: fallback última posição ${cached.lat}, ${cached.lng}',
          );
          return cached;
        }
      }
    } catch (e, st) {
      debugPrint('LocationService.refineLocationForMap fallback: $e\n$st');
    }

    return null;
  }

  /// Obtém coordenadas ao salvar a tarefa.
  static Future<TaskLocation?> getCurrentLocation() async {
    try {
      if (!await _hasUsablePermission(requestIfDenied: true)) return null;

      final fresh = await _fetchCurrentPositionWithRetry();
      if (fresh != null) {
        _sessionCache = fresh;
        return fresh;
      }

      if (_sessionCache != null) return _sessionCache;

      return getQuickLocationForMap();
    } catch (e, st) {
      debugPrint('LocationService.getCurrentLocation: $e\n$st');
      return null;
    }
  }

  static Future<TaskLocation?> _fetchCurrentPositionWithRetry() async {
    const attempts = <({LocationAccuracy accuracy, Duration timeout})>[
      (accuracy: LocationAccuracy.medium, timeout: Duration(seconds: 8)),
      (accuracy: LocationAccuracy.high, timeout: Duration(seconds: 15)),
    ];

    for (var i = 0; i < attempts.length; i++) {
      final config = attempts[i];
      final loc = await _tryCurrentPosition(
        accuracy: config.accuracy,
        timeout: config.timeout,
      );
      if (loc != null) return loc;
      if (i < attempts.length - 1) {
        await Future<void>.delayed(const Duration(milliseconds: 500));
      }
    }
    return null;
  }

  static Future<bool> _hasUsablePermission({
    required bool requestIfDenied,
  }) async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        debugPrint('LocationService: serviço de localização desligado');
        return false;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied && requestIfDenied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        debugPrint('LocationService: permissão negada ($permission)');
        return false;
      }
      return true;
    } catch (e, st) {
      debugPrint('LocationService._hasUsablePermission: $e\n$st');
      return false;
    }
  }

  static Future<TaskLocation?> _tryCurrentPosition({
    required LocationAccuracy accuracy,
    required Duration timeout,
  }) async {
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(
          accuracy: accuracy,
          timeLimit: timeout,
        ),
      ).timeout(timeout);

      final loc = _fromPosition(position);
      if (loc != null) {
        debugPrint('LocationService: posição atual ${loc.lat}, ${loc.lng}');
      }
      return loc;
    } catch (e) {
      debugPrint('LocationService._tryCurrentPosition ($accuracy): $e');
      return null;
    }
  }

  static TaskLocation? _fromPosition(Position position) {
    final lat = position.latitude;
    final lng = position.longitude;
    if (!lat.isFinite || !lng.isFinite) return null;
    if (lat == 0 && lng == 0) return null;
    return TaskLocation(lat: lat, lng: lng);
  }
}
