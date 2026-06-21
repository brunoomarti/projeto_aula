import 'package:flutter/foundation.dart';

import 'achievement_medal.dart';
import 'achievement_trail_id.dart';

/// Metadados de uma trilha (grupo de medalhas com a mesma lógica).
@immutable
class AchievementTrail {
  const AchievementTrail({
    required this.id,
    required this.title,
    required this.summary,
    required this.medals,
  });

  final AchievementTrailId id;
  final String title;

  /// Resumo exibido no topo da trilha na UI de conquistas.
  final String summary;
  final List<AchievementMedal> medals;
}
