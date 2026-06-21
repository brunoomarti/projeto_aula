import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../app/theme/tasker_colors.dart';
import '../../features/tasks/presentation/widgets/task_card.dart';
import '../widgets/tasker_glass_surface.dart';

/// Utilitários para reduzir jank na primeira animação após cold start.
abstract final class AppAnimationWarmup {
  static Future<void> waitForFrames([int count = 6]) async {
    for (var i = 0; i < count; i++) {
      await _waitNextFrame();
    }
  }

  static Future<void> _waitNextFrame() {
    final completer = Completer<void>();
    SchedulerBinding.instance.scheduleFrameCallback((_) {
      if (!completer.isCompleted) completer.complete();
    });
    return completer.future;
  }
}

/// Aquecimento no splash — blur dinâmico, transforms e card shell.
class AppAnimationWarmupPanel extends StatefulWidget {
  const AppAnimationWarmupPanel({super.key});

  @override
  State<AppAnimationWarmupPanel> createState() =>
      _AppAnimationWarmupPanelState();
}

class _AppAnimationWarmupPanelState extends State<AppAnimationWarmupPanel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await _controller.forward(from: 0);
      if (!mounted) return;
      await _controller.reverse();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Opacity(
        opacity: 0.01,
        child: RepaintBoundary(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              final t = _controller.value;
              return ClipRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 3.5 * t, sigmaY: 3.5 * t),
                  child: Transform.scale(
                    scale: 0.92 + t * 0.08,
                    alignment: Alignment.topCenter,
                    filterQuality: FilterQuality.low,
                    child: child,
                  ),
                ),
              );
            },
            child: SizedBox(
              width: 160,
              height: 140,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TaskerGlassSurface(
                    shape: TaskerGlassShape.pill,
                    height: 32,
                    child: const SizedBox.shrink(),
                  ),
                  const SizedBox(height: 8),
                  TaskCardTokens.shell(
                    child: const SizedBox(height: 72, width: 140),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Aquecimento na home — simula abrir/fechar pilha e blur após montar a tela.
class HomeRuntimeWarmup extends StatefulWidget {
  const HomeRuntimeWarmup({super.key});

  @override
  State<HomeRuntimeWarmup> createState() => _HomeRuntimeWarmupState();
}

class _HomeRuntimeWarmupState extends State<HomeRuntimeWarmup>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  var _done = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  Future<void> _run() async {
    if (!mounted || _done) return;
    await _controller.forward(from: 0);
    if (!mounted) return;
    await _controller.reverse();
    if (!mounted) return;
    setState(() => _done = true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_done) return const SizedBox.shrink();

    return IgnorePointer(
      child: Opacity(
        opacity: 0.001,
        child: SizedBox(
          width: 1,
          height: 1,
          child: OverflowBox(
            maxWidth: 180,
            maxHeight: 160,
            alignment: Alignment.topLeft,
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                final t = Curves.easeOutCubic.transform(_controller.value);
                return Stack(
                  clipBehavior: Clip.hardEdge,
                  children: [
                    Positioned(
                      top: 12 * t,
                      left: 8 * (1 - t),
                      right: 8 * (1 - t),
                      child: Transform.scale(
                        scale: 0.9 + 0.1 * t,
                        alignment: Alignment.topCenter,
                        filterQuality: FilterQuality.low,
                        child: TaskCardTokens.shell(
                          child: const SizedBox(height: 64, width: 160),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(
                            sigmaX: 24 * t,
                            sigmaY: 24 * t,
                          ),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: const Color(0xFFDADDEB),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: TaskerColors.primary.withValues(
                                  alpha: 0.2,
                                ),
                              ),
                            ),
                            child: const SizedBox(height: 120, width: 180),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
