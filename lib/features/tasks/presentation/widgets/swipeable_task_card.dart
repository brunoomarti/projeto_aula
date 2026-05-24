import 'package:flutter/physics.dart';
import 'package:flutter/material.dart';

import '../../domain/task.dart';
import 'task_card.dart';

enum SwipeOpenDirection { left, right }

/// Card de tarefa com swipe horizontal — espelha o TaskRow da referência Tasker.
class SwipeableTaskCard extends StatefulWidget {
  const SwipeableTaskCard({
    super.key,
    required this.task,
    required this.isOpen,
    required this.openDir,
    required this.onOpenDetails,
    required this.onToggleDone,
    required this.onAskDelete,
    required this.onOpenSwipe,
    required this.onCloseSwipe,
    this.showCompletionFlash = false,
  });

  final Task task;
  final bool isOpen;
  final SwipeOpenDirection? openDir;
  final VoidCallback onOpenDetails;
  final VoidCallback onToggleDone;
  final VoidCallback onAskDelete;
  final void Function(String? id, SwipeOpenDirection? dir) onOpenSwipe;
  final VoidCallback onCloseSwipe;
  final bool showCompletionFlash;

  @override
  State<SwipeableTaskCard> createState() => _SwipeableTaskCardState();
}

class _SwipeableTaskCardState extends State<SwipeableTaskCard>
    with SingleTickerProviderStateMixin {
  static const _swipeLockX = 80.0;
  static const _dragMaxX = 90.0;
  static const _swipeLockLeft = -80.0;

  late final AnimationController _x = AnimationController.unbounded(
    vsync: this,
    value: 0,
  );

  bool _dragging = false;
  SwipeOpenDirection? _dragStartOpenDir;
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    _x.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void didUpdateWidget(covariant SwipeableTaskCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Durante o arrasto, não interferir — o offset fica sob controle do gesto.
    if (_dragging) return;

    if (widget.isOpen != oldWidget.isOpen ||
        widget.openDir != oldWidget.openDir) {
      _snapTo(
        widget.isOpen
            ? (widget.openDir == SwipeOpenDirection.left
                ? _swipeLockLeft
                : _swipeLockX)
            : 0,
      );
    }
  }

  @override
  void dispose() {
    _x.dispose();
    super.dispose();
  }

  double get _offset => _x.value.clamp(-_dragMaxX, _dragMaxX);

  double get _progressRight =>
      (_offset / _swipeLockX).clamp(0.0, 1.0);

  double get _progressLeft =>
      (-_offset / -_swipeLockLeft).clamp(0.0, 1.0);

  void _snapTo(double target, {double velocity = 0}) {
    _x.stop();
    final simulation = SpringSimulation(
      const SpringDescription(mass: 1, stiffness: 700, damping: 40),
      _offset,
      target,
      velocity,
    );
    _x.animateWith(simulation);
  }

  void _centerRow() {
    widget.onCloseSwipe();
    _snapTo(0);
  }

  void _onDragStart(DragStartDetails _) {
    _dragging = true;
    _dragStartOpenDir =
        widget.isOpen ? widget.openDir : null;
    widget.onOpenSwipe(null, null);
  }

  void _onDragUpdate(DragUpdateDetails details) {
    var next = _offset + details.delta.dx;

    // Ao fechar um swipe aberto, não deixa cruzar o centro e acionar o outro lado.
    if (_dragStartOpenDir == SwipeOpenDirection.right) {
      next = _trunc(next, 0, _dragMaxX);
    } else if (_dragStartOpenDir == SwipeOpenDirection.left) {
      next = _trunc(next, -_dragMaxX, 0);
    } else {
      next = _trunc(next, -_dragMaxX, _dragMaxX);
    }

    _x.value = next;
  }

  bool _shouldLockRight(double current, double v, SwipeOpenDirection? startedDir) {
    if (startedDir == SwipeOpenDirection.left) return false;
    return current > _swipeLockX * 0.5 ||
        (current > _swipeLockX * 0.25 && v > 250);
  }

  bool _shouldLockLeft(double current, double v, SwipeOpenDirection? startedDir) {
    if (startedDir == SwipeOpenDirection.right) return false;
    return current < _swipeLockLeft * 0.5 ||
        (current < _swipeLockLeft * 0.25 && v < -250);
  }

  void _onDragEnd(DragEndDetails details) {
    final current = _offset;
    final v = details.velocity.pixelsPerSecond.dx;
    final startedDir = _dragStartOpenDir;

    final shouldCompleteLeft = !widget.task.done &&
        _shouldLockLeft(current, v, startedDir);
    final shouldOpenRight = _shouldLockRight(current, v, startedDir);

    if (shouldCompleteLeft) {
      _snapTo(0, velocity: v);
      widget.onCloseSwipe();
      widget.onToggleDone();
    } else if (shouldOpenRight) {
      _snapTo(_swipeLockX, velocity: v);
      widget.onOpenSwipe(widget.task.id, SwipeOpenDirection.right);
    } else {
      _snapTo(0, velocity: v);
      widget.onCloseSwipe();
    }

    Future<void>.delayed(Duration.zero, () {
      if (mounted) {
        setState(() {
          _dragging = false;
          _dragStartOpenDir = null;
        });
      }
    });
  }

  void _handleOpenDetails() {
    if (widget.isOpen) {
      _centerRow();
      return;
    }
    if (_dragging) return;
    widget.onOpenDetails();
  }

  /// Lixeira: visível durante o arrasto mesmo em tarefas concluídas.
  bool get _showDeleteLayer =>
      !widget.task.done ||
      widget.isOpen ||
      _dragging ||
      _progressRight > 0;

  /// Concluir: só para tarefas pendentes.
  bool get _showCompleteLayer => !widget.task.done;

  @override
  Widget build(BuildContext context) {
    final isOpenRight =
        widget.isOpen && widget.openDir == SwipeOpenDirection.right;

    return LayoutBuilder(
      builder: (context, constraints) {
        final cardHeight = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : 110.0;

        return Stack(
          clipBehavior: Clip.none,
          children: [
            if (_showDeleteLayer)
              Positioned.fill(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: _SwipeActionButton(
                    progress: _progressRight,
                    color: const Color(0xFFE15E5B),
                    icon: Icons.delete_outline,
                    iconColor: Colors.white,
                    cardHeight: cardHeight,
                    onTap: widget.onAskDelete,
                    enabled: isOpenRight,
                  ),
                ),
              ),
            if (_showCompleteLayer)
              Positioned.fill(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: _SwipeActionButton(
                    progress: _progressLeft,
                    color: TaskCardTokens.doneAccent,
                    icon: Icons.check,
                    iconColor: Colors.white,
                    cardHeight: cardHeight,
                    visualOnly: true,
                  ),
                ),
              ),
            Transform.translate(
              offset: Offset(_offset, 0),
              child: GestureDetector(
                onHorizontalDragStart: _onDragStart,
                onHorizontalDragUpdate: _onDragUpdate,
                onHorizontalDragEnd: _onDragEnd,
                onTapDown: (_) => setState(() => _pressed = true),
                onTapUp: (_) => setState(() => _pressed = false),
                onTapCancel: () => setState(() => _pressed = false),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 120),
                  decoration: BoxDecoration(
                    borderRadius:
                        BorderRadius.circular(TaskCardTokens.borderRadius),
                    color: _pressed
                        ? const Color(0xFFECECEC)
                        : Colors.transparent,
                  ),
                  child: TaskCard(
                    task: widget.task,
                    onOpenDetails: _handleOpenDetails,
                    onToggleDone: widget.onToggleDone,
                    showCompletionFlash: widget.showCompletionFlash,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

double _lerp(double a, double b, double t) => a + (b - a) * t;

double _trunc(double value, double min, double max) {
  if (value < min) return min;
  if (value > max) return max;
  return value;
}

class _SwipeActionButton extends StatelessWidget {
  const _SwipeActionButton({
    required this.progress,
    required this.color,
    required this.icon,
    required this.iconColor,
    required this.cardHeight,
    this.onTap,
    this.enabled = false,
    this.visualOnly = false,
  });

  final double progress;
  final Color color;
  final IconData icon;
  final Color iconColor;
  final double cardHeight;
  final VoidCallback? onTap;
  final bool enabled;
  final bool visualOnly;

  @override
  Widget build(BuildContext context) {
    final width = _lerp(48, 70, progress);
    final height = _lerp(cardHeight * 0.84, cardHeight * 0.92, progress);
    final radius = _lerp(24, 16, progress);
    final opacity = progress;
    final interactive = !visualOnly && enabled && onTap != null;

    return IgnorePointer(
      ignoring: !interactive,
      child: Opacity(
        opacity: opacity,
        child: Material(
          color: color,
          borderRadius: BorderRadius.circular(radius),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: interactive ? onTap : null,
            child: SizedBox(
              width: width,
              height: height,
              child: Icon(icon, color: iconColor, size: 22),
            ),
          ),
        ),
      ),
    );
  }
}
