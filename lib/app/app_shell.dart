import 'package:flutter/material.dart';

import '../features/dashboard/presentation/pages/dashboard_page.dart';
import '../features/home/presentation/pages/home_page.dart';
import '../features/profile/presentation/pages/profile_page.dart';
import 'widgets/app_dock.dart';

/// Shell principal: conteúdo + [AppDock] (equivalente a [tasker-main/src/Shell.jsx]).
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _currentIndex = 0;
  final _homeKey = GlobalKey<HomePageState>();
  final _dashboardKey = GlobalKey<DashboardPageState>();
  final _profileKey = GlobalKey<ProfilePageState>();

  void _goToTab(int index) {
    setState(() => _currentIndex = index);
    if (index == 0) {
      _homeKey.currentState?.reload();
    } else if (index == 1) {
      _dashboardKey.currentState?.reload();
    } else if (index == 2) {
      _profileKey.currentState?.reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: IndexedStack(
        index: _currentIndex,
        children: [
          HomePage(
            key: _homeKey,
            onOpenProfile: () => _goToTab(2),
          ),
          DashboardPage(key: _dashboardKey),
          ProfilePage(
            key: _profileKey,
            onNameSaved: () => _homeKey.currentState?.reload(),
          ),
        ],
      ),
      bottomNavigationBar: AppDock(
        currentIndex: _currentIndex,
        onDestinationSelected: _goToTab,
      ),
    );
  }
}
