import 'package:flutter/foundation.dart';

/// Localização opcional (par latitude/longitude), espelhando o objeto `location` do app web.
@immutable
class TaskLocation {
  const TaskLocation({
    required this.lat,
    required this.lng,
    this.name,
  });

  final double lat;
  final double lng;

  /// Nome do estabelecimento mencionado pelo usuário (ex.: «Ama Hospital Veterinário»).
  final String? name;

  TaskLocation copyWith({double? lat, double? lng, String? name}) {
    return TaskLocation(
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      name: name ?? this.name,
    );
  }

  /// Aceita `lat`/`lng` ou `latitude`/`longitude` (formato web legado).
  static TaskLocation? tryParse(dynamic raw) {
    if (raw is! Map) return null;
    final map = Map<String, dynamic>.from(raw);
    try {
      return TaskLocation.fromJson(map);
    } catch (e) {
      debugPrint('TaskLocation.tryParse: $e');
      return null;
    }
  }

  factory TaskLocation.fromJson(Map<String, dynamic> json) {
    final lat = json['lat'] ?? json['latitude'];
    final lng = json['lng'] ?? json['longitude'];
    if (lat == null || lng == null) {
      throw FormatException('location sem lat/lng');
    }
    final rawName = json['name'];
    final name = rawName is String && rawName.trim().isNotEmpty
        ? rawName.trim()
        : null;

    return TaskLocation(
      lat: (lat is num) ? lat.toDouble() : double.parse('$lat'),
      lng: (lng is num) ? lng.toDouble() : double.parse('$lng'),
      name: name,
    );
  }

  Map<String, dynamic> toJson() => {
        'lat': lat,
        'lng': lng,
        if (name != null && name!.trim().isNotEmpty) 'name': name!.trim(),
      };

  /// Nome do estabelecimento + endereço resolvido (sem duplicar o nome).
  static String formatAddressLine({
    required TaskLocation location,
    String? streetAddress,
  }) {
    final placeName = location.name?.trim();
    final address = streetAddress?.trim();

    if (placeName != null &&
        placeName.isNotEmpty &&
        address != null &&
        address.isNotEmpty) {
      final placeNorm = placeName.toLowerCase();
      final addressNorm = address.toLowerCase();
      if (addressNorm.contains(placeNorm)) return address;
      return '$placeName · $address';
    }

    if (placeName != null && placeName.isNotEmpty) return placeName;
    if (address != null && address.isNotEmpty) return address;
    return '${location.lat.toStringAsFixed(4)}, ${location.lng.toStringAsFixed(4)}';
  }
}

/// Modelo de tarefa — persistência apenas local ([tasker-main/src/utils/db.js]).
@immutable
class Task {
  const Task({
    required this.id,
    required this.title,
    this.descricao = '',
    required this.data,
    required this.hora,
    this.done = false,
    this.createdAt,
    this.lastUpdated,
    this.location,
    this.deleted = false,
    /// Chave do ícone — ver [TaskIconCatalog.icons]. Null = casa.
    this.iconKey,
    /// ARGB da cor de fundo do ícone (`Color.toARGB32()`). Null = padrão do app.
    this.iconBackgroundArgb,
  });

  final String id;
  final String title;
  final String descricao;
  final String data;
  final String hora;
  final bool done;
  final DateTime? createdAt;
  final DateTime? lastUpdated;
  final TaskLocation? location;
  final bool deleted;
  final String? iconKey;
  final int? iconBackgroundArgb;

  String get displayDescription {
    final t = descricao.trim();
    return t.isEmpty ? '' : t;
  }

  Task copyWith({
    String? id,
    String? title,
    String? descricao,
    String? data,
    String? hora,
    bool? done,
    DateTime? createdAt,
    DateTime? lastUpdated,
    TaskLocation? location,
    bool? deleted,
    String? iconKey,
    int? iconBackgroundArgb,
  }) {
    return Task(
      id: id ?? this.id,
      title: title ?? this.title,
      descricao: descricao ?? this.descricao,
      data: data ?? this.data,
      hora: hora ?? this.hora,
      done: done ?? this.done,
      createdAt: createdAt ?? this.createdAt,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      location: location ?? this.location,
      deleted: deleted ?? this.deleted,
      iconKey: iconKey ?? this.iconKey,
      iconBackgroundArgb: iconBackgroundArgb ?? this.iconBackgroundArgb,
    );
  }

  factory Task.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic v) {
      if (v == null) return null;
      if (v is DateTime) return v;
      if (v is String) return DateTime.tryParse(v);
      return null;
    }

    final loc = TaskLocation.tryParse(json['location']);

    return Task(
      id: '${json['id'] ?? ''}',
      title: json['title'] as String? ?? '',
      descricao: json['descricao'] as String? ?? '',
      data: json['data'] as String? ?? '',
      hora: json['hora'] as String? ?? '',
      done: json['done'] as bool? ?? false,
      createdAt: parseDate(json['createdAt']),
      lastUpdated: parseDate(json['lastUpdated']),
      location: loc,
      deleted: json['_deleted'] as bool? ?? false,
      iconKey: json['iconKey'] as String?,
      iconBackgroundArgb: _parseIconBackgroundArgb(json['iconBackgroundArgb']),
    );
  }

  static int? _parseIconBackgroundArgb(dynamic raw) {
    if (raw == null) return null;
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    return int.tryParse('$raw');
  }

  /// JSON gravado no dispositivo (sem campos de nuvem/sync).
  Map<String, dynamic> toLocalJson() => {
        'id': id,
        'title': title,
        'descricao': descricao,
        'data': data,
        'hora': hora,
        'done': done,
        if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
        if (lastUpdated != null) 'lastUpdated': lastUpdated!.toIso8601String(),
        if (location != null) 'location': location!.toJson(),
        '_deleted': deleted,
        if (iconKey != null) 'iconKey': iconKey,
        if (iconBackgroundArgb != null)
          'iconBackgroundArgb': iconBackgroundArgb,
      };
}
