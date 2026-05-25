import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Detecta arraste horizontal para alternar o dia selecionado na home.
///
/// Use em áreas sem outro gesto horizontal (header, espaços vazios, input
/// inativo) para não competir com swipe de tarefas ou scroll do calendário.
class HomeDaySwipeDetector extends StatefulWidget {
  const HomeDaySwipeDetector({
    super.key,
    required this.child,
    required this.onPreviousDay,
    required this.onNextDay,
    this.enabled = true,
  });

  final Widget child;
  final VoidCallback onPreviousDay;
  final VoidCallback onNextDay;
  final bool enabled;

  @override
  State<HomeDaySwipeDetector> createState() => _HomeDaySwipeDetectorState();
}

class _HomeDaySwipeDetectorState extends State<HomeDaySwipeDetector> {
  double _dragDelta = 0;

  static const _distanceThreshold = 52;
  static const _velocityThreshold = 280;

  void _resetDrag() => _dragDelta = 0;

  void _onDragUpdate(DragUpdateDetails details) {
    if (!widget.enabled) return;
    _dragDelta += details.delta.dx;
  }

  void _onDragEnd(DragEndDetails details) {
    if (!widget.enabled) {
      _resetDrag();
      return;
    }

    final velocity = details.primaryVelocity ?? 0;
    final swipedToNextDay =
        _dragDelta <= -_distanceThreshold || velocity <= -_velocityThreshold;
    final swipedToPreviousDay =
        _dragDelta >= _distanceThreshold || velocity >= _velocityThreshold;

    _resetDrag();

    if (swipedToNextDay) {
      HapticFeedback.lightImpact();
      widget.onNextDay();
    } else if (swipedToPreviousDay) {
      HapticFeedback.lightImpact();
      widget.onPreviousDay();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragStart: (_) => _resetDrag(),
      onHorizontalDragUpdate: _onDragUpdate,
      onHorizontalDragEnd: _onDragEnd,
      onHorizontalDragCancel: _resetDrag,
      child: widget.child,
    );
  }
}
