import 'package:flutter/material.dart';

import '../layout/tasker_breakpoints.dart';
import '../layout/tasker_page_chrome.dart';
import 'tasker_glass_surface.dart';

/// Barra inferior flutuante — mesma altura e posição do [HomeAppDock].
class TaskerGlassFooterBar extends StatelessWidget {
  const TaskerGlassFooterBar({
    super.key,
    required this.child,
    this.barHeight = TaskerDockMetrics.barHeight,
  });

  final Widget child;
  final double barHeight;

  static double reserveHeight(BuildContext context) {
    return TaskerDockMetrics.reservedHeight(context);
  }

  @override
  Widget build(BuildContext context) {
    final bottomSafe = MediaQuery.paddingOf(context).bottom;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return Padding(
          padding: EdgeInsets.fromLTRB(
            TaskerDockMetrics.horizontalInset,
            0,
            TaskerDockMetrics.horizontalInset,
            TaskerDockMetrics.bottomInset + bottomSafe,
          ),
          child: TaskerResponsiveContent(
            width: width,
            child: TaskerGlassSurface(
              shape: TaskerGlassShape.pill,
              height: barHeight,
              child: SizedBox(
                width: double.infinity,
                height: barHeight,
                child: child,
              ),
            ),
          ),
        );
      },
    );
  }
}
