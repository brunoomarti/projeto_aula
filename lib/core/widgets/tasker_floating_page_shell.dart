import 'package:flutter/material.dart';

import 'tasker_glass_footer_bar.dart';
import 'tasker_vertical_edge_fade.dart';

/// Insets do conteúdo rolável sob header/footer flutuantes.
class TaskerFloatingPageInsets {
  const TaskerFloatingPageInsets({
    required this.top,
    required this.bottom,
  });

  final double top;
  final double bottom;
}

/// Layout com conteúdo rolável passando por trás do header/footer + fades.
class TaskerFloatingPageShell extends StatelessWidget {
  const TaskerFloatingPageShell({
    super.key,
    required this.headerReserve,
    required this.header,
    required this.bodyBuilder,
    this.footer,
    this.topFadeExtension = 56,
    this.bottomFadeExtension = 72,
    this.scrollEndInset = 12,
    this.showBottomFade = true,
  });

  /// Altura reservada do header (safe area + cápsula).
  final double headerReserve;
  final Widget header;
  final Widget Function(BuildContext context, TaskerFloatingPageInsets insets)
      bodyBuilder;
  final Widget? footer;

  /// Extensão do fade além da zona do header/footer (topo/base da tela).
  final double topFadeExtension;
  final double bottomFadeExtension;
  final double scrollEndInset;

  /// Habilita o fade inferior (visível só com conteúdo oculto abaixo).
  final bool showBottomFade;

  @override
  Widget build(BuildContext context) {
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    final footerReserve = footer != null
        ? TaskerGlassFooterBar.reserveHeight(context)
        : safeBottom;

    final topFadeHeight = headerReserve + topFadeExtension;
    final bottomFadeHeight = footer != null
        ? footerReserve + bottomFadeExtension
        : safeBottom + bottomFadeExtension;

    final insets = TaskerFloatingPageInsets(
      top: headerReserve + scrollEndInset,
      bottom: footer != null
          ? footerReserve + scrollEndInset
          : scrollEndInset + safeBottom,
    );

    return Stack(
      fit: StackFit.expand,
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          child: TaskerScrollEdgeFades(
            topFadeHeight: topFadeHeight,
            bottomFadeHeight: bottomFadeHeight,
            showBottomFade: showBottomFade,
            child: bodyBuilder(context, insets),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          child: header,
        ),
        if (footer != null)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: footer!,
          ),
      ],
    );
  }
}
