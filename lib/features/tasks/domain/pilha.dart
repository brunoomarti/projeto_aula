import 'package:flutter/foundation.dart';

/// Grupo de tarefas relacionadas — exibido empilhado na home.
@immutable
class Pilha {
  const Pilha({
    required this.id,
    required this.name,
    this.createdAt,
  });

  final String id;
  final String name;
  final DateTime? createdAt;

  Pilha copyWith({
    String? id,
    String? name,
    DateTime? createdAt,
  }) {
    return Pilha(
      id: id ?? this.id,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory Pilha.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic v) {
      if (v == null) return null;
      if (v is DateTime) return v;
      if (v is String) return DateTime.tryParse(v);
      return null;
    }

    return Pilha(
      id: '${json['id'] ?? ''}',
      name: json['name'] as String? ?? '',
      createdAt: parseDate(json['createdAt']),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
      };
}
