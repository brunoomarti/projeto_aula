import 'package:flutter/foundation.dart';

import 'achievement_trail_id.dart';

/// Evento imutável que incrementa pontos em uma trilha (ledger append-only).
@immutable
class AchievementEvent {
  const AchievementEvent({
    required this.trail,
    required this.eventKey,
    this.points = 1,
    this.recordedAt,
  });

  final AchievementTrailId trail;
  final String eventKey;
  final int points;
  final DateTime? recordedAt;
}
