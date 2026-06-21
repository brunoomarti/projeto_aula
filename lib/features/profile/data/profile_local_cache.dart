import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'profile_repository.dart';

/// Cache local do perfil ([UserProfile]) em [SharedPreferences].
///
/// Permite mostrar o nome do usuário instantaneamente (sem buscar na nuvem) e
/// funciona offline. A flag `dirty` indica que o nome foi editado localmente e
/// ainda precisa ser enviado ao Supabase.
class ProfileLocalCache {
  static const _profileKey = 'cached_user_profile_v1';
  static const _dirtyKey = 'cached_user_profile_dirty_v1';

  Future<UserProfile?> read() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_profileKey);
      if (raw == null || raw.trim().isEmpty) return null;
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      return UserProfile.fromJson(Map<String, dynamic>.from(decoded));
    } catch (e, st) {
      debugPrint('ProfileLocalCache.read: $e\n$st');
      return null;
    }
  }

  Future<void> write(UserProfile profile, {bool dirty = false}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_profileKey, jsonEncode(profile.toJson()));
      await prefs.setBool(_dirtyKey, dirty);
    } catch (e, st) {
      debugPrint('ProfileLocalCache.write: $e\n$st');
    }
  }

  Future<bool> isDirty() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_dirtyKey) ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> clear() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_profileKey);
      await prefs.remove(_dirtyKey);
    } catch (e, st) {
      debugPrint('ProfileLocalCache.clear: $e\n$st');
    }
  }
}
