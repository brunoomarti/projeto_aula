import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:tasker_project/core/icons/tasker_icon.dart';

import 'package:hugeicons/hugeicons.dart';

import '../../app/theme/tasker_colors.dart';
import '../layout/tasker_page_chrome.dart';

/// Dock com thumb arrastável — estilo “deslize para confirmar”.
///
/// Componente genérico reutilizável em qualquer fluxo de confirmação por gesto.
class TaskerSwipeSubmitDock extends StatefulWidget {
  const TaskerSwipeSubmitDock({
    super.key,
    required this.label,
    required this.onSubmit,
    this.enabled = true,
    this.loading = false,
    this.height = TaskerDockMetrics.barHeight,
    this.insetContent = true,
  });

  final String label;
  final Future<void> Function() onSubmit;
  final bool enabled;
  final bool loading;

  /// Altura externa do trilho — padrão igual ao dock da home.
  final double height;

  /// Quando `false`, [height] já é a altura do trilho (sem gap interno).
  final bool insetContent;

  static const outerHeight = TaskerDockMetrics.barHeight;
  static const glassInnerGap = 6.0;
  static const thumbInset = 6.0;
  static const completeThreshold = 0.86;
  static const waveArrowSize = 15.0;
  static const waveArrowGap = 6.0;
  static const maxWaveArrowsPerSide = 8;

  /// Quantas setas cabem em uma faixa lateral, dado a largura disponível.
  static int arrowsPerSideForLaneWidth(double laneWidth) {
    if (laneWidth < waveArrowSize) return 0;
    return ((laneWidth + waveArrowGap) / (waveArrowSize + waveArrowGap))
        .floor()
        .clamp(0, maxWaveArrowsPerSide);
  }

  /// Atrito da inércia — menor = desliza mais longe após soltar.
  static const flingFriction = 0.128;

  /// Velocidade mínima (px/s) para completar só pelo “flick”.
  static const strongFlingVelocity = 620.0;

  /// Sombra leve — igual à pílula de dia selecionada na home.
  static const thumbShadow = BoxShadow(
    color: Color.fromARGB(41, 0, 0, 0),
    blurRadius: 1,
    offset: Offset(0, 1),
  );

  @override
  State<TaskerSwipeSubmitDock> createState() => _TaskerSwipeSubmitDockState();
}

class _TaskerSwipeSubmitDockState extends State<TaskerSwipeSubmitDock>
    with TickerProviderStateMixin {
  final _dragOffset = ValueNotifier(0.0);
  bool _submitting = false;

  late final AnimationController _snapController;
  late final AnimationController _waveController;
  Animation<double>? _snapAnimation;

  Ticker? _flingTicker;
  FrictionSimulation? _flingSimulation;
  double _flingMaxDrag = 0;
  bool _snapCompletesOnEnd = false;

  @override
  void initState() {
    super.initState();
    _snapController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    )..addListener(() {
        if (_snapAnimation != null) {
          _dragOffset.value = _snapAnimation!.value;
          _syncWaveAnimation();
        }
      });
    _snapController.addStatusListener((status) {
      if (status == AnimationStatus.completed &&
          _snapCompletesOnEnd &&
          mounted) {
        _snapCompletesOnEnd = false;
        _completeAt(_flingMaxDrag);
      }
    });
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _syncWaveAnimation();
    });
  }

  @override
  void didUpdateWidget(covariant TaskerSwipeSubmitDock oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.loading && !widget.loading && !_submitting) {
      _resetThumb();
    }
    _syncWaveAnimation();
  }

  @override
  void dispose() {
    _stopFling();
    _dragOffset.dispose();
    _snapController.dispose();
    _waveController.dispose();
    super.dispose();
  }

  void _stopFling() {
    _flingTicker?.stop();
    _flingTicker?.dispose();
    _flingTicker = null;
    _flingSimulation = null;
  }

  void _stopMotion() {
    _stopFling();
    _snapController.stop();
    _snapCompletesOnEnd = false;
  }

  void _syncWaveAnimation() {
    final shouldAnimate =
        widget.enabled && !widget.loading && !_submitting && _dragOffset.value <= 1;
    if (shouldAnimate && !_waveController.isAnimating) {
      _waveController.repeat();
    } else if (!shouldAnimate && _waveController.isAnimating) {
      _waveController.stop();
    }
  }

  void _resetThumb() {
    _stopMotion();
    _snapAnimation = null;
    _dragOffset.value = 0;
    _syncWaveAnimation();
  }

  void _animateTo(double target, {bool completeOnEnd = false}) {
    _stopFling();
    _snapCompletesOnEnd = completeOnEnd;
    _snapAnimation = Tween<double>(
      begin: _dragOffset.value,
      end: target,
    ).animate(CurvedAnimation(
      parent: _snapController,
      curve: Curves.easeOutCubic,
    ));
    _snapController.forward(from: 0);
  }

  void _startFling(double maxDrag, double velocity) {
    _flingMaxDrag = maxDrag;
    _flingSimulation = FrictionSimulation(
      TaskerSwipeSubmitDock.flingFriction,
      _dragOffset.value,
      velocity,
      tolerance: const Tolerance(velocity: 18, distance: 0.5),
    );
    _flingTicker?.dispose();
    _flingTicker = createTicker(_onFlingTick)..start();
  }

  void _onFlingTick(Duration elapsed) {
    final simulation = _flingSimulation;
    if (simulation == null) return;

    final maxDrag = _flingMaxDrag;
    final threshold = maxDrag * TaskerSwipeSubmitDock.completeThreshold;
    final t = elapsed.inMicroseconds / 1e6;

    if (!simulation.isDone(t)) {
      final next = simulation.x(t).clamp(0.0, maxDrag);
      _dragOffset.value = next;
      _syncWaveAnimation();
      if (next >= maxDrag) {
        _stopFling();
        _completeAt(maxDrag);
      }
      return;
    }

    final settled = simulation.x(t).clamp(0.0, maxDrag);
    _dragOffset.value = settled;
    _stopFling();

    if (settled >= threshold) {
      if (settled < maxDrag) {
        _animateTo(maxDrag, completeOnEnd: true);
      } else {
        _completeAt(maxDrag);
      }
    } else {
      _animateTo(0);
    }
  }

  Future<void> _completeAt(double maxDrag) async {
    if (_submitting || !widget.enabled) return;

    _dragOffset.value = maxDrag;
    setState(() => _submitting = true);
    _waveController.stop();
    HapticFeedback.mediumImpact();
    await widget.onSubmit();
    if (!mounted) return;
    setState(() => _submitting = false);
    if (!widget.loading) _resetThumb();
  }

  void _handleRelease(double maxDrag, DragEndDetails details) {
    if (!widget.enabled || widget.loading || _submitting) return;

    _stopFling();
    _snapController.stop();
    _snapCompletesOnEnd = false;
    _flingMaxDrag = maxDrag;

    final threshold = maxDrag * TaskerSwipeSubmitDock.completeThreshold;
    final velocity = details.velocity.pixelsPerSecond.dx;

    if (_dragOffset.value >= threshold) {
      _completeAt(maxDrag);
      return;
    }

    if (velocity >= TaskerSwipeSubmitDock.strongFlingVelocity) {
      _animateTo(maxDrag, completeOnEnd: true);
      return;
    }

    if (velocity < -260) {
      _animateTo(0);
      return;
    }

    if (velocity.abs() < 55) {
      _animateTo(0);
      return;
    }

    _startFling(maxDrag, velocity);
  }

  @override
  Widget build(BuildContext context) {
    final interactive = widget.enabled && !widget.loading && !_submitting;
    final outerHeight = widget.height;
    final innerTrackHeight = widget.insetContent
        ? outerHeight - TaskerSwipeSubmitDock.glassInnerGap * 2
        : outerHeight;
    final thumbSize =
        innerTrackHeight - TaskerSwipeSubmitDock.thumbInset * 2;
    final outerPadding = widget.insetContent
        ? const EdgeInsets.all(TaskerSwipeSubmitDock.glassInnerGap)
        : EdgeInsets.zero;

    return LayoutBuilder(
      builder: (context, constraints) {
        return SizedBox(
          width: double.infinity,
          height: outerHeight,
          child: Padding(
            padding: outerPadding,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0x1A1A3D47),
                borderRadius: BorderRadius.circular(innerTrackHeight / 2),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.42),
                  width: 1,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(innerTrackHeight / 2),
                child: SizedBox(
                  height: innerTrackHeight,
                  width: double.infinity,
                  child: LayoutBuilder(
                    builder: (context, innerConstraints) {
                      final innerWidth = innerConstraints.maxWidth;
                      final maxDrag = (innerWidth -
                              thumbSize -
                              TaskerSwipeSubmitDock.thumbInset * 2)
                          .clamp(0.0, double.infinity);

                      return RepaintBoundary(
                        child: ListenableBuilder(
                          listenable: _dragOffset,
                          builder: (context, _) {
                            final dragOffset = _dragOffset.value;
                            final progress = maxDrag <= 0
                                ? 0.0
                                : (dragOffset / maxDrag).clamp(0.0, 1.0);
                            final hintOpacity =
                                (1 - progress * 0.85).clamp(0.0, 1.0);
                            final showWave =
                                hintOpacity > 0.08 && interactive;

                            return Stack(
                              clipBehavior: Clip.hardEdge,
                              alignment: Alignment.center,
                              children: [
                                Positioned(
                                  left: thumbSize +
                                      TaskerSwipeSubmitDock.thumbInset,
                                  right: TaskerSwipeSubmitDock.thumbInset,
                                  top: 0,
                                  bottom: 0,
                                  child: IgnorePointer(
                                    child: Opacity(
                                      opacity: hintOpacity,
                                      child: _SwipeHintLane(
                                        label: widget.label,
                                        animation: _waveController,
                                        showWave: showWave,
                                      ),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  left: TaskerSwipeSubmitDock.thumbInset +
                                      dragOffset,
                                  top: (innerTrackHeight - thumbSize) / 2,
                                  child: IgnorePointer(
                                    child: _SwipeThumb(
                                      loading:
                                          widget.loading || _submitting,
                                      size: thumbSize,
                                    ),
                                  ),
                                ),
                                if (interactive)
                                  Positioned.fill(
                                    child: GestureDetector(
                                      behavior: HitTestBehavior.translucent,
                                      onHorizontalDragStart: (_) =>
                                          _stopMotion(),
                                      onHorizontalDragUpdate: (details) {
                                        _dragOffset.value =
                                            (_dragOffset.value +
                                                    details.delta.dx)
                                                .clamp(0.0, maxDrag);
                                        _syncWaveAnimation();
                                      },
                                      onHorizontalDragEnd: (details) =>
                                          _handleRelease(maxDrag, details),
                                    ),
                                  ),
                              ],
                            );
                          },
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Texto central com setas animadas nas faixas laterais — quantidade adaptativa.
class _SwipeHintLane extends StatelessWidget {
  const _SwipeHintLane({
    required this.label,
    required this.animation,
    required this.showWave,
  });

  final String label;
  final Animation<double> animation;
  final bool showWave;

  static const _labelHorizontalPadding = 4.0;

  static TextStyle _labelStyle(BuildContext context) => TextStyle(
        fontSize: 13.5,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.1,
        color: TaskerColors.secondaryText.withValues(alpha: 0.92),
      );

  static double _measureLabelWidth(
    String text,
    TextStyle style,
    TextScaler textScaler,
  ) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      textScaler: textScaler,
      maxLines: 1,
    )..layout();
    return painter.width;
  }

  @override
  Widget build(BuildContext context) {
    final labelStyle = _labelStyle(context);
    final textScaler = MediaQuery.textScalerOf(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final labelWidth = _measureLabelWidth(label, labelStyle, textScaler) +
            _labelHorizontalPadding * 2;
        final sideLaneWidth =
            ((constraints.maxWidth - labelWidth) / 2).clamp(0.0, double.infinity);
        final arrowsPerSide =
            showWave ? TaskerSwipeSubmitDock.arrowsPerSideForLaneWidth(sideLaneWidth) : 0;
        final totalWaveSlots = arrowsPerSide * 2;

        return ClipRect(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: arrowsPerSide > 0
                    ? ClipRect(
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: _SwipeWaveArrows(
                            animation: animation,
                            startIndex: 0,
                            count: arrowsPerSide,
                            totalWaveSlots: totalWaveSlots,
                            mainAxisAlignment: MainAxisAlignment.end,
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
              Flexible(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: _labelHorizontalPadding,
                  ),
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    softWrap: false,
                    textAlign: TextAlign.center,
                    style: labelStyle,
                  ),
                ),
              ),
              Expanded(
                child: arrowsPerSide > 0
                    ? ClipRect(
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: _SwipeWaveArrows(
                            animation: animation,
                            startIndex: arrowsPerSide,
                            count: arrowsPerSide,
                            totalWaveSlots: totalWaveSlots,
                            mainAxisAlignment: MainAxisAlignment.start,
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SwipeWaveArrows extends StatelessWidget {
  const _SwipeWaveArrows({
    required this.animation,
    required this.startIndex,
    required this.count,
    required this.totalWaveSlots,
    required this.mainAxisAlignment,
  });

  final Animation<double> animation;
  final int startIndex;
  final int count;
  final int totalWaveSlots;
  final MainAxisAlignment mainAxisAlignment;

  static double _opacityForArrow(int index, int total, double t) {
    if (total <= 0) return 0;
    final wavePos = t * (total + 1.0);
    final dist = (wavePos - index).abs();
    if (dist >= 1.0) return 0.32;
    final pulse = Curves.easeInOut.transform(1 - (dist / 1.0));
    return 0.32 + 0.68 * pulse;
  }

  @override
  Widget build(BuildContext context) {
    if (count <= 0 || totalWaveSlots <= 0) {
      return const SizedBox.shrink();
    }

    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: mainAxisAlignment,
          children: [
            for (var i = 0; i < count; i++) ...[
              if (i > 0) const SizedBox(width: TaskerSwipeSubmitDock.waveArrowGap),
              Opacity(
                opacity: _opacityForArrow(
                  startIndex + i,
                  totalWaveSlots,
                  animation.value,
                ),
                child: AppHugeIcon(
                  icon: HugeIcons.strokeRoundedArrowRight01,
                  size: TaskerSwipeSubmitDock.waveArrowSize,
                  strokeWidth: 1.85,
                  color: TaskerColors.primary.withValues(alpha: 0.88),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _SwipeThumb extends StatelessWidget {
  const _SwipeThumb({
    required this.loading,
    required this.size,
  });

  final bool loading;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFFFFFFF),
            Color(0xFFD9DEE8),
          ],
        ),
        border: Border.all(color: Colors.white, width: 1),
        boxShadow: const [TaskerSwipeSubmitDock.thumbShadow],
      ),
      child: Center(
        child: loading
            ? SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: TaskerColors.primary.withValues(alpha: 0.85),
                ),
              )
            : AppHugeIcon(
                icon: HugeIcons.strokeRoundedArrowRight01,
                size: 20,
                color: TaskerColors.primary.withValues(alpha: 0.85),
              ),
      ),
    );
  }
}
