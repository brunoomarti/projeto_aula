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
              child: IconButton(
                onPressed: onProfileTap,
                tooltip: 'Meu perfil',
                icon: const Icon(
                  Icons.account_circle_outlined,
                  size: 48,
                  color: TaskerColors.mutedText,
                ),
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
              child: IconButton(
                onPressed: onAddTaskTap,
                tooltip: 'Nova tarefa',
                icon: const Icon(
                  Icons.add_circle_outline,
                  size: 32,
                  color: TaskerColors.primary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
