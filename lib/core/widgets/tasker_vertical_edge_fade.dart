import 'package:flutter/material.dart';

import '../../app/theme/tasker_colors.dart';

/// Gradiente vertical que suaviza a transição entre conteúdo rolável e overlays.
class TaskerVerticalEdgeFade extends StatelessWidget {
  const TaskerVerticalEdgeFade({
    super.key,
    required this.top,
    this.softEdge = false,
    this.color,
  });

  final bool top;

  /// Fade suave (home/dock) em vez de opaco sólido.
  final bool softEdge;

  /// Cor base do fade — padrão [TaskerColors.appBackground].
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final bg = color ?? TaskerColors.appBackground;

    if (softEdge) {
      if (top) {
        return IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  bg.withValues(alpha: 0.96),
                  bg.withValues(alpha: 0.72),
                  bg.withValues(alpha: 0.28),
                  bg.withValues(alpha: 0),
                ],
                stops: const [0, 0.35, 0.68, 1],
              ),
            ),
          ),
        );
      }

      return IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [
                bg.withValues(alpha: 0.96),
                bg.withValues(alpha: 0.72),
                bg.withValues(alpha: 0.28),
                bg.withValues(alpha: 0),
              ],
              stops: const [0, 0.35, 0.68, 1],
            ),
          ),
        ),
      );
    }

    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: top ? Alignment.topCenter : Alignment.bottomCenter,
            end: top ? Alignment.bottomCenter : Alignment.topCenter,
            colors: [
              bg,
              bg.withValues(alpha: 0),
            ],
          ),
        ),
      ),
    );
  }
}

/// Fades superior/inferior que só aparecem quando há conteúdo oculto na rolagem.
class TaskerScrollEdgeFades extends StatefulWidget {
  const TaskerScrollEdgeFades({
    super.key,
    required this.child,
    required this.topFadeHeight,
    this.bottomFadeHeight,
    this.showTopFade = true,
    this.showBottomFade = true,
    this.fadeColor,
  });

  final Widget child;
  final double topFadeHeight;
  final double? bottomFadeHeight;
  final bool showTopFade;
  final bool showBottomFade;
  final Color? fadeColor;

  @override
  State<TaskerScrollEdgeFades> createState() => _TaskerScrollEdgeFadesState();
}

class _TaskerScrollEdgeFadesState extends State<TaskerScrollEdgeFades> {
  final ValueNotifier<bool> _showTopFade = ValueNotifier(false);
  final ValueNotifier<bool> _showBottomFade = ValueNotifier(false);

  static const _scrollEpsilon = 0.5;

  @override
  void initState() {
    super.initState();
    _scheduleInitialSync();
  }

  @override
  void dispose() {
    _showTopFade.dispose();
    _showBottomFade.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant TaskerScrollEdgeFades oldWidget) {
    super.didUpdateWidget(oldWidget);
    _scheduleInitialSync();
  }

  void _scheduleInitialSync({int attempt = 0}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final metrics = _scrollMetricsFromDescendants();
      if (metrics != null &&
          (metrics.maxScrollExtent > _scrollEpsilon || attempt >= 12)) {
        _syncFades(metrics);
        return;
      }
      if (attempt < 12) _scheduleInitialSync(attempt: attempt + 1);
    });
  }

  ScrollMetrics? _scrollMetricsFromDescendants() {
    ScrollMetrics? found;

    void visit(Element element) {
      if (found != null) return;
      if (element is StatefulElement && element.state is ScrollableState) {
        found = (element.state as ScrollableState).position;
        return;
      }
      element.visitChildren(visit);
    }

    (context as Element).visitChildren(visit);
    return found;
  }

  void _syncFades(ScrollMetrics metrics) {
    if (metrics.axis != Axis.vertical) return;

    final canScroll =
        metrics.maxScrollExtent > metrics.minScrollExtent + _scrollEpsilon;
    final showTop = widget.showTopFade &&
        canScroll &&
        metrics.pixels > metrics.minScrollExtent + _scrollEpsilon;
    final showBottom = widget.showBottomFade &&
        canScroll &&
        metrics.pixels < metrics.maxScrollExtent - _scrollEpsilon;

    if (showTop != _showTopFade.value) _showTopFade.value = showTop;
    if (showBottom != _showBottomFade.value) {
      _showBottomFade.value = showBottom;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomHeight = widget.bottomFadeHeight ?? widget.topFadeHeight;
    final fade = widget.fadeColor;

    return Stack(
      clipBehavior: Clip.none,
      fit: StackFit.expand,
      children: [
        NotificationListener<ScrollNotification>(
          onNotification: (notification) {
            _syncFades(notification.metrics);
            return false;
          },
          child: widget.child,
        ),
        ValueListenableBuilder<bool>(
          valueListenable: _showTopFade,
          builder: (context, visible, _) {
            if (!visible) return const SizedBox.shrink();
            return Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: widget.topFadeHeight,
              child: TaskerVerticalEdgeFade(
                top: true,
                softEdge: true,
                color: fade,
              ),
            );
          },
        ),
        ValueListenableBuilder<bool>(
          valueListenable: _showBottomFade,
          builder: (context, visible, _) {
            if (!visible) return const SizedBox.shrink();
            return Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              height: bottomHeight,
              child: TaskerVerticalEdgeFade(
                top: false,
                softEdge: true,
                color: fade,
              ),
            );
          },
        ),
      ],
    );
  }
}
