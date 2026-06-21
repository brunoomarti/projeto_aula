import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/daily_combo_state.dart';

/// Armazenamento local do combo diário em [SharedPreferences].
class DailyComboLocalRepository {
  DailyComboLocalRepository._();

  static final DailyComboLocalRepository instance =
      DailyComboLocalRepository._();

  static String _keyFor(String userId) => 'tasker_daily_combo_v1_$userId';

  Future<DailyComboState?> read(String userId) async {
    if (userId.isEmpty) return null;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_keyFor(userId));
      if (raw == null || raw.trim().isEmpty) return null;
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      return DailyComboState.fromLocalJson(
        Map<String, dynamic>.from(decoded),
      );
    } catch (e, st) {
      debugPrint('DailyComboLocalRepository.read: $e\n$st');
      return null;
    }
  }

  Future<void> write(String userId, DailyComboState state) async {
    if (userId.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _keyFor(userId),
        jsonEncode(state.toLocalJson()),
      );
    } catch (e, st) {
      debugPrint('DailyComboLocalRepository.write: $e\n$st');
    }
  }

  Future<void> clear(String userId) async {
    if (userId.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyFor(userId));
    } catch (e, st) {
      debugPrint('DailyComboLocalRepository.clear: $e\n$st');
    }
  }
}
