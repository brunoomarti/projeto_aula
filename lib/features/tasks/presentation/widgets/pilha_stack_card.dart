import 'dart:math' as math;

import 'package:tasker_project/core/icons/tasker_icon.dart';

import 'package:hugeicons/hugeicons.dart';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../../../app/theme/tasker_colors.dart';
import '../../domain/pilha.dart';
import '../../domain/task.dart';
import 'task_card.dart';
import 'task_stack_drag.dart';

/// Máximo de cards visíveis quando a pilha está fechada (sem limite de agrupamento).
const _kMaxVisibleStackLayers = 3;

/// Duração da animação de abrir/fechar a pilha.
const _kPilhaAnimDuration = Duration(milliseconds: 380);

/// Altura estimada de um card — usada até a medição real estar disponível.
const _kCardSlotHeight = 118.0;

/// Espaço vertical entre cards expandidos — igual ao [AnimatedTaskList.separatorExtent].
const _kCardSpacing = 12.0;

/// Card empilhado de uma [Pilha] — colapsado mostra camadas; expandido lista tarefas.
class PilhaStackCard extends StatefulWidget {
  const PilhaStackCard({
    super.key,
    required this.pilha,
    required this.tasks,
    required this.expanded,
    required this.onToggleExpanded,
    required this.taskCardBuilder,
    this.canAcceptTask,
    this.onTaskDropped,
  });

  final Pilha pilha;
  final List<Task> tasks;
  final bool expanded;
  final VoidCallback onToggleExpanded;

  /// Constrói o card interativo de cada tarefa (swipe, detalhes, etc.).
  final Widget Function(Task task) taskCardBuilder;

  /// Se informado, a pilha aceita tarefas arrastadas da home.
  final bool Function(Task task)? canAcceptTask;
  final ValueChanged<Task>? onTaskDropped;

  @override
  State<PilhaStackCard> createState() => _PilhaStackCardState();
}

class _PilhaStackCardState extends State<PilhaStackCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _expand;

  final Map<String, GlobalKey> _cardMeasureKeys = {};
  List<double> _measuredHeights = const [];
  List<double>? _heightSnapshot;
  bool _measureScheduled = false;

  int get _completedCount => widget.tasks.where((t) => t.done).length;

  bool get _showAllCards =>
      widget.expanded || _controller.isAnimating || _controller.value > 0.001;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: _kPilhaAnimDuration,
      value: widget.expanded ? 1.0 : 0.0,
    );
    _expand = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    _controller.addStatusListener(_onAnimationStatus);
  }

  void _onAnimationStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed ||
        status == AnimationStatus.dismissed) {
      _heightSnapshot = null;
      _scheduleMeasureHeights(force: true);
    }
  }

  void _snapshotHeightsForAnimation() {
    if (_measuredHeights.isEmpty) {
      _heightSnapshot =
          List<double>.filled(widget.tasks.length, _kCardSlotHeight);
      return;
    }
    _heightSnapshot = List<double>.from(_measuredHeights);
    if (_heightSnapshot!.length < widget.tasks.length) {
      _heightSnapshot!.addAll(
        List<double>.filled(
          widget.tasks.length - _heightSnapshot!.length,
          _kCardSlotHeight,
        ),
      );
    }
  }

  @override
  void didUpdateWidget(covariant PilhaStackCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.expanded != oldWidget.expanded) {
      _snapshotHeightsForAnimation();
      if (widget.expanded) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    }
    _pruneMeasureKeys();
  }

  @override
  void dispose() {
    _controller.removeStatusListener(_onAnimationStatus);
    _controller.dispose();
    super.dispose();
  }

  void _handleToggle() {
    widget.onToggleExpanded();
  }

  void _pruneMeasureKeys() {
    final ids = widget.tasks.map((t) => t.id).toSet();
    _cardMeasureKeys.removeWhere((id, _) => !ids.contains(id));
  }

  GlobalKey _measureKeyFor(String taskId) =>
      _cardMeasureKeys.putIfAbsent(taskId, GlobalKey.new);

  double _heightForIndex(int index) {
    final snapshot = _heightSnapshot;
    if (_controller.isAnimating && snapshot != null) {
      if (index < snapshot.length && snapshot[index] > 0) {
        return snapshot[index];
      }
      return _kCardSlotHeight;
    }
    if (index < _measuredHeights.length && _measuredHeights[index] > 0) {
      return _measuredHeights[index];
    }
    return _kCardSlotHeight;
  }

  void _scheduleMeasureHeights({bool force = false}) {
    if (!force && _controller.isAnimating) return;
    if (_measureScheduled) return;
    _measureScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _measureScheduled = false;
      if (!mounted) return;

      final measureCount = _showAllCards
          ? widget.tasks.length
          : math.min(widget.tasks.length, _kMaxVisibleStackLayers);

      if (measureCount <= 0) return;

      final next = <double>[];
      for (var i = 0; i < measureCount; i++) {
        final task = widget.tasks[i];
        final box =
            _measureKeyFor(task.id).currentContext?.findRenderObject()
                as RenderBox?;
        final measured =
            box != null && box.hasSize ? box.size.height : 0.0;
        if (measured > 0) {
          next.add(measured);
        } else if (i < _measuredHeights.length && _measuredHeights[i] > 0) {
          next.add(_measuredHeights[i]);
        } else {
          next.add(_kCardSlotHeight);
        }
      }

      if (_showAllCards && widget.tasks.length > measureCount) {
        for (var i = measureCount; i < widget.tasks.length; i++) {
          final task = widget.tasks[i];
          final box =
              _measureKeyFor(task.id).currentContext?.findRenderObject()
                  as RenderBox?;
          final measured =
              box != null && box.hasSize ? box.size.height : 0.0;
          if (measured > 0) {
            next.add(measured);
          } else if (i < _measuredHeights.length && _measuredHeights[i] > 0) {
            next.add(_measuredHeights[i]);
          } else {
            next.add(_kCardSlotHeight);
          }
        }
      }

      if (next.length != _measuredHeights.length ||
          !_heightsMatch(next, _measuredHeights)) {
        setState(() => _measuredHeights = next);
      }
    });
  }

  bool _heightsMatch(List<double> a, List<double> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if ((a[i] - b[i]).abs() > 0.5) return false;
    }
    return true;
  }

  double _lerp(double a, double b, double t) => a + (b - a) * t;

  double _expandedTopForIndex(int index) {
    var top = 0.0;
    for (var i = 0; i < index; i++) {
      top += _heightForIndex(i) + _kCardSpacing;
    }
    return top;
  }

  double _expandedContainerHeight(int count) {
    if (count <= 0) return _kCardSlotHeight;
    var height = 0.0;
    for (var i = 0; i < count; i++) {
      height += _heightForIndex(i);
      if (i < count - 1) height += _kCardSpacing;
    }
    return height;
  }

  double _collapsedContainerHeight(int count) {
    if (count <= 0) return _kCardSlotHeight;

    final visible = math.min(count, _kMaxVisibleStackLayers);
    if (visible == 1) return _heightForIndex(0);

    final deepestIndex = visible - 1;
    final deepestTop = _PilhaStackLayout.topForDepth(deepestIndex);
    final deepestScale = _PilhaStackLayout.scaleForDepth(deepestIndex);
    final deepestHeight = _heightForIndex(deepestIndex);
    final deepestVisualBottom = deepestTop + deepestHeight * deepestScale;

    return math.max(_heightForIndex(0), deepestVisualBottom);
  }

  List<int> _indicesToRender(int count) {
    if (!_showAllCards) {
      return List.generate(
        math.min(count, _kMaxVisibleStackLayers),
        (i) => i,
      );
    }
    return List.generate(count, (i) => i);
  }

  List<int> _paintOrder(List<int> indices, double t) {
    final order = List<int>.from(indices);
    if (t < 0.55) {
      order.sort((a, b) => b.compareTo(a));
    } else {
      order.sort();
    }
    return order;
  }

  double _itemProgress(int index, double t) {
    final hiddenWhenCollapsed = index >= _kMaxVisibleStackLayers;
    if (!hiddenWhenCollapsed) return t;

    final delay = 0.12 + (index - _kMaxVisibleStackLayers) * 0.05;
    return ((t - delay) / (1.0 - delay)).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    _scheduleMeasureHeights();

    final content = RepaintBoundary(
      child: AnimatedBuilder(
        animation: _expand,
        builder: (context, _) {
          final t = _expand.value;

          return _PilhaGroupShell(
            emphasis: t,
            header: GestureDetector(
              onTap: _handleToggle,
              behavior: HitTestBehavior.opaque,
              child: _buildPilhaHeader(expanded: t > 0.5),
            ),
            child: _buildUnstackingBody(t),
          );
        },
      ),
    );

    if (widget.canAcceptTask == null || widget.onTaskDropped == null) {
      return content;
    }

    return TaskStackDropTarget(
      canAccept: (data) => widget.canAcceptTask!(data.task),
      onAccept: (data) => widget.onTaskDropped!(data.task),
      child: content,
    );
  }

  Widget _buildPilhaHeader({required bool expanded}) {
    final total = widget.tasks.length;
    final completed = _completedCount;

    return Row(
      children: [
        TaskerIconBox(
          icon: HugeIcons.strokeRoundedLayers01,
          boxSize: 28,
          iconSize: 14,
          strokeWidth: 1.5,
          color: TaskerColors.primary.withValues(alpha: 0.95),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.62),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: const Color(0xFFB8C3D8).withValues(alpha: 0.75),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            widget.pilha.name,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: TaskerColors.primaryText,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Text(
          '$completed/$total',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 12,
            color: TaskerColors.mutedText.withValues(alpha: 0.95),
          ),
        ),
        const SizedBox(width: 6),
        AppHugeIcon(
          icon: expanded
              ? HugeIcons.strokeRoundedArrowUp01
              : HugeIcons.strokeRoundedArrowDown01,
          size: 20,
          color: TaskerColors.mutedText.withValues(alpha: 0.85),
        ),
      ],
    );
  }

  Widget _buildUnstackingBody(double t) {
    final tasks = widget.tasks;
    if (tasks.isEmpty) {
      return GestureDetector(
        onTap: _handleToggle,
        behavior: HitTestBehavior.opaque,
        child: _EmptyPilhaFace(pilhaName: widget.pilha.name),
      );
    }

    final count = tasks.length;
    final indices = _indicesToRender(count);
    final containerHeight = _lerp(
      _collapsedContainerHeight(count),
      _expandedContainerHeight(count),
      t,
    );
    final animating = _controller.isAnimating;
    final cardsInteractive = !animating && t >= 0.98;
    final stackTapEnabled = !animating && t < 0.05;

    return GestureDetector(
      onTap: stackTapEnabled ? _handleToggle : null,
      behavior: HitTestBehavior.opaque,
      child: ClipRect(
        clipBehavior: animating ? Clip.hardEdge : Clip.none,
        child: SizedBox(
          height: containerHeight,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.topCenter,
            children: [
              for (final index in _paintOrder(indices, t))
                _buildUnstackingCard(
                  index: index,
                  t: t,
                  cardsInteractive: cardsInteractive,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUnstackingCard({
    required int index,
    required double t,
    required bool cardsInteractive,
  }) {
    final task = widget.tasks[index];
    final itemT = Curves.easeInOutCubic.transform(_itemProgress(index, t));
    final hiddenWhenCollapsed = index >= _kMaxVisibleStackLayers;
    final animating = _controller.isAnimating;
    // Card da frente arrastável mesmo com pilha fechada.
    final pointerEnabled =
        !animating && (cardsInteractive || (index == 0 && t < 0.98));

    final stackDepth = hiddenWhenCollapsed
        ? _kMaxVisibleStackLayers - 1
        : index.clamp(0, _kMaxVisibleStackLayers - 1);

    final collapsedTop = _PilhaStackLayout.topForDepth(stackDepth);
    final collapsedScale = _PilhaStackLayout.scaleForDepth(stackDepth);
    final collapsedInset = _PilhaStackLayout.horizontalInset(stackDepth);
    final expandedTop = _expandedTopForIndex(index);

    final top = _lerp(collapsedTop, expandedTop, itemT);
    final scale = _lerp(collapsedScale, 1.0, itemT);
    final inset = _lerp(collapsedInset, 0.0, itemT);
    final opacity = hiddenWhenCollapsed ? itemT : 1.0;

    final card = Transform.scale(
      scale: scale,
      alignment: Alignment.topCenter,
      filterQuality: FilterQuality.medium,
      child: IgnorePointer(
        ignoring: !pointerEnabled,
        child: KeyedSubtree(
          key: _measureKeyFor(task.id),
          child: widget.taskCardBuilder(task),
        ),
      ),
    );

    final fadedCard = opacity >= 0.999
        ? card
        : Opacity(
            opacity: opacity.clamp(0.0, 1.0),
            alwaysIncludeSemantics: false,
            child: card,
          );

    return Positioned(
      top: top,
      left: inset,
      right: inset,
      child: RepaintBoundary(child: fadedCard),
    );
  }
}

abstract final class _PilhaStackLayout {
  static const layerGap = 4.0;
  static const layerPeek = 10.0;
  static const horizontalInsetStep = 10.0;
  static const scaleStep = 0.05;

  static double layerStep(int depthFromFront) =>
      depthFromFront * (layerPeek + layerGap);

  static double scaleForDepth(int depthFromFront) =>
      (1.0 - depthFromFront * scaleStep).clamp(0.82, 1.0);

  static double topForDepth(int depthFromFront) => layerStep(depthFromFront);

  static double horizontalInset(int depthFromFront) =>
      depthFromFront * horizontalInsetStep;
}

/// Moldura visual que agrupa cabeçalho + cards da pilha.
class _PilhaGroupShell extends StatelessWidget {
  const _PilhaGroupShell({
    required this.emphasis,
    required this.header,
    required this.child,
  });

  final double emphasis;
  final Widget header;
  final Widget child;

  static const _radiusTop = 20.0;
  static const _radiusBottomCollapsed = 20.0;

  /// Espaçamento uniforme entre divisor e pilha, laterais e base.
  static const _contentInset = 10.0;

  /// Espaço inferior para a [BoxShadow] do shell não ser cortada na lista.
  static const shellShadowExtent = 12.0;

  BorderRadius _borderRadius(double emphasis) {
    final bottom = _radiusBottomCollapsed +
        (TaskCardTokens.borderRadius - _radiusBottomCollapsed) * emphasis;
    return BorderRadius.only(
      topLeft: const Radius.circular(_radiusTop),
      topRight: const Radius.circular(_radiusTop),
      bottomLeft: Radius.circular(bottom),
      bottomRight: Radius.circular(bottom),
    );
  }

  @override
  Widget build(BuildContext context) {
    final borderColor = Color.lerp(
      const Color(0xFFB8C3D8),
      const Color(0xFFACB8D0),
      emphasis,
    )!;
    final backgroundColor = Color.lerp(
      const Color(0xFFDADDEB),
      const Color(0xFFD2D7E6),
      emphasis,
    )!;
    final borderRadius = _borderRadius(emphasis);
    final clipContent = emphasis <= 0.15;

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            _contentInset,
            12,
            _contentInset,
            8,
          ),
          child: header,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: _contentInset),
          child: Divider(
            height: 1,
            thickness: 1,
            color: const Color(0xFFB8C3D8).withValues(alpha: 0.9),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(_contentInset),
          child: child,
        ),
      ],
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: shellShadowExtent),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: borderRadius,
          border: Border.all(
            color: borderColor,
            width: 1.1 + emphasis * 0.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05 + emphasis * 0.015),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: clipContent
            ? ClipRRect(borderRadius: borderRadius, child: content)
            : content,
      ),
    );
  }
}

class _EmptyPilhaFace extends StatelessWidget {
  const _EmptyPilhaFace({required this.pilhaName});

  final String pilhaName;

  @override
  Widget build(BuildContext context) {
    return TaskCardTokens.shell(
      child: Padding(
        padding: const EdgeInsets.all(TaskCardTokens.padding),
        child: Text(
          pilhaName,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: TaskCardTokens.primaryText,
          ),
        ),
      ),
    );
  }
}
