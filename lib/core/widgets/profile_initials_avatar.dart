import 'package:flutter/material.dart';

import '../../app/theme/tasker_colors.dart';

/// Iniciais a partir do nome exibido (até 2 letras).
String profileInitialsFromName(String name) {
  final parts =
      name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) {
    final word = parts.first;
    return word.length >= 2
        ? word.substring(0, 2).toUpperCase()
        : word[0].toUpperCase();
  }
  return '${parts.first[0]}${parts[1][0]}'.toUpperCase();
}

/// Avatar circular com iniciais — home, perfil e pré-visualização.
class ProfileInitialsAvatar extends StatelessWidget {
  const ProfileInitialsAvatar({
    super.key,
    required this.initials,
    this.size = 48,
  });

  final String initials;
  final double size;

  @override
  Widget build(BuildContext context) {
    final fontSize = size * 0.34;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: TaskerColors.primary.withValues(alpha: 0.12),
        shape: BoxShape.circle,
        border: Border.all(
          color: TaskerColors.primary.withValues(alpha: 0.25),
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
          color: TaskerColors.primary,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

/// Avatar do usuário — foto da conta (Google) ou iniciais como fallback.
class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({
    super.key,
    required this.initials,
    this.imageUrl,
    this.size = 48,
  });

  final String initials;
  final String? imageUrl;
  final double size;

  @override
  Widget build(BuildContext context) {
    final url = imageUrl?.trim();
    if (url == null || url.isEmpty) {
      return ProfileInitialsAvatar(initials: initials, size: size);
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: TaskerColors.primary.withValues(alpha: 0.25),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.network(
        url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) =>
            ProfileInitialsAvatar(initials: initials, size: size),
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return ProfileInitialsAvatar(initials: initials, size: size);
        },
      ),
    );
  }
}
