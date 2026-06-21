import 'dart:async';

import 'package:flutter/material.dart';

/// Auto-scroll da lista enquanto uma tarefa está sendo arrastada perto das bordas.
class TaskDragScrollScope extends StatefulWidget {
  const TaskDragScrollScope({
    super.key,
    required this.scrollController,
    required this.viewportKey,
    required this.child,
  });

  final ScrollController scrollController;
  final GlobalKey viewportKey;
  final Widget child;

  static TaskDragScrollScopeState? maybeOf(BuildContext context) {
    return context
        .findAncestorStateOfType<TaskDragScrollScopeState>();
  }

  @override
  State<TaskDragScrollScope> createState() => TaskDragScrollScopeState();
}

class TaskDragScrollScopeState extends State<TaskDragScrollScope> {
  static const edgeThreshold = 88.0;
  static const maxScrollSpeed = 22.0;

  Timer? _autoScrollTimer;
  double _scrollVelocity = 0;

  void handleDragPosition(Offset globalPosition) {
    final box =
        widget.viewportKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) {
      stopAutoScroll();
      return;
    }

    final local = box.globalToLocal(globalPosition);
    final height = box.size.height;

    double velocity = 0;
    if (local.dy < edgeThreshold) {
      velocity = -_speedForDistance(local.dy, edgeThreshold);
    } else if (local.dy > height - edgeThreshold) {
      velocity = _speedForDistance(height - local.dy, edgeThreshold);
    }

    if (velocity == 0) {
      stopAutoScroll();
      return;
    }

    _scrollVelocity = velocity;
    _autoScrollTimer ??= Timer.periodic(const Duration(milliseconds: 16), (_) {
      _tickScroll();
    });
  }

  double _speedForDistance(double distanceFromEdge, double threshold) {
    final t = (1 - (distanceFromEdge / threshold).clamp(0.0, 1.0));
    return maxScrollSpeed * t * t;
  }

  void _tickScroll() {
    if (!widget.scrollController.hasClients) return;

    final position = widget.scrollController.position;
    final next = (position.pixels + _scrollVelocity)
        .clamp(position.minScrollExtent, position.maxScrollExtent);

    if ((next - position.pixels).abs() < 0.1) {
      stopAutoScroll();
      return;
    }

    widget.scrollController.jumpTo(next);
  }

  void stopAutoScroll() {
    _scrollVelocity = 0;
    _autoScrollTimer?.cancel();
    _autoScrollTimer = null;
  }

  @override
  void dispose() {
    stopAutoScroll();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
