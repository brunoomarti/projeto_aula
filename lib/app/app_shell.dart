import 'package:flutter/material.dart';

import '../core/navigation/task_notification_router.dart';
import '../features/achievements/presentation/widgets/achievement_celebration_host.dart';
import '../features/home/presentation/pages/home_shell_page.dart';

/// Shell principal — abas do dock (início/conquistas); perfil e tarefas por [Navigator].
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      TaskNotificationRouter.tryOpenPendingTask();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      resizeToAvoidBottomInset: false,
      body: const Stack(
        fit: StackFit.expand,
        children: [
          HomeShellPage(),
          AchievementCelebrationHost(),
        ],
      ),
    );
  }
}
