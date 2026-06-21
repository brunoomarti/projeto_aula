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
    /// `true` quando a versão local já está refletida na nuvem (Supabase).
    /// `false` = alteração pendente de envio (offline ou erro de rede).
    /// Campo apenas local — não é gravado no Supabase.
    this.synced = true,
    /// ID da [Pilha] à qual a tarefa pertence. Apenas local por enquanto.
    this.pilhaId,
    /// Tarefa teve a data alterada após o período de tolerância (1 h).
    /// Não conta para o combo diário.
    this.postponed = false,
    /// A data agendada foi alterada em qualquer momento (inclui tentativa de burlar < 1 h).
    this.scheduleAdjusted = false,
    /// Momento em que a tarefa foi marcada como concluída pela última vez.
    this.completedAt,
    /// Tarefa criada pelo Magic Input (entrada inteligente).
    this.createdViaMagic = false,
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
  final bool synced;
  final String? pilhaId;
  final bool postponed;
  final bool scheduleAdjusted;
  final DateTime? completedAt;
  final bool createdViaMagic;

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
    bool? synced,
    String? pilhaId,
    bool clearPilhaId = false,
    bool? postponed,
    bool? scheduleAdjusted,
    DateTime? completedAt,
    bool clearCompletedAt = false,
    bool? createdViaMagic,
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
      synced: synced ?? this.synced,
      pilhaId: clearPilhaId ? null : (pilhaId ?? this.pilhaId),
      postponed: postponed ?? this.postponed,
      scheduleAdjusted: scheduleAdjusted ?? this.scheduleAdjusted,
      completedAt:
          clearCompletedAt ? null : (completedAt ?? this.completedAt),
      createdViaMagic: createdViaMagic ?? this.createdViaMagic,
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
      synced: json['_synced'] as bool? ?? true,
      pilhaId: json['pilhaId'] as String?,
      postponed: json['postponed'] as bool? ?? false,
      scheduleAdjusted: json['scheduleAdjusted'] as bool? ?? false,
      completedAt: parseDate(json['completedAt']),
      createdViaMagic: json['createdViaMagic'] as bool? ?? false,
    );
  }

  static int? _parseIconBackgroundArgb(dynamic raw) {
    if (raw == null) return null;
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    return int.tryParse('$raw');
  }

  factory Task.fromSupabaseRow(Map<String, dynamic> row) {
    DateTime? parseTs(dynamic v) {
      if (v == null) return null;
      if (v is DateTime) return v;
      if (v is String) return DateTime.tryParse(v);
      return null;
    }

    final loc = TaskLocation.tryParse(row['location']);

    return Task(
      id: '${row['id'] ?? ''}',
      title: row['title'] as String? ?? '',
      descricao: row['descricao'] as String? ?? '',
      data: row['data'] as String? ?? '',
      hora: row['hora'] as String? ?? '',
      done: row['done'] as bool? ?? false,
      createdAt: parseTs(row['created_at']),
      lastUpdated: parseTs(row['last_updated']),
      location: loc,
      deleted: row['deleted'] as bool? ?? false,
      iconKey: row['icon_key'] as String?,
      iconBackgroundArgb: _parseIconBackgroundArgb(row['icon_background_argb']),
      synced: true,
      postponed: row['postponed'] as bool? ?? false,
      scheduleAdjusted: row['schedule_adjusted'] as bool? ?? false,
      completedAt: parseTs(row['completed_at']),
      createdViaMagic: row['created_via_magic'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toSupabaseRow(String userId) => {
        'id': id,
        'user_id': userId,
        'title': title,
        'descricao': descricao,
        'data': data,
        'hora': hora,
        'done': done,
        'created_at': (createdAt ?? DateTime.now()).toUtc().toIso8601String(),
        'last_updated': (lastUpdated ?? DateTime.now()).toUtc().toIso8601String(),
        'location': location?.toJson(),
        'deleted': deleted,
        'postponed': postponed,
        'schedule_adjusted': scheduleAdjusted,
        if (completedAt != null)
          'completed_at': completedAt!.toUtc().toIso8601String(),
        'created_via_magic': createdViaMagic,
        if (iconKey != null) 'icon_key': iconKey,
        if (iconBackgroundArgb != null)
          'icon_background_argb': iconBackgroundArgb,
      };

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
        '_synced': synced,
        'postponed': postponed,
        'scheduleAdjusted': scheduleAdjusted,
        if (completedAt != null) 'completedAt': completedAt!.toIso8601String(),
        if (createdViaMagic) 'createdViaMagic': true,
        if (iconKey != null) 'iconKey': iconKey,
        if (iconBackgroundArgb != null)
          'iconBackgroundArgb': iconBackgroundArgb,
        if (pilhaId != null) 'pilhaId': pilhaId,
      };
}
