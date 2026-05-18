import 'package:flutter/foundation.dart';

/// Localização opcional (par latitude/longitude), espelhando o objeto `location` do app web.
@immutable
class TaskLocation {
  const TaskLocation({required this.lat, required this.lng});

  final double lat;
  final double lng;

  factory TaskLocation.fromJson(Map<String, dynamic> json) {
    final lat = json['lat'];
    final lng = json['lng'];
    return TaskLocation(
      lat: (lat is num) ? lat.toDouble() : double.parse('$lat'),
      lng: (lng is num) ? lng.toDouble() : double.parse('$lng'),
    );
  }

  Map<String, dynamic> toJson() => {'lat': lat, 'lng': lng};
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
    );
  }

  factory Task.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic v) {
      if (v == null) return null;
      if (v is DateTime) return v;
      if (v is String) return DateTime.tryParse(v);
      return null;
    }

    TaskLocation? loc;
    final rawLoc = json['location'];
    if (rawLoc is Map<String, dynamic>) {
      loc = TaskLocation.fromJson(rawLoc);
    }

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
    );
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
      };
}
