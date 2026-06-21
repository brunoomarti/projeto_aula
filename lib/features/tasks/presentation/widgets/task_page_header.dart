import 'package:flutter/material.dart';

import 'package:tasker_project/core/icons/tasker_icon.dart';

import 'package:hugeicons/hugeicons.dart';

import '../../../../app/theme/tasker_colors.dart';
import '../../../../core/layout/tasker_breakpoints.dart';
import '../../../../core/layout/tasker_page_chrome.dart';
import '../../../../core/widgets/tasker_glass_surface.dart';

/// Cabeçalho flutuante — botão voltar em círculo de vidro + cápsula de título.
class TaskPageHeader extends StatelessWidget {
  const TaskPageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.onBack,
    this.trailing,
    this.showBack = true,
  });

  final String title;
  final String? subtitle;
  final VoidCallback? onBack;
  final Widget? trailing;

  /// Quando `false`, oculta o botão voltar (ex.: abas do shell).
  final bool showBack;

  static const horizontalInset = TaskerPageChrome.horizontalInset;
  static const backTitleGap = 10.0;
  static const titlePillMinHeight = TaskerPageChrome.pillHeight;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (showBack) ...[
          _GlassBackButton(onPressed: onBack),
          const SizedBox(width: backTitleGap),
        ],
        Expanded(
          child: TaskerGlassSurface(
            shape: TaskerGlassShape.pill,
            height: titlePillMinHeight,
            padding: EdgeInsets.fromLTRB(
              showBack ? 18 : 20,
              8,
              trailing != null ? 2 : 18,
              8,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: TaskerColors.primaryText,
                          letterSpacing: -0.25,
                          height: 1.15,
                        ),
                      ),
                      if (subtitle != null && subtitle!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: TaskerColors.secondaryText,
                            height: 1.2,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                ?trailing,
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _GlassBackButton extends StatelessWidget {
  const _GlassBackButton({required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return TaskerGlassSurface(
      shape: TaskerGlassShape.circle,
      width: TaskPageHeader.titlePillMinHeight,
      height: TaskPageHeader.titlePillMinHeight,
      child: Tooltip(
        message: 'Voltar',
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPressed,
            customBorder: const CircleBorder(),
            child: Center(
              child: AppHugeIcon(
                icon: HugeIcons.strokeRoundedArrowLeft01,
                color: onPressed == null
                    ? TaskerColors.mutedText
                    : TaskerColors.primaryText,
                size: 24,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Barra superior flutuante com [TaskPageHeader] — sem fundo sólido full-width.
class TaskPageHeaderBar extends StatelessWidget {
  const TaskPageHeaderBar({
    super.key,
    required this.title,
    this.subtitle,
    this.onBack,
    this.trailing,
    this.showBack = true,
  });

  final String title;
  final String? subtitle;
  final VoidCallback? onBack;
  final Widget? trailing;
  final bool showBack;

  static const topInset = 12.0;
  static const bottomInset = 12.0;

  /// Altura total ocupada pelo header flutuante (safe area + cápsula + respiro).
  static double reserveHeight(BuildContext context) {
    final safeTop = MediaQuery.paddingOf(context).top;
    return safeTop +
        topInset +
        TaskPageHeader.titlePillMinHeight +
        bottomInset;
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          return Padding(
            padding: const EdgeInsets.fromLTRB(0, topInset, 0, bottomInset),
            child: TaskerResponsiveContent(
              width: width,
              padding: const EdgeInsets.symmetric(
                horizontal: TaskPageHeader.horizontalInset,
              ),
              child: TaskPageHeader(
                title: title,
                subtitle: subtitle,
                onBack: onBack,
                trailing: trailing,
                showBack: showBack,
              ),
            ),
          );
        },
      ),
    );
  }
}
