import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/achievement_progress_state.dart';

/// Armazenamento local das conquistas em [SharedPreferences].
class AchievementLocalRepository {
  AchievementLocalRepository._();

  static final AchievementLocalRepository instance =
      AchievementLocalRepository._();

  static String _keyFor(String userId) => 'tasker_achievements_v1_$userId';

  Future<AchievementProgressState?> read(String userId) async {
    if (userId.isEmpty) return null;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_keyFor(userId));
      if (raw == null || raw.trim().isEmpty) return null;
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      return AchievementProgressState.fromLocalJson(
        Map<String, dynamic>.from(decoded),
      );
    } catch (e, st) {
      debugPrint('AchievementLocalRepository.read: $e\n$st');
      return null;
    }
  }

  Future<void> write(String userId, AchievementProgressState state) async {
    if (userId.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _keyFor(userId),
        jsonEncode(state.toLocalJson()),
      );
    } catch (e, st) {
      debugPrint('AchievementLocalRepository.write: $e\n$st');
    }
  }

  Future<void> clear(String userId) async {
    if (userId.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyFor(userId));
    } catch (e, st) {
      debugPrint('AchievementLocalRepository.clear: $e\n$st');
    }
  }
}
