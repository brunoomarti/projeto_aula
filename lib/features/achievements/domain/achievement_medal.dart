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
    this.flavorText,
    this.unlockEventKey,
    this.unlockEventKeyPrefix,
  });

  final String id;
  final AchievementTrailId trail;

  /// Pontos acumulados na trilha necessários para desbloquear.
  final int threshold;
  final String title;

  /// Marco customizado (trilhas com regras únicas por medalha).
  final String? customMilestoneLabel;

  /// Frase de sabor exibida após desbloquear (conquistas lendárias).
  final String? flavorText;

  /// Desbloqueio por evento exato no ledger (conquistas lendárias).
  final String? unlockEventKey;

  /// Desbloqueio quando qualquer evento começa com este prefixo.
  final String? unlockEventKeyPrefix;

  /// Marco curto exibido no subtítulo após desbloquear.
  String get milestoneLabel =>
      customMilestoneLabel ??
      AchievementMilestoneLabel.forMedal(trail: trail, threshold: threshold);
}
