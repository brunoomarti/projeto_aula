import 'package:flutter/foundation.dart';

import 'task.dart';

/// Resultado de busca (endereço ou estabelecimento).
@immutable
class AddressSuggestion {
  const AddressSuggestion({
    required this.displayName,
    required this.shortLabel,
    required this.location,
    this.categoryLabel,
    this.placeId,
  });

  final String displayName;
  final String shortLabel;
  final TaskLocation location;
  final String? placeId;

  /// Ex.: "Restaurante", "Loja", "Endereço".
  final String? categoryLabel;

  bool get hasCoordinates =>
      location.lat != 0 || location.lng != 0;

  /// Detalhes do lugar via [GeocodeService] / Places API (New).
  factory AddressSuggestion.fromGooglePlace(
    Map<String, dynamic> json, {
    String? placeId,
  }) {
    final name = _textFromGoogleField(json['displayName']);
    final formatted = (json['formattedAddress'] as String?)?.trim() ?? '';

    final loc = json['location'];
    double lat = 0;
    double lng = 0;
    if (loc is Map) {
      final latVal = loc['latitude'];
      final lngVal = loc['longitude'];
      if (latVal is num) lat = latVal.toDouble();
      if (lngVal is num) lng = lngVal.toDouble();
    }

    final types = json['types'];
    final typeList = types is List ? types.map((e) => e.toString()).toList() : <String>[];
    final primaryType = json['primaryType'] as String?;
    final categoryLabel = _labelFromGoogleTypes(typeList, primaryType: primaryType);

    final displayName = formatted.isNotEmpty
        ? (name.isNotEmpty ? '$name, $formatted' : formatted)
        : name;

    final shortLabel = name.isNotEmpty
        ? name
        : (formatted.isNotEmpty ? formatted : displayName);

    final id = placeId ??
        (json['id'] as String?) ??
        (json['name'] as String?);

    return AddressSuggestion(
      displayName: displayName.isNotEmpty ? displayName : shortLabel,
      shortLabel: shortLabel.isNotEmpty ? shortLabel : displayName,
      location: TaskLocation(lat: lat, lng: lng),
      categoryLabel: categoryLabel,
      placeId: id,
    );
  }

  /// Autocomplete sem coordenadas (antes de [GeocodeService.resolveSuggestion]).
  factory AddressSuggestion.fromGoogleAutocomplete({
    required String placeId,
    required String mainText,
    required String secondaryText,
    List<dynamic> types = const [],
  }) {
    final typeStrings = types.map((e) => e.toString()).toList();
    final displayName = secondaryText.isNotEmpty
        ? '$mainText, $secondaryText'
        : mainText;

    return AddressSuggestion(
      displayName: displayName,
      shortLabel: mainText.isNotEmpty ? mainText : displayName,
      location: const TaskLocation(lat: 0, lng: 0),
      categoryLabel: _labelFromGoogleTypes(typeStrings),
      placeId: placeId,
    );
  }

  static String _textFromGoogleField(dynamic field) {
    if (field is Map) {
      return (field['text'] as String?)?.trim() ?? '';
    }
    return '';
  }

  static String? _labelFromGoogleTypes(
    List<String> types, {
    String? primaryType,
  }) {
    if (primaryType != null && primaryType.isNotEmpty) {
      final fromPrimary = _googleTypeLabels[primaryType];
      if (fromPrimary != null) return fromPrimary;
    }

    for (final type in types) {
      final label = _googleTypeLabels[type];
      if (label != null) return label;
    }

    const establishmentHints = {
      'establishment',
      'point_of_interest',
      'store',
      'food',
    };
    if (types.any(establishmentHints.contains)) {
      return 'Estabelecimento';
    }

    if (types.contains('street_address') ||
        types.contains('route') ||
        types.contains('premise') ||
        types.contains('subpremise')) {
      return 'Endereço';
    }

    return types.isEmpty ? null : 'Endereço';
  }

  static const _googleTypeLabels = {
    'restaurant': 'Restaurante',
    'cafe': 'Café',
    'coffee_shop': 'Café',
    'bakery': 'Padaria',
    'bar': 'Bar',
    'meal_takeaway': 'Delivery',
    'meal_delivery': 'Delivery',
    'fast_food_restaurant': 'Fast food',
    'supermarket': 'Supermercado',
    'grocery_store': 'Mercado',
    'convenience_store': 'Conveniência',
    'shopping_mall': 'Shopping',
    'clothing_store': 'Loja de roupas',
    'pharmacy': 'Farmácia',
    'drugstore': 'Farmácia',
    'hospital': 'Hospital',
    'doctor': 'Clínica',
    'dentist': 'Dentista',
    'bank': 'Banco',
    'atm': 'Caixa eletrônico',
    'gas_station': 'Posto',
    'car_repair': 'Oficina',
    'car_dealer': 'Concessionária',
    'lodging': 'Hotel',
    'gym': 'Academia',
    'school': 'Escola',
    'university': 'Universidade',
    'library': 'Biblioteca',
    'movie_theater': 'Cinema',
    'museum': 'Museu',
    'parking': 'Estacionamento',
    'beauty_salon': 'Beleza',
    'hair_care': 'Salão',
    'pet_store': 'Pet shop',
    'veterinary_care': 'Veterinário',
    'laundry': 'Lavanderia',
    'electronics_store': 'Eletrônicos',
    'furniture_store': 'Móveis',
    'hardware_store': 'Material de construção',
    'insurance_agency': 'Seguros',
    'real_estate_agency': 'Imobiliária',
    'lawyer': 'Advocacia',
    'accounting': 'Contabilidade',
    'post_office': 'Correios',
    'bus_station': 'Rodoviária',
    'train_station': 'Estação',
    'airport': 'Aeroporto',
  };
}
