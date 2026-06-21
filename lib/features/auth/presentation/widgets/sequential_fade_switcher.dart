import 'package:flutter/material.dart';

/// Fade out completo → troca conteúdo invisível → fade in.
///
/// Evita o "pulo" de layout do [AnimatedSwitcher], que anima entrada e saída
/// ao mesmo tempo com alturas diferentes.
class SequentialFadeSwitcher extends StatefulWidget {
  const SequentialFadeSwitcher({
    super.key,
    required this.switchKey,
    required this.child,
    this.duration = const Duration(milliseconds: 130),
    this.onSwap,
  });

  final Object switchKey;
  final Widget child;
  final Duration duration;
  final VoidCallback? onSwap;

  @override
  State<SequentialFadeSwitcher> createState() => _SequentialFadeSwitcherState();
}

class _SequentialFadeSwitcherState extends State<SequentialFadeSwitcher>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Widget _visibleChild;
  late Object _visibleKey;
  bool _isSwitching = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _visibleChild = widget.child;
    _visibleKey = widget.switchKey;
    _controller.value = 1;
  }

  @override
  void didUpdateWidget(SequentialFadeSwitcher oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.switchKey != oldWidget.switchKey) {
      _scheduleSwitch();
      return;
    }
    if (!_isSwitching) {
      _visibleChild = widget.child;
    }
  }

  void _scheduleSwitch() {
    if (_isSwitching) return;
    _isSwitching = true;
    _runSwitch();
  }

  Future<void> _runSwitch() async {
    await _controller.reverse();
    if (!mounted) return;

    widget.onSwap?.call();
    setState(() {
      _visibleChild = widget.child;
      _visibleKey = widget.switchKey;
    });

    await _controller.forward();
    if (mounted) {
      _isSwitching = false;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _controller,
      child: KeyedSubtree(
        key: ValueKey(_visibleKey),
        child: _visibleChild,
      ),
    );
  }
}
