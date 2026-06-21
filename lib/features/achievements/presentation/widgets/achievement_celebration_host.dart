import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../domain/achievement_catalog.dart';
import '../../domain/achievement_medal.dart';
import '../pages/achievement_unlock_celebration.dart';
import '../state/achievement_controller.dart';

/// Overlay global — uma sessão contínua para todas as conquistas na fila.
class AchievementCelebrationHost extends StatefulWidget {
  const AchievementCelebrationHost({super.key});

  @override
  State<AchievementCelebrationHost> createState() =>
      _AchievementCelebrationHostState();
}

class _AchievementCelebrationHostState extends State<AchievementCelebrationHost> {
  List<AchievementMedal>? _sessionMedals;

  void _captureSession(AchievementController controller) {
    if (_sessionMedals != null) return;
    if (controller.celebrationQueue.isEmpty) return;

    final medals = <AchievementMedal>[];
    for (final id in controller.celebrationQueue) {
      final medal = AchievementCatalog.medalsById[id];
      if (medal != null) {
        medals.add(medal);
      } else {
        controller.acknowledgeCelebration();
      }
    }
    if (medals.isNotEmpty) {
      _sessionMedals = medals;
    }
  }

  void _finishSession(AchievementController controller) {
    while (controller.celebrationQueue.isNotEmpty) {
      controller.acknowledgeCelebration();
    }
    _sessionMedals = null;
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AchievementController>();
    if (!controller.isActive) {
      _sessionMedals = null;
      return const SizedBox.shrink();
    }

    _captureSession(controller);
    final medals = _sessionMedals;
    if (medals == null || medals.isEmpty) return const SizedBox.shrink();

    return Positioned.fill(
      child: AchievementUnlockCelebration(
        key: ValueKey(medals.map((m) => m.id).join(',')),
        medals: medals,
        onFinished: () => _finishSession(controller),
      ),
    );
  }
}
