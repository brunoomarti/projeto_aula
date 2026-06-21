import 'achievement_catalog.dart';
import 'achievement_event.dart';
import 'achievement_progress_state.dart';
import 'achievement_trail_id.dart';

/// Aplica eventos ao estado — ledger append-only; pontos nunca diminuem.
abstract final class AchievementProgressApplier {
  static AchievementProgressState applyEvents(
    AchievementProgressState state,
    Iterable<AchievementEvent> events,
  ) {
    var next = state;

    for (final event in events) {
      if (next.recordedEventKeys.contains(event.eventKey)) continue;

      final points = Map<AchievementTrailId, int>.from(next.pointsByTrail);
      points[event.trail] =
          (points[event.trail] ?? 0) + event.points;

      final keys = {...next.recordedEventKeys, event.eventKey};
      final unlocked = AchievementCatalog.unlockedMedalIds(points);

      next = next.copyWith(
        pointsByTrail: points,
        recordedEventKeys: keys,
        unlockedMedalIds: unlocked,
        synced: false,
      );
    }

    return next;
  }
}
