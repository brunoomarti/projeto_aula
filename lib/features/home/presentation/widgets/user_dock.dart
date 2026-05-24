import 'package:flutter/material.dart';

import '../../../../app/theme/tasker_colors.dart';
import '../../../../core/widgets/profile_initials_avatar.dart';
import '../utils/selected_day_label.dart';

/// Cabeçalho da home — equivalente a [tasker-main/src/view/components/userDock.jsx].
class UserDock extends StatelessWidget {
  const UserDock({
    super.key,
    this.displayName,
    required this.selectedDate,
    required this.onProfileTap,
  });

  final String? displayName;
  final DateTime selectedDate;
  final VoidCallback onProfileTap;

  static const double _sideButtonSize = 56;
  static const double _avatarSize = 52;

  @override
  Widget build(BuildContext context) {
    final name = (displayName != null && displayName!.trim().isNotEmpty)
        ? displayName!.trim()
        : 'Usuário';

    final dateLabel = SelectedDayLabel.format(selectedDate);
    final initials = profileInitialsFromName(name);

    return Padding(
      padding: EdgeInsets.zero,
      child: SizedBox(
        height: _sideButtonSize,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned(
              left: 0,
              child: _DockProfileButton(
                initials: initials,
                onPressed: onProfileTap,
                size: _sideButtonSize,
                avatarSize: _avatarSize,
              ),
            ),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 20,
                    height: 1.2,
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
            const Positioned(
              right: 0,
              child: SizedBox(
                width: _sideButtonSize,
                height: _sideButtonSize,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DockProfileButton extends StatelessWidget {
  const _DockProfileButton({
    required this.initials,
    required this.onPressed,
    required this.size,
    required this.avatarSize,
  });

  final String initials;
  final VoidCallback onPressed;
  final double size;
  final double avatarSize;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Meu perfil',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: size,
            height: size,
            child: Center(
              child: ProfileInitialsAvatar(
                initials: initials,
                size: avatarSize,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
