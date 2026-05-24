import 'package:flutter/material.dart';

import '../../../../app/theme/tasker_colors.dart';
import '../../../../core/layout/tasker_breakpoints.dart';

/// Cabeçalho de telas de tarefa — botão voltar, título e subtítulo.
class TaskPageHeader extends StatelessWidget {
  const TaskPageHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.onBack,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final VoidCallback? onBack;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 20, 12),
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back_rounded),
            color: TaskerColors.primaryText,
            tooltip: 'Voltar',
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: TaskerColors.primaryText,
                    letterSpacing: -0.3,
                    height: 1.1,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 13,
                    color: TaskerColors.secondaryText,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// Barra superior branca com [TaskPageHeader] e divisor — uso em telas full-page.
class TaskPageHeaderBar extends StatelessWidget {
  const TaskPageHeaderBar({
    super.key,
    required this.title,
    required this.subtitle,
    this.onBack,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final VoidCallback? onBack;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.white,
      child: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TaskerResponsiveContent(
                  width: width,
                  child: TaskPageHeader(
                    title: title,
                    subtitle: subtitle,
                    onBack: onBack,
                    trailing: trailing,
                  ),
                ),
                TaskerResponsiveContent(
                  width: width,
                  child: const Divider(height: 1, color: Color(0x14000000)),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
