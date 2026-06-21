import 'package:flutter/material.dart';

import '../../../../app/theme/tasker_colors.dart';
import '../../domain/achievement_medal.dart';
import 'achievement_hexagon_placeholder.dart';

/// Uma medalha na trilha — hexágono reservado, título e marco (ocultos até desbloquear).
class AchievementMedalTile extends StatelessWidget {
  const AchievementMedalTile({
    super.key,
    required this.medal,
    required this.unlocked,
  });

  final AchievementMedal medal;
  final bool unlocked;

  static const _hiddenLabel = '???';

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AchievementHexagonPlaceholder(unlocked: unlocked),
        const SizedBox(height: 10),
        Text(
          unlocked ? medal.title : _hiddenLabel,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            height: 1.25,
            color: unlocked
                ? TaskerColors.primaryText
                : TaskerColors.mutedText,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          unlocked ? medal.milestoneLabel : _hiddenLabel,
          textAlign: TextAlign.center,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 11,
            height: 1.3,
            color: unlocked
                ? TaskerColors.secondaryText.withValues(alpha: 0.95)
                : TaskerColors.mutedText.withValues(alpha: 0.85),
          ),
        ),
      ],
    );
  }
}
