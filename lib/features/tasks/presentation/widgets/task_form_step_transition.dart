import 'package:flutter/material.dart';

/// Transição entre steps — card sai para um lado enquanto o próximo entra do oposto.
class TaskFormStepTransition extends StatefulWidget {
  const TaskFormStepTransition({
    super.key,
    required this.step,
    required this.direction,
    required this.child,
    this.duration = const Duration(milliseconds: 340),
  });

  final int step;
  final int direction;
  final Widget child;
  final Duration duration;

  @override
  State<TaskFormStepTransition> createState() => _TaskFormStepTransitionState();
}

class _TaskFormStepTransitionState extends State<TaskFormStepTransition>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _progress;

  Widget? _outgoingChild;
  int _transitionDirection = 1;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
      value: 1,
    );
    _progress = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOutCubic,
    );
    _controller.addStatusListener(_onAnimationStatus);
  }

  void _onAnimationStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed && mounted) {
      setState(() => _outgoingChild = null);
    }
  }

  @override
  void didUpdateWidget(covariant TaskFormStepTransition oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.step != oldWidget.step) {
      _outgoingChild = oldWidget.child;
      _transitionDirection = widget.direction;
      _controller
        ..value = 0
        ..forward();
    }
    if (widget.duration != oldWidget.duration) {
      _controller.duration = widget.duration;
    }
  }

  @override
  void dispose() {
    _controller.removeStatusListener(_onAnimationStatus);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _progress,
        child: widget.child,
        builder: (context, child) {
          final t = _progress.value;
          final children = <Widget>[];

          final outgoing = _outgoingChild;
          if (outgoing != null && t < 1) {
            children.add(
              _StepSlideLayer(
                progress: t,
                direction: _transitionDirection,
                exiting: true,
                child: outgoing,
              ),
            );
          }

          children.add(
            _StepSlideLayer(
              progress: t,
              direction: _transitionDirection,
              exiting: false,
              child: child!,
            ),
          );

          return Stack(
            alignment: Alignment.topCenter,
            clipBehavior: Clip.none,
            children: children.map((layer) {
              return Align(
                alignment: Alignment.topCenter,
                widthFactor: 1,
                child: layer,
              );
            }).toList(),
          );
        },
      ),
    );
  }
}

class _StepSlideLayer extends StatelessWidget {
  const _StepSlideLayer({
    required this.progress,
    required this.direction,
    required this.exiting,
    required this.child,
  });

  final double progress;
  final int direction;
  final bool exiting;
  final Widget child;

  static const _fadePortion = 0.22;

  Offset _offset() {
    final sign = direction.sign.toDouble();
    if (exiting) {
      return Offset.lerp(
        Offset.zero,
        Offset(-sign, 0),
        progress,
      )!;
    }
    return Offset.lerp(
      Offset(sign, 0),
      Offset.zero,
      progress,
    )!;
  }

  double _opacity() {
    if (exiting) {
      if (progress <= 1 - _fadePortion) return 1;
      return ((1 - progress) / _fadePortion).clamp(0.0, 1.0);
    }
    if (progress >= _fadePortion) return 1;
    return (progress / _fadePortion).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    return FractionalTranslation(
      translation: _offset(),
      transformHitTests: !exiting || progress < 1,
      child: Opacity(
        opacity: _opacity(),
        child: child,
      ),
    );
  }
}
