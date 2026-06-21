import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/theme/tasker_colors.dart';
import '../../domain/task.dart';
import 'task_card.dart';
import 'task_drag_scroll_scope.dart';
import '../../../home/presentation/widgets/home_day_selector_drag_scope.dart';

/// Dados transportados durante o arrasto de uma tarefa na home.
class TaskDragData {
  const TaskDragData(this.task);

  final Task task;
}

/// Permite segurar e arrastar uma tarefa para empilhar na home.
class TaskDragWrapper extends StatefulWidget {
  const TaskDragWrapper({
    super.key,
    required this.task,
    required this.child,
    this.enabled = true,
    this.onDragStarted,
    this.onDragEnded,
  });

  final Task task;
  final Widget child;
  final bool enabled;
  final VoidCallback? onDragStarted;
  final VoidCallback? onDragEnded;

  static const delay = Duration(milliseconds: 300);

  @override
  State<TaskDragWrapper> createState() => _TaskDragWrapperState();
}

class _TaskDragWrapperState extends State<TaskDragWrapper>
    with TickerProviderStateMixin {
  final _measureKey = GlobalKey();
  final _tiltNotifier = ValueNotifier(0.0);

  late final AnimationController _pressController;

  double _feedbackWidth = 320;
  bool _isDragging = false;
  Timer? _tiltDecayTimer;
  DateTime _lastDragUpdate = DateTime.now();
  HomeDaySelectorDragController? _daySelectorDrag;
  TaskDragScrollScopeState? _listDragScroll;

  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    );
  }

  @override
  void dispose() {
    _tiltDecayTimer?.cancel();
    _tiltNotifier.dispose();
    _pressController.dispose();
    super.dispose();
  }

  void _captureWidth() {
    final box =
        _measureKey.currentContext?.findRenderObject() as RenderBox?;
    if (box != null && box.hasSize) {
      _feedbackWidth = box.size.width;
    }
  }

  void _onPointerDown(PointerDownEvent _) {
    if (!widget.enabled || _isDragging) return;
    _pressController.forward();
  }

  void _onPointerUp(PointerUpEvent _) {
    if (_isDragging) return;
    _pressController.reverse();
  }

  void _onPointerCancel(PointerCancelEvent _) {
    if (_isDragging) return;
    _pressController.reverse();
  }

  void _onDragStarted() {
    _captureWidth();
    _isDragging = true;
    _pressController.reverse();
    _daySelectorDrag = HomeDaySelectorDragScope.maybeOf(context);
    _listDragScroll = TaskDragScrollScope.maybeOf(context);
    HapticFeedback.mediumImpact();
    widget.onDragStarted?.call();
  }

  void _onDragUpdate(DragUpdateDetails details) {
    _lastDragUpdate = DateTime.now();
    _tiltNotifier.value =
        (_tiltNotifier.value + details.delta.dx * 0.0038).clamp(-0.11, 0.11);
    _ensureTiltDecay();
    final dayDrag = _daySelectorDrag;
    dayDrag?.handleDragPosition(details.globalPosition);
    if (dayDrag?.isDragOverSelector == true) {
      _listDragScroll?.stopAutoScroll();
    } else {
      _listDragScroll?.handleDragPosition(details.globalPosition);
    }
  }

  void _onDragEnd() {
    _stopTiltDecay();
    _listDragScroll?.stopAutoScroll();
    _daySelectorDrag?.onDragEnded();
    _daySelectorDrag = null;
    _listDragScroll = null;
    _tiltNotifier.value = 0;
    setState(() => _isDragging = false);
    widget.onDragEnded?.call();
  }

  void _ensureTiltDecay() {
    _tiltDecayTimer ??= Timer.periodic(const Duration(milliseconds: 16), (_) {
      if (!mounted) return;
      if (DateTime.now().difference(_lastDragUpdate).inMilliseconds > 40) {
        final next = _tiltNotifier.value * 0.86;
        _tiltNotifier.value = next.abs() < 0.002 ? 0 : next;
        if (_tiltNotifier.value == 0) _stopTiltDecay();
      }
    });
  }

  void _stopTiltDecay() {
    _tiltDecayTimer?.cancel();
    _tiltDecayTimer = null;
  }

  Widget _buildPressableChild(Widget child) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _onPointerDown,
      onPointerUp: _onPointerUp,
      onPointerCancel: _onPointerCancel,
      child: AnimatedBuilder(
        animation: _pressController,
        builder: (context, child) {
          final press = Curves.easeOutCubic.transform(_pressController.value);
          final scale = 1 - press * 0.042;
          final depth = press * 4;
          return Transform.translate(
            offset: Offset(0, depth),
            child: Transform.scale(
              scale: scale,
              alignment: Alignment.center,
              child: child,
            ),
          );
        },
        child: child,
      ),
    );
  }

  Widget _buildFeedback() {
    return _TaskDragFeedback(
      task: widget.task,
      width: _feedbackWidth,
      tiltListenable: _tiltNotifier,
    );
  }

  @override
  Widget build(BuildContext context) {
    final measuredChild = KeyedSubtree(
      key: _measureKey,
      child: widget.child,
    );

    if (!widget.enabled) return measuredChild;

    return LongPressDraggable<TaskDragData>(
      data: TaskDragData(widget.task),
      delay: TaskDragWrapper.delay,
      hapticFeedbackOnStart: false,
      maxSimultaneousDrags: 1,
      onDragStarted: _onDragStarted,
      onDragUpdate: _onDragUpdate,
      onDragEnd: (_) => _onDragEnd(),
      onDraggableCanceled: (_, _) => _onDragEnd(),
      feedback: Material(
        color: Colors.transparent,
        elevation: 0,
        child: _buildFeedback(),
      ),
      childWhenDragging: TweenAnimationBuilder<double>(
        tween: Tween(begin: 1, end: 0.28),
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        builder: (context, opacity, child) =>
            Opacity(opacity: opacity, child: child),
        child: _buildPressableChild(measuredChild),
      ),
      child: _buildPressableChild(measuredChild),
    );
  }
}

class _TaskDragFeedback extends StatefulWidget {
  const _TaskDragFeedback({
    required this.task,
    required this.width,
    required this.tiltListenable,
  });

  final Task task;
  final double width;
  final ValueListenable<double> tiltListenable;

  @override
  State<_TaskDragFeedback> createState() => _TaskDragFeedbackState();
}

class _TaskDragFeedbackState extends State<_TaskDragFeedback>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pickupController;

  @override
  void initState() {
    super.initState();
    _pickupController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    )..forward();
  }

  @override
  void dispose() {
    _pickupController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pickupController,
      builder: (context, _) {
        final pickup = Curves.easeOutBack.transform(_pickupController.value);
        final scale = 1.02 + pickup * 0.07;
        final elevation = 8 + pickup * 10;

        return ValueListenableBuilder<double>(
          valueListenable: widget.tiltListenable,
          builder: (context, tilt, _) {
            return Transform.rotate(
              angle: tilt,
              child: Transform.scale(
                scale: scale,
                alignment: Alignment.center,
                child: SizedBox(
                  width: widget.width,
                  child: TaskCardTokens.shell(
                    elevation: elevation,
                    child: TaskCard(
                      task: widget.task,
                      onOpenDetails: () {},
                      onToggleDone: () {},
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

/// Destino de soltura — destaca e faz bounce ao receber a tarefa.
class TaskStackDropTarget extends StatefulWidget {
  const TaskStackDropTarget({
    super.key,
    required this.child,
    required this.canAccept,
    required this.onAccept,
    this.enabled = true,
  });

  final Widget child;
  final bool Function(TaskDragData data) canAccept;
  final ValueChanged<TaskDragData> onAccept;
  final bool enabled;

  @override
  State<TaskStackDropTarget> createState() => _TaskStackDropTargetState();
}

class _TaskStackDropTargetState extends State<TaskStackDropTarget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _bounceController;
  late final Animation<double> _bounceScale;

  @override
  void initState() {
    super.initState();
    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );
    _bounceScale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 0.965)
            .chain(CurveTween(curve: Curves.easeInCubic)),
        weight: 18,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 0.965, end: 1.035)
            .chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 42,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.035, end: 1.0)
            .chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 40,
      ),
    ]).animate(_bounceController);
  }

  @override
  void dispose() {
    _bounceController.dispose();
    super.dispose();
  }

  void _handleAccept(TaskDragData data) {
    HapticFeedback.lightImpact();
    _bounceController.forward(from: 0);
    widget.onAccept(data);
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;

    return DragTarget<TaskDragData>(
      onWillAcceptWithDetails: (details) => widget.canAccept(details.data),
      onAcceptWithDetails: (details) => _handleAccept(details.data),
      builder: (context, candidate, rejected) {
        final hovering = candidate.isNotEmpty;
        final hoverScale = hovering ? 1.018 : 1.0;

        return AnimatedBuilder(
          animation: _bounceController,
          builder: (context, child) {
            return Transform.scale(
              scale: _bounceScale.value * hoverScale,
              child: child,
            );
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            decoration: hovering
                ? BoxDecoration(
                    borderRadius:
                        BorderRadius.circular(TaskCardTokens.borderRadius),
                    border: Border.all(
                      color: TaskerColors.primary.withValues(alpha: 0.9),
                      width: 2.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: TaskerColors.primary.withValues(alpha: 0.22),
                        blurRadius: 18,
                        spreadRadius: 1,
                      ),
                    ],
                  )
                : null,
              child: widget.child,
            ),
          ),
        );
      },
    );
  }
}

/// Faixa entre itens da lista — soltar aqui remove a tarefa da pilha.
class TaskListInsertDropSlot extends StatelessWidget {
  const TaskListInsertDropSlot({
    super.key,
    required this.collapsedHeight,
    required this.expandedHeight,
    required this.canAccept,
    required this.onAccept,
    this.enabled = true,
  });

  final double collapsedHeight;
  final double expandedHeight;
  final bool Function(TaskDragData data) canAccept;
  final ValueChanged<TaskDragData> onAccept;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    if (!enabled) {
      return AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        height: collapsedHeight,
      );
    }

    return DragTarget<TaskDragData>(
      onWillAcceptWithDetails: (details) => canAccept(details.data),
      onAcceptWithDetails: (details) {
        HapticFeedback.lightImpact();
        onAccept(details.data);
      },
      builder: (context, candidate, rejected) {
        final hovering = candidate.isNotEmpty;
        final dragHeight = collapsedHeight + 8;
        final targetHeight =
            hovering ? expandedHeight : dragHeight;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          height: targetHeight,
          margin: EdgeInsets.symmetric(vertical: hovering ? 2 : 0),
          decoration: hovering
              ? BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: TaskerColors.primary.withValues(alpha: 0.1),
                  border: Border.all(
                    color: TaskerColors.primary.withValues(alpha: 0.75),
                    width: 1.8,
                  ),
                )
              : null,
          child: hovering
              ? Center(
                  child: Container(
                    height: 3,
                    margin: const EdgeInsets.symmetric(horizontal: 24),
                    decoration: BoxDecoration(
                      color: TaskerColors.primary.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                )
              : null,
        );
      },
    );
  }
}
