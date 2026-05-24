import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../app/theme/tasker_colors.dart';

/// Cabeçalho da home — equivalente a [tasker-main/src/view/components/userDock.jsx].
class UserDock extends StatelessWidget {
  const UserDock({
    super.key,
    this.displayName,
    required this.onProfileTap,
    required this.onAddTaskTap,
  });

  final String? displayName;
  final VoidCallback onProfileTap;
  final VoidCallback onAddTaskTap;

  @override
  Widget build(BuildContext context) {
    final name = (displayName != null && displayName!.trim().isNotEmpty)
        ? displayName!.trim()
        : 'Usuário';

    final dateLabel = DateFormat("d 'de' MMMM", 'pt_BR').format(DateTime.now());

    return Padding(
      padding: const EdgeInsets.only(bottom: 40),
      child: SizedBox(
        height: 56,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned(
              left: 0,
              child: _DockCircleIconButton(
                onPressed: onProfileTap,
                tooltip: 'Meu perfil',
                icon: Icons.account_circle_outlined,
                iconColor: TaskerColors.mutedText,
              ),
            ),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    color: TaskerColors.primaryText,
                  ),
                  textAlign: TextAlign.center,
                ),
                Text(
                  dateLabel,
                  style: const TextStyle(
                    fontSize: 14,
                    color: TaskerColors.secondaryText,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
            Positioned(
              right: 0,
              child: _DockCircleIconButton(
                onPressed: onAddTaskTap,
                tooltip: 'Nova tarefa',
                icon: Icons.add_circle_outline,
                iconColor: TaskerColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Ícone em círculo branco com padding uniforme (perfil e nova tarefa).
class _DockCircleIconButton extends StatelessWidget {
  const _DockCircleIconButton({
    required this.onPressed,
    required this.tooltip,
    required this.icon,
    required this.iconColor,
  });

  static const double _iconSize = 30;
  static const double _padding = 6;
  static const double _circleSize = _iconSize + _padding * 2;

  final VoidCallback onPressed;
  final String tooltip;
  final IconData icon;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: 48,
            height: 48,
            child: Center(
              child: Container(
                width: _circleSize,
                height: _circleSize,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                padding: const EdgeInsets.all(_padding),
                child: Icon(icon, size: _iconSize, color: iconColor),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
