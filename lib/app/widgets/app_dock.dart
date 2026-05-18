import 'package:flutter/material.dart';

import '../theme/tasker_colors.dart';

/// Item do dock inferior (espelha rotas do [tasker-main]).
class AppDockDestination {
  const AppDockDestination({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
}

/// Barra inferior fixa — equivalente a [tasker-main/src/view/components/navbar.jsx].
class AppDock extends StatelessWidget {
  const AppDock({
    super.key,
    required this.currentIndex,
    required this.onDestinationSelected,
    this.destinations = kAppDockDestinations,
  });

  final int currentIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<AppDockDestination> destinations;

  static const List<AppDockDestination> kAppDockDestinations = [
    AppDockDestination(
      icon: Icons.home_outlined,
      selectedIcon: Icons.home,
      label: 'Início',
    ),
    AppDockDestination(
      icon: Icons.dashboard_outlined,
      selectedIcon: Icons.dashboard,
      label: 'Concluídas',
    ),
    AppDockDestination(
      icon: Icons.person_outline,
      selectedIcon: Icons.person,
      label: 'Perfil',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    const primary = TaskerColors.primary;
    const muted = TaskerColors.mutedText;

    return Material(
      color: Colors.transparent,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: TaskerColors.dockBackground,
          border: const Border(top: BorderSide(color: TaskerColors.dockBorder)),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0A000000),
              blurRadius: 8,
              offset: Offset(0, -2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
          child: SafeArea(
            top: false,
            child: SizedBox(
              height: 64,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: List.generate(destinations.length, (index) {
                  final dest = destinations[index];
                  final selected = index == currentIndex;
                  return _DockItem(
                    icon: selected ? dest.selectedIcon : dest.icon,
                    label: dest.label,
                    selected: selected,
                    primaryColor: primary,
                    mutedColor: muted,
                    onTap: () => onDestinationSelected(index),
                  );
                }),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DockItem extends StatelessWidget {
  const _DockItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.primaryColor,
    required this.mutedColor,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final Color primaryColor;
  final Color mutedColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? primaryColor : mutedColor;

    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(50),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Icon(icon, color: color, size: 28),
        ),
      ),
    );
  }
}
