import 'dart:math' as math;

import '../../features/tasks/domain/address_suggestion.dart';
import '../../features/tasks/domain/task.dart';
import '../services/geocode_service.dart';
import 'extract_place_pt_br.dart';

/// Resultado da resolução de local via geocoding.
class ResolvedPlace {
  const ResolvedPlace({
    required this.location,
    required this.label,
    required this.searchQuery,
  });

  final TaskLocation location;
  final String label;
  final String searchQuery;
}

/// Sinônimos para busca/score de instituições conhecidas.
const _kInstitutionAliases = <String, List<String>>{
  'ifes': [
    'ifes',
    'instituto federal',
    'instituto federal do espirito santo',
  ],
  'ufes': ['ufes', 'universidade federal do espirito santo'],
  'unitins': ['unitins', 'universidade do tocantins'],
  'unesc': ['unesc'],
  'faccamp': ['faccamp'],
};

/// Distância aproximada em km entre dois pontos (Haversine).
double haversineDistanceKm(TaskLocation a, TaskLocation b) {
  const earthRadiusKm = 6371.0;
  final dLat = _toRad(b.lat - a.lat);
  final dLng = _toRad(b.lng - a.lng);
  final lat1 = _toRad(a.lat);
  final lat2 = _toRad(b.lat);

  final h = math.pow(math.sin(dLat / 2), 2) +
      math.cos(lat1) * math.cos(lat2) * math.pow(math.sin(dLng / 2), 2);
  return earthRadiusKm * 2 * math.asin(math.sqrt(h));
}

double _toRad(double deg) => deg * math.pi / 180.0;

String _norm(String s) => s.toLowerCase().trim();

List<String> _aliasesForQuery(String query) {
  final low = _norm(query);
  final out = <String>[low];
  for (final entry in _kInstitutionAliases.entries) {
    if (low.contains(entry.key)) {
      out.addAll(entry.value);
    }
  }
  return out.toSet().toList();
}

/// Queries alternativas para melhorar resultados OSM.
List<String> geocodeQueriesForPlace(ExtractPlaceResult place) {
  final queries = <String>[place.searchQuery.trim()];
  final low = _norm(place.searchQuery);

  for (final entry in _kInstitutionAliases.entries) {
    if (low.contains(entry.key)) {
      queries.add('${entry.key.toUpperCase()} Espírito Santo');
      queries.add(entry.value.last);
    }
  }

  if (place.qualifiers.isNotEmpty) {
    queries.add('${place.searchQuery} ${place.qualifiers.join(' ')}');
  }

  if (low.contains('shopping')) {
    queries.add('${place.searchQuery} Espírito Santo');
    if (low.contains('vitoria')) {
      queries.add('Shopping Vitória Espírito Santo');
      queries.add('Shopping Center Vitória ES');
    }
  }

  return queries.where((q) => q.trim().length >= 3).toSet().toList();
}

/// Verifica se o resultado da busca corresponde ao local pedido.
bool textMatchesPlace(AddressSuggestion suggestion, ExtractPlaceResult place) {
  final label = _norm('${suggestion.shortLabel} ${suggestion.displayName}');

  for (final alias in _aliasesForQuery(place.searchQuery)) {
    if (alias.length >= 3 && label.contains(_norm(alias))) {
      return true;
    }
  }

  for (final token in _norm(place.searchQuery).split(RegExp(r'\s+'))) {
    if (token.length >= 3 && label.contains(token)) {
      return true;
    }
  }

  return false;
}

/// Pontua sugestões para escolher o melhor candidato.
double scorePlaceSuggestion(
  AddressSuggestion suggestion,
  ExtractPlaceResult place,
  TaskLocation? near,
) {
  final label = _norm('${suggestion.shortLabel} ${suggestion.displayName}');
  final query = _norm(place.searchQuery);
  var score = 0.0;

  if (textMatchesPlace(suggestion, place)) {
    score += 30.0;
  }

  final queryTokens = query
      .split(RegExp(r'\s+'))
      .where((t) => t.length >= 2)
      .toList();

  for (final token in queryTokens) {
    if (label.contains(token)) {
      score += token.length >= 4 ? 14.0 : 8.0;
    }
  }

  for (final qual in place.qualifiers) {
    final q = _norm(qual);
    if (q.length >= 3 && label.contains(q)) {
      score += 28.0;
    }
  }

  if (suggestion.categoryLabel != null &&
      suggestion.categoryLabel != 'Endereço') {
    score += 4.0;
  }

  if (near != null) {
    final km = haversineDistanceKm(near, suggestion.location);
  // Penalidade suave — campus pode estar a dezenas de km, ainda é válido.
    score -= km * 0.35;
    if (km <= 5) score += 20;
    if (km <= 25) score += 10;
    if (km <= 80) score += 4;
  }

  return score;
}

AddressSuggestion? _pickNearestTextMatch(
  List<AddressSuggestion> suggestions,
  ExtractPlaceResult place,
  TaskLocation? near,
) {
  final matched =
      suggestions.where((s) => textMatchesPlace(s, place)).toList();
  if (matched.isEmpty) return null;

  if (near != null) {
    matched.sort(
      (a, b) => haversineDistanceKm(near, a.location)
          .compareTo(haversineDistanceKm(near, b.location)),
    );
  }

  return matched.first;
}

/// Escolhe a melhor sugestão; retorna null se nenhuma for confiável.
AddressSuggestion? pickBestPlaceSuggestion(
  List<AddressSuggestion> suggestions,
  ExtractPlaceResult place,
  TaskLocation? near,
) {
  if (suggestions.isEmpty) return null;

  var pool = suggestions;
  if (place.qualifiers.isNotEmpty) {
    final qualified = pool.where((item) {
      final label = _norm('${item.shortLabel} ${item.displayName}');
      return place.qualifiers.any((q) {
        final nq = _norm(q);
        return nq.length >= 3 && label.contains(nq);
      });
    }).toList();
    if (qualified.isNotEmpty) pool = qualified;
  }

  // Correspondência textual clara → campus/POI mais próximo.
  final textNearest = _pickNearestTextMatch(pool, place, near);
  if (textNearest != null) return textNearest;

  AddressSuggestion? best;
  var bestScore = double.negativeInfinity;

  for (final item in pool) {
    final s = scorePlaceSuggestion(item, place, near);
    if (s > bestScore) {
      bestScore = s;
      best = item;
    }
  }

  if (best == null) return null;
  if (textMatchesPlace(best, place)) return best;
  if (bestScore >= 6) return best;
  return null;
}

String _enhanceGeocodeQuery(String query) {
  final q = query.trim();
  if (q.isEmpty) return q;
  if (!q.toLowerCase().contains('brasil')) {
    return '$q, Brasil';
  }
  return q;
}

Future<List<AddressSuggestion>> _searchAllQueries(
  ExtractPlaceResult place, {
  TaskLocation? near,
}) async {
  final seen = <String>{};
  final merged = <AddressSuggestion>[];

  for (final raw in geocodeQueriesForPlace(place)) {
    final q = _enhanceGeocodeQuery(raw);
    final results = await GeocodeService.searchAddresses(q, near: near);
    for (final item in results) {
      if (!item.hasCoordinates) continue;
      final key = item.placeId ??
          '${item.location.lat.toStringAsFixed(4)}|${item.location.lng.toStringAsFixed(4)}';
      if (seen.add(key)) merged.add(item);
    }
  }

  return merged;
}

/// Busca coordenadas na internet com viés de proximidade ([near]).
Future<ResolvedPlace?> resolvePlaceLocation(
  ExtractPlaceResult place, {
  TaskLocation? near,
}) async {
  final suggestions = await _searchAllQueries(place, near: near);
  final best = pickBestPlaceSuggestion(suggestions, place, near);

  if (best == null) return null;

  final resolved = await GeocodeService.resolveSuggestion(best);
  if (resolved == null || !resolved.hasCoordinates) return null;

  return ResolvedPlace(
    location: resolved.location,
    label: resolved.shortLabel.isNotEmpty
        ? resolved.shortLabel
        : resolved.displayName,
    searchQuery: place.searchQuery,
  );
}
