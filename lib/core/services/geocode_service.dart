import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

import '../../features/tasks/domain/address_suggestion.dart';
import '../../features/tasks/domain/task.dart';
import '../config/env_config.dart';

/// Geocodificação via Google Places (New) + Geocoding API.
/// O mapa continua usando tiles OpenStreetMap; apenas busca/endereço usam Google.
class GeocodeService {
  GeocodeService._();

  static const _uuid = Uuid();
  static const _minAutocompleteInterval = Duration(milliseconds: 280);
  static const _minSearchInterval = Duration(milliseconds: 350);
  static const _maxSuggestions = 8;
  static const _maxDetailsPerSearch = 6;

  static final Map<String, String?> _cache = {};
  static DateTime? _lastSearchRequest;
  static String _sessionToken = _uuid.v4();

  static Map<String, String> _headers({required String fieldMask}) => {
        'Content-Type': 'application/json',
        'X-Goog-Api-Key': EnvConfig.googlePlacesApiKey,
        'X-Goog-FieldMask': fieldMask,
      };

  static void _startNewSession() {
    _sessionToken = _uuid.v4();
  }

  static Future<String?> getAddressCached(TaskLocation location) async {
    if (!EnvConfig.isGoogleConfigured) return null;

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

  /// Autocomplete (Places API New) — endereços **e** estabelecimentos.
  /// Usado no campo "Buscar endereço" da criação/edição de tarefas.
  /// Coordenadas vêm em [resolveSuggestion] ao selecionar um item.
  static Future<List<AddressSuggestion>> autocompletePlaces(
    String query, {
    TaskLocation? near,
  }) async {
    if (!EnvConfig.isGoogleConfigured) return [];

    final q = query.trim();
    if (q.length < 3) return [];

    await _throttleAutocomplete();

    final predictions = await _autocomplete(
      q,
      near: near,
      includeEstablishments: true,
    );

    return predictions
        .map(
          (p) => AddressSuggestion.fromGoogleAutocomplete(
            placeId: p.placeId,
            mainText: p.mainText,
            secondaryText: p.secondaryText,
            types: p.types,
          ),
        )
        .toList();
  }

  /// Autocomplete + Place Details — usado pelo NLP de voz (precisa de coordenadas).
  static Future<List<AddressSuggestion>> searchAddresses(
    String query, {
    TaskLocation? near,
  }) async {
    if (!EnvConfig.isGoogleConfigured) return [];

    final q = query.trim();
    if (q.length < 3) return [];

    await _throttleSearch();

    final predictions = await _autocomplete(
      q,
      near: near,
      includeEstablishments: true,
    );
    if (predictions.isEmpty) return [];

    final placeIds = predictions
        .map((p) => p.placeId)
        .where((id) => id.isNotEmpty)
        .take(_maxDetailsPerSearch)
        .toList();

    final details = await Future.wait(
      placeIds.map(_fetchPlaceDetails),
    );

    final resolved = details.whereType<AddressSuggestion>().toList();
    return resolved.take(_maxSuggestions).toList();
  }

  /// Garante coordenadas ao selecionar uma sugestão (ex.: autocomplete sem details).
  static Future<AddressSuggestion?> resolveSuggestion(
    AddressSuggestion suggestion,
  ) async {
    if (!EnvConfig.isGoogleConfigured) return suggestion;

    if (suggestion.hasCoordinates) {
      _startNewSession();
      return suggestion;
    }

    final placeId = suggestion.placeId;
    if (placeId == null || placeId.isEmpty) return suggestion;

    final resolved = await _fetchPlaceDetails(placeId);
    _startNewSession();
    return resolved ?? suggestion;
  }

  static Future<List<_PlacePrediction>> _autocomplete(
    String input, {
    TaskLocation? near,
    bool includeEstablishments = true,
  }) async {
    final body = <String, dynamic>{
      'input': input,
      'languageCode': 'pt-BR',
      'regionCode': 'BR',
      'sessionToken': _sessionToken,
    };

    // Sem filtro de tipo: Google retorna ruas, cidades e POIs (lojas, etc.).
    // Se quiser só estabelecimentos no futuro, use includedPrimaryTypes.
    if (!includeEstablishments) {
      body['includedPrimaryTypes'] = [
        'street_address',
        'route',
        'premise',
        'subpremise',
        'locality',
      ];
    }

    if (near != null) {
      body['locationBias'] = {
        'circle': {
          'center': {
            'latitude': near.lat,
            'longitude': near.lng,
          },
          'radius': 50000.0,
        },
      };
    }

    final uri = Uri.https('places.googleapis.com', '/v1/places:autocomplete');

    try {
      final response = await http
          .post(
            uri,
            headers: _headers(
              fieldMask:
                  'suggestions.placePrediction.placeId,'
                  'suggestions.placePrediction.text,'
                  'suggestions.placePrediction.structuredFormat,'
                  'suggestions.placePrediction.types',
            ),
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 12));

      if (response.statusCode != 200) {
        debugPrint(
          'GeocodeService autocomplete: HTTP ${response.statusCode} ${response.body}',
        );
        return [];
      }

      final data = jsonDecode(response.body);
      if (data is! Map<String, dynamic>) return [];

      final suggestions = data['suggestions'];
      if (suggestions is! List) return [];

      final out = <_PlacePrediction>[];
      for (final raw in suggestions) {
        if (raw is! Map) continue;
        final map = Map<String, dynamic>.from(raw);
        final prediction = map['placePrediction'];
        if (prediction is! Map) continue;
        final predMap = Map<String, dynamic>.from(prediction);

        final placeId = predMap['placeId'] as String? ?? '';
        if (placeId.isEmpty) continue;

        final structured = predMap['structuredFormat'];
        String mainText = '';
        String secondaryText = '';
        if (structured is Map) {
          final st = Map<String, dynamic>.from(structured);
          mainText = _textFromGoogleField(st['mainText']);
          secondaryText = _textFromGoogleField(st['secondaryText']);
        }
        if (mainText.isEmpty) {
          mainText = _textFromGoogleField(predMap['text']);
        }

        final types = predMap['types'];
        out.add(
          _PlacePrediction(
            placeId: placeId,
            mainText: mainText,
            secondaryText: secondaryText,
            types: types is List ? types.cast<dynamic>() : const [],
          ),
        );
        if (out.length >= _maxSuggestions) break;
      }
      return out;
    } catch (e, st) {
      debugPrint('GeocodeService._autocomplete: $e\n$st');
      return [];
    }
  }

  static Future<AddressSuggestion?> _fetchPlaceDetails(String placeId) async {
    final resourceId = placeId.startsWith('places/')
        ? placeId.substring('places/'.length)
        : placeId;

    final uri = Uri.https(
      'places.googleapis.com',
      '/v1/places/${Uri.encodeComponent(resourceId)}',
      {'sessionToken': _sessionToken},
    );

    try {
      final response = await http
          .get(
            uri,
            headers: _headers(
              fieldMask:
                  'id,displayName,formattedAddress,location,types,primaryType',
            ),
          )
          .timeout(const Duration(seconds: 12));

      if (response.statusCode != 200) {
        debugPrint(
          'GeocodeService place details: HTTP ${response.statusCode} ${response.body}',
        );
        return null;
      }

      final data = jsonDecode(response.body);
      if (data is! Map<String, dynamic>) return null;

      return AddressSuggestion.fromGooglePlace(data, placeId: placeId);
    } catch (e, st) {
      debugPrint('GeocodeService._fetchPlaceDetails: $e\n$st');
      return null;
    }
  }

  static Future<String?> _reverseGeocode({
    required double lat,
    required double lng,
  }) async {
    final uri = Uri.https(
      'maps.googleapis.com',
      '/maps/api/geocode/json',
      {
        'latlng': '$lat,$lng',
        'language': 'pt-BR',
        'key': EnvConfig.googlePlacesApiKey,
      },
    );

    try {
      final response = await http
          .get(uri)
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        debugPrint('GeocodeService reverse: HTTP ${response.statusCode}');
        return null;
      }

      final data = jsonDecode(response.body);
      if (data is! Map<String, dynamic>) return null;

      final status = data['status'] as String?;
      if (status != 'OK') {
        debugPrint('GeocodeService reverse status: $status');
        return null;
      }

      final results = data['results'];
      if (results is! List || results.isEmpty) return null;

      final first = results.first;
      if (first is! Map) return null;
      return (first['formatted_address'] as String?)?.trim();
    } catch (e, st) {
      debugPrint('GeocodeService._reverseGeocode: $e\n$st');
      return null;
    }
  }

  static Future<void> _throttleAutocomplete() async {
    await _throttle(_minAutocompleteInterval);
  }

  static Future<void> _throttleSearch() async {
    await _throttle(_minSearchInterval);
  }

  static Future<void> _throttle(Duration minInterval) async {
    final last = _lastSearchRequest;
    if (last != null) {
      final elapsed = DateTime.now().difference(last);
      if (elapsed < minInterval) {
        await Future.delayed(minInterval - elapsed);
      }
    }
    _lastSearchRequest = DateTime.now();
  }

  static String _textFromGoogleField(dynamic field) {
    if (field is Map) {
      return (field['text'] as String?)?.trim() ?? '';
    }
    return '';
  }
}

class _PlacePrediction {
  const _PlacePrediction({
    required this.placeId,
    required this.mainText,
    required this.secondaryText,
    required this.types,
  });

  final String placeId;
  final String mainText;
  final String secondaryText;
  final List<dynamic> types;
}
