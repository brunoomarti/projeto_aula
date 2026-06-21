import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:provider/provider.dart';

import '../../../../app/theme/tasker_colors.dart';
import '../../../../core/layout/tasker_breakpoints.dart';
import '../../../../core/widgets/tasker_floating_page_shell.dart';
import '../../domain/achievement_catalog.dart';
import '../../../auth/presentation/auth_controller.dart';
import '../../../home/presentation/widgets/home_app_dock.dart';
import '../../../tasks/presentation/widgets/task_page_header.dart';
import '../../../tasks/presentation/widgets/task_section_card.dart';
import '../state/achievement_controller.dart';
import '../widgets/achievement_trail_section.dart';

/// Aba de conquistas — trilhas com medalhas e placeholders para ícones.
class AchievementsPage extends StatelessWidget {
  const AchievementsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final dockReserve = HomeAppDock.reservedHeight(context);
    final auth = context.watch<AuthController>();
    final controller = context.watch<AchievementController>();

    return ColoredBox(
      color: TaskerColors.appBackground,
      child: TaskerFloatingPageShell(
        headerReserve: TaskPageHeaderBar.reserveHeight(context),
        header: const TaskPageHeaderBar(
          title: 'Conquistas',
          showBack: false,
        ),
        bodyBuilder: (context, insets) {
          return LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final pagePadding = TaskerBreakpoints.pagePadding(width);

              if (!controller.isInitialized) {
                return const Center(child: CircularProgressIndicator());
              }

              if (auth.isGuest || !controller.isActive) {
                return SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    pagePadding.left,
                    insets.top,
                    pagePadding.right,
                    insets.bottom + dockReserve,
                  ),
                  child: TaskerResponsiveContent(
                    width: width,
                    child: TaskSectionCard(
                      title: 'Requer login',
                      icon: HugeIcons.strokeRoundedAward01,
                      child: Text(
                        'As conquistas e medalhas ficam disponíveis apenas '
                        'com uma conta logada. Faça login pelo perfil para '
                        'acompanhar seu progresso e desbloquear recompensas.',
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.45,
                          color: TaskerColors.secondaryText
                              .withValues(alpha: 0.95),
                        ),
                      ),
                    ),
                  ),
                );
              }

              return SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  pagePadding.left,
                  insets.top,
                  pagePadding.right,
                  insets.bottom + dockReserve,
                ),
                child: TaskerResponsiveContent(
                  width: width,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var i = 0; i < AchievementCatalog.trails.length; i++) ...[
                        if (i > 0) const SizedBox(height: 16),
                        AchievementTrailSection(
                          trail: AchievementCatalog.trails[i],
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
