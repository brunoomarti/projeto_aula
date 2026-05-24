import 'package:flutter/foundation.dart';

import 'task.dart';

/// Resultado de busca (endereço ou estabelecimento via OSM).
@immutable
class AddressSuggestion {
  const AddressSuggestion({
    required this.displayName,
    required this.shortLabel,
    required this.location,
    this.categoryLabel,
  });

  final String displayName;
  final String shortLabel;
  final TaskLocation location;

  /// Ex.: "Restaurante", "Loja", "Endereço".
  final String? categoryLabel;

  factory AddressSuggestion.fromNominatim(Map<String, dynamic> json) {
    final displayName = (json['display_name'] as String?) ?? '';
    final lat = json['lat'];
    final lon = json['lon'];

    final parts = displayName
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    final short = parts.length <= 2
        ? displayName
        : '${parts[0]}, ${parts[1]}';

    final type = json['type'] as String?;
    final category = json['class'] as String?;
    final categoryLabel = _labelFromNominatimType(category, type);

    return AddressSuggestion(
      displayName: displayName,
      shortLabel: short,
      location: TaskLocation(
        lat: lat is num ? lat.toDouble() : double.parse('$lat'),
        lng: lon is num ? lon.toDouble() : double.parse('$lon'),
      ),
      categoryLabel: categoryLabel,
    );
  }

  factory AddressSuggestion.fromPhoton(Map<String, dynamic> properties, List coords) {
    final lng = coords[0] is num ? (coords[0] as num).toDouble() : double.parse('${coords[0]}');
    final lat = coords[1] is num ? (coords[1] as num).toDouble() : double.parse('${coords[1]}');

    final name = (properties['name'] as String?)?.trim();
    final street = (properties['street'] as String?)?.trim();
    final housenumber = (properties['housenumber'] as String?)?.trim();
    final city = (properties['city'] as String?)?.trim() ??
        (properties['town'] as String?)?.trim() ??
        (properties['village'] as String?)?.trim();
    final state = (properties['state'] as String?)?.trim();

    final osmKey = properties['osm_key'] as String?;
    final osmValue = properties['osm_value'] as String?;
    final categoryLabel = _labelFromOsmTag(osmKey, osmValue);

    final streetLine = [
      if (street != null && street.isNotEmpty) street,
      if (housenumber != null && housenumber.isNotEmpty) housenumber,
    ].join(', ');

    final contextParts = [
      if (streetLine.isNotEmpty) streetLine,
      if (city != null && city.isNotEmpty) city,
      if (state != null && state.isNotEmpty) state,
    ];

    final displayName = name != null && name.isNotEmpty
        ? [...contextParts.isEmpty ? [name] : [name, ...contextParts]].join(', ')
        : contextParts.join(', ');

    final shortLabel = name != null && name.isNotEmpty
        ? (contextParts.isEmpty
            ? name
            : '$name · ${contextParts.take(2).join(', ')}')
        : displayName;

    return AddressSuggestion(
      displayName: displayName.isEmpty ? shortLabel : displayName,
      shortLabel: shortLabel.isEmpty ? displayName : shortLabel,
      location: TaskLocation(lat: lat, lng: lng),
      categoryLabel: categoryLabel,
    );
  }

  static String? _labelFromNominatimType(String? osmClass, String? type) {
    if (osmClass == 'amenity' ||
        osmClass == 'shop' ||
        osmClass == 'tourism' ||
        osmClass == 'office' ||
        osmClass == 'craft' ||
        osmClass == 'leisure') {
      return _labelFromOsmTag(osmClass, type);
    }
    if (osmClass == 'building' && type == 'yes') return 'Estabelecimento';
    return osmClass == 'place' ? null : 'Endereço';
  }

  static String? _labelFromOsmTag(String? key, String? value) {
    if (key == null || value == null) return 'Estabelecimento';

    const labels = {
      'restaurant': 'Restaurante',
      'cafe': 'Café',
      'fast_food': 'Fast food',
      'bar': 'Bar',
      'pub': 'Pub',
      'bakery': 'Padaria',
      'supermarket': 'Supermercado',
      'convenience': 'Conveniência',
      'mall': 'Shopping',
      'clothes': 'Loja de roupas',
      'hairdresser': 'Salão',
      'pharmacy': 'Farmácia',
      'hospital': 'Hospital',
      'clinic': 'Clínica',
      'dentist': 'Dentista',
      'bank': 'Banco',
      'atm': 'Caixa eletrônico',
      'fuel': 'Posto',
      'car': 'Concessionária',
      'car_repair': 'Oficina',
      'hotel': 'Hotel',
      'motel': 'Motel',
      'hostel': 'Hostel',
      'gym': 'Academia',
      'school': 'Escola',
      'university': 'Universidade',
      'kindergarten': 'Creche',
      'library': 'Biblioteca',
      'cinema': 'Cinema',
      'theatre': 'Teatro',
      'museum': 'Museu',
      'place_of_worship': 'Templo',
      'parking': 'Estacionamento',
      'marketplace': 'Mercado',
      'beauty': 'Beleza',
      'electronics': 'Eletrônicos',
      'furniture': 'Móveis',
      'hardware': 'Material de construção',
      'pet': 'Pet shop',
      'veterinary': 'Veterinário',
      'laundry': 'Lavanderia',
      'dry_cleaning': 'Lavanderia',
      'office': 'Escritório',
      'company': 'Empresa',
      'yes': 'Comércio',
    };

    if (labels.containsKey(value)) return labels[value];

    switch (key) {
      case 'shop':
        return 'Loja';
      case 'amenity':
        return 'Estabelecimento';
      case 'tourism':
        return 'Turismo';
      case 'leisure':
        return 'Lazer';
      case 'office':
        return 'Empresa';
      case 'craft':
        return 'Comércio';
      default:
        return 'Estabelecimento';
    }
  }
}
