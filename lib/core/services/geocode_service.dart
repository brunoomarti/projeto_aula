import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../features/tasks/domain/address_suggestion.dart';
import '../../features/tasks/domain/task.dart';

/// Geocodificação via OSM (Nominatim + Photon) — endereços e estabelecimentos.
/// Equivalente a [tasker-main/src/utils/geocode.js].
class GeocodeService {
  GeocodeService._();

  static const _userAgent = 'tasker-flutter/1.0 (projeto-aula)';
  static const _minSearchInterval = Duration(milliseconds: 1100);
  static const _maxSuggestions = 8;

  static final Map<String, String?> _cache = {};
  static DateTime? _lastSearchRequest;

  static Future<String?> getAddressCached(TaskLocation location) async {
    final key =
        '${location.lat.toStringAsFixed(6)},${location.lng.toStringAsFixed(6)}';

    if (_cache.containsKey(key)) {
      return _cache[key];
    }

    final address = await _reverseGeocode(
      lat: location.lat,
      lng: location.lng,
    );
    _cache[key] = address;
    return address;
  }

  /// Autocomplete: endereços (Nominatim) + lojas/restaurantes/etc. (Photon).
  static Future<List<AddressSuggestion>> searchAddresses(
    String query, {
    TaskLocation? near,
  }) async {
    final q = query.trim();
    if (q.length < 3) return [];

    await _throttleSearch();

    final results = await Future.wait([
      _searchNominatim(q),
      _searchPhoton(q, near: near),
    ]);

    // Photon primeiro: lojas e serviços; Nominatim complementa endereços.
    return _mergeSuggestions([...results[1], ...results[0]]);
  }

  static List<AddressSuggestion> _mergeSuggestions(
    List<AddressSuggestion> items,
  ) {
    final seen = <String>{};
    final merged = <AddressSuggestion>[];

    for (final item in items) {
      if (item.displayName.isEmpty && item.shortLabel.isEmpty) continue;

      final key =
          '${item.location.lat.toStringAsFixed(4)}|${item.location.lng.toStringAsFixed(4)}|${item.shortLabel.toLowerCase()}';
      if (!seen.add(key)) continue;

      merged.add(item);
      if (merged.length >= _maxSuggestions) break;
    }

    return merged;
  }

  static Future<List<AddressSuggestion>> _searchNominatim(String q) async {
    final uri = Uri.https(
      'nominatim.openstreetmap.org',
      '/search',
      {
        'q': q,
        'format': 'json',
        'limit': '5',
        'addressdetails': '1',
        'countrycodes': 'br',
        'accept-language': 'pt-BR',
      },
    );

    try {
      final response = await http
          .get(
            uri,
            headers: const {
              'Accept': 'application/json',
              'User-Agent': _userAgent,
            },
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        debugPrint('GeocodeService Nominatim: HTTP ${response.statusCode}');
        return [];
      }

      final data = jsonDecode(response.body);
      if (data is! List) return [];

      return data
          .whereType<Map>()
          .map((e) => AddressSuggestion.fromNominatim(
                Map<String, dynamic>.from(e),
              ))
          .where((s) => s.displayName.isNotEmpty)
          .toList();
    } catch (e, st) {
      debugPrint('GeocodeService._searchNominatim: $e\n$st');
      return [];
    }
  }

  /// Photon (Komoot) — forte em POIs: lojas, restaurantes, serviços.
  static Future<List<AddressSuggestion>> _searchPhoton(
    String q, {
    TaskLocation? near,
  }) async {
    final params = <String, String>{
      'q': q,
      'limit': '8',
      'lang': 'pt',
    };
    if (near != null) {
      params['lat'] = near.lat.toString();
      params['lon'] = near.lng.toString();
    }

    final uri = Uri.https('photon.komoot.io', '/api/', params);

    try {
      final response = await http
          .get(
            uri,
            headers: const {'Accept': 'application/json'},
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        debugPrint('GeocodeService Photon: HTTP ${response.statusCode}');
        return [];
      }

      final data = jsonDecode(response.body);
      if (data is! Map<String, dynamic>) return [];

      final features = data['features'];
      if (features is! List) return [];

      final out = <AddressSuggestion>[];
      for (final raw in features) {
        if (raw is! Map) continue;
        final feature = Map<String, dynamic>.from(raw);
        final props = feature['properties'];
        final geometry = feature['geometry'];
        if (props is! Map || geometry is! Map) continue;

        final propsMap = Map<String, dynamic>.from(props);
        final countryCode =
            (propsMap['countrycode'] as String?)?.toUpperCase();
        if (countryCode != null && countryCode != 'BR') continue;

        final coords = geometry['coordinates'];
        if (coords is! List || coords.length < 2) continue;

        final suggestion = AddressSuggestion.fromPhoton(propsMap, coords);
        if (suggestion.displayName.isNotEmpty ||
            suggestion.shortLabel.isNotEmpty) {
          out.add(suggestion);
        }
      }
      return out;
    } catch (e, st) {
      debugPrint('GeocodeService._searchPhoton: $e\n$st');
      return [];
    }
  }

  static Future<void> _throttleSearch() async {
    final last = _lastSearchRequest;
    if (last != null) {
      final elapsed = DateTime.now().difference(last);
      if (elapsed < _minSearchInterval) {
        await Future.delayed(_minSearchInterval - elapsed);
      }
    }
    _lastSearchRequest = DateTime.now();
  }

  static Future<String?> _reverseGeocode({
    required double lat,
    required double lng,
  }) async {
    final uri = Uri.https(
      'nominatim.openstreetmap.org',
      '/reverse',
      {
        'format': 'jsonv2',
        'lat': lat.toString(),
        'lon': lng.toString(),
        'accept-language': 'pt-BR',
      },
    );

    try {
      final response = await http
          .get(
            uri,
            headers: const {
              'Accept': 'application/json',
              'User-Agent': _userAgent,
            },
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        debugPrint('GeocodeService: HTTP ${response.statusCode}');
        return null;
      }

      final data = jsonDecode(response.body);
      if (data is! Map<String, dynamic>) return null;

      return data['display_name'] as String?;
    } catch (e, st) {
      debugPrint('GeocodeService._reverseGeocode: $e\n$st');
      return null;
    }
  }
}
