import 'package:flutter/material.dart';

import '../../../../app/theme/tasker_colors.dart';
import '../../../../core/widgets/profile_initials_avatar.dart';
import '../utils/selected_day_label.dart';

/// Primeiro nome para saudação no cabeçalho.
String homeGreetingFirstName(String displayName) {
  final parts =
      displayName.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
  final first = parts.isEmpty ? null : parts.first;
  if (first == null || first.isEmpty) return 'Usuário';
  return first[0].toUpperCase() + first.substring(1);
}

/// Cabeçalho da home — equivalente a [tasker-main/src/view/components/userDock.jsx].
class UserDock extends StatelessWidget {
  const UserDock({
    super.key,
    this.displayName,
    this.avatarUrl,
    required this.selectedDate,
    required this.onProfileTap,
    this.dailyComboStreak = 0,
  });

  final String? displayName;
  final String? avatarUrl;
  final DateTime selectedDate;
  final VoidCallback onProfileTap;
  final int dailyComboStreak;

  static const double _rowHeight = 60;
  static const double _avatarSize = 52;

  @override
  Widget build(BuildContext context) {
    final name = (displayName != null && displayName!.trim().isNotEmpty)
        ? displayName!.trim()
        : 'Usuário';

    final greeting = 'Olá, ${homeGreetingFirstName(name)}';
    final dateLabel = SelectedDayLabel.format(selectedDate);
    final initials = profileInitialsFromName(name);

    return SizedBox(
      height: _rowHeight,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  greeting,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 26,
                    height: 1.15,
                    color: TaskerColors.petroleumDark,
                    letterSpacing: -0.3,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  dateLabel,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    height: 1.2,
                    color: TaskerColors.petroleumDark.withValues(alpha: 0.78),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _DockProfileButton(
            initials: initials,
            avatarUrl: avatarUrl,
            onPressed: onProfileTap,
            size: _avatarSize,
            avatarSize: _avatarSize,
            dailyComboStreak: dailyComboStreak,
          ),
        ],
      ),
    );
  }
}

class _DockProfileButton extends StatelessWidget {
  const _DockProfileButton({
    required this.initials,
    this.avatarUrl,
    required this.onPressed,
    required this.size,
    required this.avatarSize,
    required this.dailyComboStreak,
  });

  final String initials;
  final String? avatarUrl;
  final VoidCallback onPressed;
  final double size;
  final double avatarSize;
  final int dailyComboStreak;

  static const Color _flameOrange = Color(0xFFFF6B2C);

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: dailyComboStreak > 0
          ? 'Combo diário: $dailyComboStreak ${dailyComboStreak == 1 ? 'dia' : 'dias'}'
          : 'Combo diário: nenhum dia zerado ainda',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: size,
            height: size + 6,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.topCenter,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 0),
                  child: ProfileAvatar(
                    initials: initials,
                    imageUrl: avatarUrl,
                    size: avatarSize,
                  ),
                ),
                Positioned(
                  bottom: 0,
                  child: _DailyComboBadge(streak: dailyComboStreak),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DailyComboBadge extends StatelessWidget {
  const _DailyComboBadge({required this.streak});

  final int streak;

  @override
  Widget build(BuildContext context) {
    final flameColor = streak > 0
        ? _DockProfileButton._flameOrange
        : TaskerColors.mutedText;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        boxShadow: const [
          BoxShadow(
            color: Color(0x26000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(5, 2, 7, 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.local_fire_department_rounded,
              size: 14,
              color: flameColor,
            ),
            const SizedBox(width: 1),
            Text(
              '$streak',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                height: 1,
                color: TaskerColors.primaryText,
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
