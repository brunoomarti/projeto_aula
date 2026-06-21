import 'package:flutter/material.dart';

import 'package:hugeicons/hugeicons.dart';

import '../../core/icons/tasker_icon.dart';
import '../../core/layout/tasker_breakpoints.dart';
import '../theme/tasker_colors.dart';

/// Item do dock inferior (espelha rotas do [tasker-main]).
class AppDockDestination {
  const AppDockDestination({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });

  final List<List<dynamic>> icon;
  final List<List<dynamic>> selectedIcon;
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
      icon: HugeIcons.strokeRoundedHome01,
      selectedIcon: HugeIcons.strokeRoundedHome03,
      label: 'Início',
    ),
    AppDockDestination(
      icon: HugeIcons.strokeRoundedUser,
      selectedIcon: HugeIcons.strokeRoundedUser,
      label: 'Perfil',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    const primary = TaskerColors.primary;
    const muted = TaskerColors.mutedText;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final isWide = TaskerBreakpoints.isWide(width);
        final barHeight = isWide ? 72.0 : 64.0;

        return Material(
          color: Colors.transparent,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: TaskerColors.dockBackground,
              border: const Border(
                top: BorderSide(color: TaskerColors.dockBorder),
              ),
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
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(12)),
              child: SafeArea(
                top: false,
                child: SizedBox(
                  height: barHeight,
                  child: TaskerResponsiveContent(
                    width: width,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: List.generate(destinations.length, (index) {
                        final dest = destinations[index];
                        final selected = index == currentIndex;
                        return _DockItem(
                          icon: selected ? dest.selectedIcon : dest.icon,
                          label: dest.label,
                          selected: selected,
                          showLabel: isWide,
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
          ),
        );
      },
    );
  }
}

class _DockItem extends StatelessWidget {
  const _DockItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.showLabel,
    required this.primaryColor,
    required this.mutedColor,
    required this.onTap,
  });

  final List<List<dynamic>> icon;
  final String label;
  final bool selected;
  final bool showLabel;
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
        borderRadius: BorderRadius.circular(showLabel ? 12 : 50),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: showLabel ? 24 : 20,
            vertical: showLabel ? 8 : 10,
          ),
          child: showLabel
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AppHugeIcon(icon: icon, color: color, size: 26),
                    const SizedBox(height: 4),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight:
                            selected ? FontWeight.w600 : FontWeight.w500,
                        color: color,
                        height: 1.1,
                      ),
                    ),
                  ],
                )
              : AppHugeIcon(icon: icon, color: color, size: 28),
        ),
      ),
    );
  }
}
