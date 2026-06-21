import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/auth/firebase_user_id.dart';
import '../../../core/bootstrap/app_bootstrap.dart';
import '../domain/achievement_progress_state.dart';
import '../domain/achievement_trail_id.dart';

/// Sincronização das conquistas com o Supabase.
class AchievementSupabaseRepository {
  AchievementSupabaseRepository({SupabaseClient? client})
      : _client = client ?? AppBootstrap.supabase;

  final SupabaseClient _client;

  static const _progressTable = 'achievement_progress';
  static const _eventsTable = 'achievement_events';

  String? get _userId => currentFirebaseUserId();

  Future<AchievementProgressState?> fetchProgress() async {
    final userId = _userId;
    if (userId == null) return null;

    try {
      final row = await _client
          .from(_progressTable)
          .select()
          .eq('user_id', userId)
          .maybeSingle();
      if (row == null) return null;

      final map = Map<String, dynamic>.from(row);
      final pointsRaw = map['points_by_trail'];
      final points = <AchievementTrailId, int>{};
      if (pointsRaw is Map) {
        for (final entry in pointsRaw.entries) {
          final trail = AchievementTrailIdX.tryParse(entry.key as String?);
          if (trail == null) continue;
          points[trail] = entry.value is int
              ? entry.value as int
              : int.tryParse('${entry.value}') ?? 0;
        }
      }

      final events = await _client
          .from(_eventsTable)
          .select('event_key')
          .eq('user_id', userId);

      final keys = <String>{};
      for (final item in events as List<dynamic>) {
        if (item is Map) {
          final key = item['event_key'] as String?;
          if (key != null && key.isNotEmpty) keys.add(key);
        }
      }

      final medalsRaw = map['unlocked_medal_ids'];
      final medals = <String>{};
      if (medalsRaw is List) {
        for (final item in medalsRaw) {
          if (item is String && item.isNotEmpty) medals.add(item);
        }
      }

      return AchievementProgressState(
        pointsByTrail: points,
        recordedEventKeys: keys,
        unlockedMedalIds: medals,
        synced: true,
      );
    } catch (e, st) {
      debugPrint('AchievementSupabaseRepository.fetchProgress: $e\n$st');
      return null;
    }
  }

  Future<void> upsertProgress(AchievementProgressState state) async {
    final userId = _userId;
    if (userId == null) {
      throw StateError('Usuário não autenticado no Supabase.');
    }

    await _client.from(_progressTable).upsert({
      'user_id': userId,
      'points_by_trail': {
        for (final entry in state.pointsByTrail.entries)
          entry.key.storageKey: entry.value,
      },
      'unlocked_medal_ids': state.unlockedMedalIds.toList(growable: false),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  Future<void> insertEvents(
    AchievementProgressState state,
    AchievementProgressState previous,
  ) async {
    final userId = _userId;
    if (userId == null) return;

    final newKeys = state.recordedEventKeys.difference(previous.recordedEventKeys);
    if (newKeys.isEmpty) return;

    final rows = <Map<String, dynamic>>[];
    for (final key in newKeys) {
      final trail = _trailForEventKey(key);
      if (trail == null) continue;
      rows.add({
        'user_id': userId,
        'trail_id': trail.storageKey,
        'event_key': key,
        'points': 1,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });
    }

    if (rows.isEmpty) return;

    await _client.from(_eventsTable).upsert(
          rows,
          onConflict: 'user_id,event_key',
        );
  }

  AchievementTrailId? _trailForEventKey(String key) {
    if (key.startsWith('tasks_created:')) {
      return AchievementTrailId.tasksCreated;
    }
    if (key.startsWith('unfinished_tasks:')) {
      return AchievementTrailId.unfinishedTasks;
    }
    if (key.startsWith('task_advance:')) {
      return AchievementTrailId.taskAdvances;
    }
    if (key.startsWith('days_completed:')) {
      return AchievementTrailId.daysCompleted;
    }
    if (key.startsWith('pilhas_created:')) {
      return AchievementTrailId.pilhasCreated;
    }
    if (key.startsWith('magic_input:')) {
      return AchievementTrailId.magicInput;
    }
    return null;
  }
}
