import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/pilha.dart';

/// Persistência local das pilhas (SharedPreferences).
class PilhaLocalRepository {
  PilhaLocalRepository._();

  static final PilhaLocalRepository instance = PilhaLocalRepository._();

  static const _pilhasKey = 'tasker_pilhas_json';

  Future<List<Pilha>> getAll() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_pilhasKey);
      if (raw == null || raw.trim().isEmpty) return [];

      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];

      final pilhas = <Pilha>[];
      for (final item in decoded) {
        if (item is! Map) continue;
        try {
          pilhas.add(Pilha.fromJson(Map<String, dynamic>.from(item)));
        } catch (e, st) {
          debugPrint('PilhaLocalRepository: item ignorado: $e\n$st');
        }
      }
      return pilhas;
    } catch (e, st) {
      debugPrint('PilhaLocalRepository.getAll: $e\n$st');
      return [];
    }
  }

  Future<void> saveAll(List<Pilha> pilhas) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(pilhas.map((p) => p.toJson()).toList());
    final ok = await prefs.setString(_pilhasKey, encoded);
    if (!ok) {
      throw StateError('Não foi possível gravar as pilhas no dispositivo.');
    }
  }
}
