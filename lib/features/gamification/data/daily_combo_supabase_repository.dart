import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/auth/firebase_user_id.dart';
import '../../../core/bootstrap/app_bootstrap.dart';
import '../domain/daily_combo_dates.dart';
import '../domain/daily_combo_history_entry.dart';
import '../domain/daily_combo_state.dart';

/// Sincronização do combo diário com o Supabase.
class DailyComboSupabaseRepository {
  DailyComboSupabaseRepository({SupabaseClient? client})
      : _client = client ?? AppBootstrap.supabase;

  final SupabaseClient _client;

  static const _stateTable = 'daily_combo_state';
  static const _historyTable = 'daily_combo_history';

  String? get _userId => currentFirebaseUserId();

  Future<DailyComboState?> fetchState() async {
    final userId = _userId;
    if (userId == null) return null;

    try {
      final row = await _client
          .from(_stateTable)
          .select()
          .eq('user_id', userId)
          .maybeSingle();
      if (row == null) return null;
      return _stateFromRow(Map<String, dynamic>.from(row));
    } catch (e, st) {
      debugPrint('DailyComboSupabaseRepository.fetchState: $e\n$st');
      return null;
    }
  }

  Future<void> upsertState(DailyComboState state) async {
    final userId = _userId;
    if (userId == null) {
      throw StateError('Usuário não autenticado no Supabase.');
    }

    await _client.from(_stateTable).upsert({
      'user_id': userId,
      'current_streak': state.currentStreak,
      'streak_started_on': state.streakStartedOn != null
          ? DailyComboDates.formatYmd(state.streakStartedOn!)
          : null,
      'last_cleared_on': state.lastClearedOn != null
          ? DailyComboDates.formatYmd(state.lastClearedOn!)
          : null,
      'pending_archive_length': state.pendingArchiveLength,
      'pending_archive_started_on': state.pendingArchiveStartedOn != null
          ? DailyComboDates.formatYmd(state.pendingArchiveStartedOn!)
          : null,
      'pending_archive_broken_on': state.pendingArchiveBrokenOn != null
          ? DailyComboDates.formatYmd(state.pendingArchiveBrokenOn!)
          : null,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  Future<void> insertHistoryEntries(
    List<DailyComboHistoryEntry> entries,
  ) async {
    final userId = _userId;
    if (userId == null || entries.isEmpty) return;

    final rows = entries.map((e) => e.toSupabaseRow(userId)).toList();
    await _client.from(_historyTable).insert(rows);
  }

  DailyComboState _stateFromRow(Map<String, dynamic> row) {
    return DailyComboState(
      currentStreak: row['current_streak'] as int? ?? 0,
      streakStartedOn:
          DailyComboDates.parseYmd(row['streak_started_on'] as String?),
      lastClearedOn:
          DailyComboDates.parseYmd(row['last_cleared_on'] as String?),
      pendingArchiveLength: row['pending_archive_length'] as int?,
      pendingArchiveStartedOn: DailyComboDates.parseYmd(
        row['pending_archive_started_on'] as String?,
      ),
      pendingArchiveBrokenOn: DailyComboDates.parseYmd(
        row['pending_archive_broken_on'] as String?,
      ),
      synced: true,
    );
  }
}
