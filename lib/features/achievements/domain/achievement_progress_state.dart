import 'package:flutter/foundation.dart';

import 'achievement_catalog.dart';
import 'achievement_trail_id.dart';

/// Estado persistido das conquistas — pontos só aumentam, nunca diminuem.
@immutable
class AchievementProgressState {
  const AchievementProgressState({
    this.pointsByTrail = const {},
    this.recordedEventKeys = const {},
    this.unlockedMedalIds = const {},
    this.synced = true,
  });

  final Map<AchievementTrailId, int> pointsByTrail;
  final Set<String> recordedEventKeys;
  final Set<String> unlockedMedalIds;
  final bool synced;

  int pointsFor(AchievementTrailId trail) => pointsByTrail[trail] ?? 0;

  bool isMedalUnlocked(String medalId) => unlockedMedalIds.contains(medalId);

  AchievementProgressState copyWith({
    Map<AchievementTrailId, int>? pointsByTrail,
    Set<String>? recordedEventKeys,
    Set<String>? unlockedMedalIds,
    bool? synced,
  }) {
    return AchievementProgressState(
      pointsByTrail: pointsByTrail ?? this.pointsByTrail,
      recordedEventKeys: recordedEventKeys ?? this.recordedEventKeys,
      unlockedMedalIds: unlockedMedalIds ?? this.unlockedMedalIds,
      synced: synced ?? this.synced,
    );
  }

  Map<String, dynamic> toLocalJson() => {
        'points_by_trail': {
          for (final entry in pointsByTrail.entries)
            entry.key.storageKey: entry.value,
        },
        'recorded_event_keys': recordedEventKeys.toList(growable: false),
        'unlocked_medal_ids': unlockedMedalIds.toList(growable: false),
        'synced': synced,
      };

  factory AchievementProgressState.fromLocalJson(Map<String, dynamic> json) {
    final pointsRaw = json['points_by_trail'];
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

    final keysRaw = json['recorded_event_keys'];
    final keys = <String>{};
    if (keysRaw is List) {
      for (final item in keysRaw) {
        if (item is String && item.isNotEmpty) keys.add(item);
      }
    }

    final medalsRaw = json['unlocked_medal_ids'];
    final medals = <String>{};
    if (medalsRaw is List) {
      for (final item in medalsRaw) {
        if (item is String && item.isNotEmpty) medals.add(item);
      }
    }

    return AchievementProgressState(
      pointsByTrail: points,
      recordedEventKeys: keys,
      unlockedMedalIds: medals.isNotEmpty
          ? medals
          : AchievementCatalog.unlockedMedalIds(
              points,
              recordedEventKeys: keys,
            ),
      synced: json['synced'] as bool? ?? true,
    );
  }

  /// Mescla local e remoto — união de eventos; pontos = máximo por trilha.
  static AchievementProgressState merge(
    AchievementProgressState local,
    AchievementProgressState remote,
  ) {
    final keys = {...local.recordedEventKeys, ...remote.recordedEventKeys};
    final points = <AchievementTrailId, int>{};
    for (final trail in AchievementTrailId.values) {
      points[trail] = mathMax(
        local.pointsFor(trail),
        remote.pointsFor(trail),
      );
    }
    final unlocked = AchievementCatalog.unlockedMedalIds(
      points,
      recordedEventKeys: keys,
    );
    unlocked.addAll(local.unlockedMedalIds);
    unlocked.addAll(remote.unlockedMedalIds);

    return AchievementProgressState(
      pointsByTrail: points,
      recordedEventKeys: keys,
      unlockedMedalIds: unlocked,
      synced: local.synced && remote.synced,
    );
  }
}

int mathMax(int a, int b) => a > b ? a : b;
