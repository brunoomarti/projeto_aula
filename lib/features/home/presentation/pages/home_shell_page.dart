import 'package:flutter/material.dart';

import '../../../achievements/presentation/pages/achievements_page.dart';
import '../widgets/home_app_dock.dart';
import 'home_page.dart';

enum HomeShellTab { home, achievements }

/// Shell com abas fixas — dock sempre visível; troca com slide horizontal.
class HomeShellPage extends StatefulWidget {
  const HomeShellPage({super.key});

  @override
  State<HomeShellPage> createState() => HomeShellPageState();
}

class HomeShellPageState extends State<HomeShellPage> {
  static const _tabSlideDuration = Duration(milliseconds: 280);
  static const _tabSlideCurve = Curves.easeOutCubic;

  HomeShellTab _tab = HomeShellTab.home;
  final GlobalKey<HomePageState> _homeKey = GlobalKey();
  final PageController _pageController = PageController();

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onHomeChromeChanged() {
    if (mounted) setState(() {});
  }

  void _goToTab(HomeShellTab tab, {bool openCreateMenuOnArrival = false}) {
    if (_tab == tab) {
      if (openCreateMenuOnArrival) {
        _homeKey.currentState?.openCreateMenuFromShell();
      }
      return;
    }

    if (!openCreateMenuOnArrival) {
      _homeKey.currentState?.closeShellOverlays();
    }

    setState(() => _tab = tab);
    _pageController
        .animateToPage(
          tab.index,
          duration: _tabSlideDuration,
          curve: _tabSlideCurve,
        )
        .then((_) {
      if (!mounted) return;
      if (openCreateMenuOnArrival && _tab == HomeShellTab.home) {
        _homeKey.currentState?.openCreateMenuFromShell();
      }
    });
  }

  void _selectHome() => _goToTab(HomeShellTab.home);

  void _selectAchievements() => _goToTab(HomeShellTab.achievements);

  void _onAddTap() {
    if (_tab != HomeShellTab.home) {
      _goToTab(HomeShellTab.home, openCreateMenuOnArrival: true);
      return;
    }
    _homeKey.currentState?.toggleCreateMenuFromShell();
  }

  bool get _canPop {
    if (_tab == HomeShellTab.achievements) return false;
    return _homeKey.currentState?.canPopShell ?? true;
  }

  void _onPopInvoked(bool didPop) {
    if (didPop) return;
    if (_tab == HomeShellTab.achievements) {
      _goToTab(HomeShellTab.home);
      return;
    }
    if (_homeKey.currentState?.handleSystemBack() ?? false) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final homeState = _homeKey.currentState;

    return PopScope(
      canPop: _canPop,
      onPopInvokedWithResult: (didPop, _) => _onPopInvoked(didPop),
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        body: Stack(
          fit: StackFit.expand,
          children: [
            PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              onPageChanged: (index) {
                final next = HomeShellTab.values[index];
                if (_tab == next) return;
                _homeKey.currentState?.closeShellOverlays();
                setState(() => _tab = next);
              },
              children: [
                HomePage(
                  key: _homeKey,
                  onShellChromeChanged: _onHomeChromeChanged,
                ),
                const AchievementsPage(),
              ],
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: HomeAppDock(
                homeSelected: _tab == HomeShellTab.home,
                achievementsSelected: _tab == HomeShellTab.achievements,
                onHomeTap: _selectHome,
                onAchievementsTap: _selectAchievements,
                onAddTap: _onAddTap,
                addMenuOpen: _tab == HomeShellTab.home &&
                    (homeState?.isCreateMenuOpen ?? false),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
