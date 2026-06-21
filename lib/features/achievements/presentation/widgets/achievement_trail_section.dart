import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../app/theme/tasker_card_style.dart';
import '../../../../app/theme/tasker_colors.dart';
import '../../domain/achievement_trail.dart';
import '../state/achievement_controller.dart';
import 'achievement_medal_tile.dart';

/// Seção de uma trilha — resumo + grade vertical de medalhas.
class AchievementTrailSection extends StatelessWidget {
  const AchievementTrailSection({
    super.key,
    required this.trail,
  });

  final AchievementTrail trail;

  static const _medalsPerRow = 3;
  static const _medalSpacing = 12.0;
  static const _medalRunSpacing = 20.0;

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AchievementController>();
    final points = controller.pointsForTrail(trail.id);

    return Material(
      color: TaskerCardStyle.background,
      elevation: TaskerCardStyle.elevation,
      shadowColor: TaskerCardStyle.shadowColor,
      surfaceTintColor: Colors.transparent,
      borderRadius: BorderRadius.circular(TaskerCardStyle.borderRadius),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: TaskerCardStyle.contentPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    trail.title,
                    style: TaskerCardStyle.sectionTitle,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '$points pts',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: TaskerColors.primary.withValues(alpha: 0.9),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              trail.summary,
              style: TextStyle(
                fontSize: 13.5,
                height: 1.45,
                color: TaskerColors.secondaryText.withValues(alpha: 0.95),
              ),
            ),
            const SizedBox(height: TaskerCardStyle.sectionHeaderGap),
            LayoutBuilder(
              builder: (context, constraints) {
                final itemWidth = (constraints.maxWidth -
                        _medalSpacing * (_medalsPerRow - 1)) /
                    _medalsPerRow;

                return Wrap(
                  spacing: _medalSpacing,
                  runSpacing: _medalRunSpacing,
                  children: [
                    for (final medal in trail.medals)
                      SizedBox(
                        width: itemWidth,
                        child: AchievementMedalTile(
                          medal: medal,
                          unlocked: controller.isMedalUnlocked(medal.id),
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
