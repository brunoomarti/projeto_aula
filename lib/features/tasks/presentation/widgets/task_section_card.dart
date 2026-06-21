import 'package:flutter/material.dart';

import '../../../../app/theme/tasker_card_style.dart';
import '../../../../app/theme/tasker_colors.dart';
import '../../../../core/icons/tasker_icon.dart';
import '../../../../core/icons/tasker_icon_glyph.dart';

/// Shell visual de card de seção — padding, raio, sombra e fundo unificados.
class TaskSectionCardShell extends StatelessWidget {
  const TaskSectionCardShell({
    super.key,
    required this.child,
    this.onTap,
    this.padding,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: padding ?? TaskerCardStyle.contentPadding,
      child: child,
    );

    return Material(
      color: TaskerCardStyle.background,
      elevation: TaskerCardStyle.elevation,
      shadowColor: TaskerCardStyle.shadowColor,
      surfaceTintColor: Colors.transparent,
      shape: TaskerCardStyle.shape,
      clipBehavior: Clip.antiAlias,
      child: onTap == null
          ? content
          : InkWell(
              onTap: onTap,
              splashColor: TaskerCardStyle.splashColor,
              highlightColor: TaskerCardStyle.highlightColor,
              child: content,
            ),
    );
  }
}

/// Card de seção com título e ícone — formulário e detalhes.
class TaskSectionCard extends StatelessWidget {
  const TaskSectionCard({
    super.key,
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final TaskerIconGlyph icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TaskSectionCardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              TaskerIcon(icon: icon, size: 20, color: TaskerColors.primary),
              const SizedBox(width: 8),
              Text(title, style: TaskerCardStyle.sectionTitle),
            ],
          ),
          const SizedBox(height: TaskerCardStyle.sectionHeaderGap),
          child,
        ],
      ),
    );
  }
}

/// Tile de ação com ícone, textos e trailing — toggles e status.
class TaskSectionActionTile extends StatelessWidget {
  const TaskSectionActionTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.trailing,
    this.active = false,
    this.loading = false,
    this.onTap,
  });

  final TaskerIconGlyph icon;
  final String title;
  final String subtitle;
  final Widget trailing;
  final bool active;
  final bool loading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return TaskSectionCardShell(
      onTap: loading ? null : onTap,
      child: Row(
        children: [
          Container(
            width: TaskerCardStyle.actionIconBoxSize,
            height: TaskerCardStyle.actionIconBoxSize,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: active
                  ? TaskerColors.primary.withValues(alpha: 0.12)
                  : TaskerCardStyle.actionIconInactiveBackground,
              borderRadius:
                  BorderRadius.circular(TaskerCardStyle.actionIconBoxRadius),
            ),
            child: loading
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : TaskerIcon(
                    icon: icon,
                    color: active ? TaskerColors.primary : TaskerColors.mutedText,
                    size: 26,
                  ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TaskerCardStyle.actionTitle),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TaskerCardStyle.actionSubtitle.copyWith(
                    color: TaskerColors.secondaryText.withValues(alpha: 0.9),
                  ),
                ),
              ],
            ),
          ),
          trailing,
        ],
      ),
    );
  }
}
