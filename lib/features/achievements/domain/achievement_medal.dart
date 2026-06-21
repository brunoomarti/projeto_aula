import 'package:flutter/foundation.dart';

import 'achievement_milestone_label.dart';
import 'achievement_trail_id.dart';

/// Uma medalha dentro de uma trilha de conquistas.
@immutable
class AchievementMedal {
  const AchievementMedal({
    required this.id,
    required this.trail,
    required this.threshold,
    required this.title,
    this.customMilestoneLabel,
  });

  final String id;
  final AchievementTrailId trail;

  /// Pontos acumulados na trilha necessários para desbloquear.
  final int threshold;
  final String title;

  /// Marco customizado (trilhas com regras únicas por medalha).
  final String? customMilestoneLabel;

  /// Marco curto exibido no subtítulo após desbloquear.
  String get milestoneLabel =>
      customMilestoneLabel ??
      AchievementMilestoneLabel.forMedal(trail: trail, threshold: threshold);
}
