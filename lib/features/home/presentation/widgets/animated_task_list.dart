import 'package:flutter/material.dart';

import '../../../tasks/presentation/widgets/task_stack_drag.dart';

/// Lista vertical que anima o deslocamento quando a ordem dos itens muda.
class AnimatedTaskList<T> extends StatefulWidget {
  const AnimatedTaskList({
    super.key,
    required this.items,
    required this.itemId,
    required this.itemBuilder,
    this.separatorExtent = 12,
    this.padding = EdgeInsets.zero,
    this.scrollController,
    this.animationDuration = const Duration(milliseconds: 380),
    this.animationCurve = Curves.easeInOutCubic,
    this.showExtractSlots = false,
    this.canAcceptExtract,
    this.onExtractDrop,
    this.extractSlotHeight = 36,
  });

  final List<T> items;
  final String Function(T item) itemId;
  final Widget Function(BuildContext context, T item) itemBuilder;
  final double separatorExtent;
  final EdgeInsetsGeometry padding;
  final ScrollController? scrollController;
  final Duration animationDuration;
  final Curve animationCurve;

  /// Exibe faixas de soltura entre itens para remover tarefa da pilha.
  final bool showExtractSlots;
  final bool Function(TaskDragData data)? canAcceptExtract;
  final ValueChanged<TaskDragData>? onExtractDrop;
  final double extractSlotHeight;

  @override
  State<AnimatedTaskList<T>> createState() => _AnimatedTaskListState<T>();
}

class _AnimatedTaskListState<T> extends State<AnimatedTaskList<T>>
    with SingleTickerProviderStateMixin {
  static const _fallbackItemExtent = 108.0;

  final Map<String, GlobalKey> _itemKeys = {};
  final Map<String, double> _itemHeights = {};

  late List<String> _layoutIds;
  Map<String, double> _activeOffsets = const {};
  late final AnimationController _controller;
  late final CurvedAnimation _curvedAnimation;

  @override
  void initState() {
    super.initState();
    _layoutIds = widget.items.map(widget.itemId).toList();
    _controller = AnimationController(
      vsync: this,
      duration: widget.animationDuration,
    );
    _curvedAnimation = CurvedAnimation(
      parent: _controller,
      curve: widget.animationCurve,
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed && mounted) {
          setState(() => _activeOffsets = const {});
        }
      });
    _scheduleHeightCapture();
  }

  @override
  void didUpdateWidget(covariant AnimatedTaskList<T> oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.showExtractSlots != widget.showExtractSlots) {
      _itemHeights.clear();
      _activeOffsets = const {};
      if (_controller.isAnimating) {
        _controller.stop();
      }
    }

    final oldIds = oldWidget.items.map(widget.itemId).toList();
    final newIds = widget.items.map(widget.itemId).toList();

    if (_listEquals(oldIds, newIds)) {
      if (!_controller.isAnimating && !_listEquals(_layoutIds, newIds)) {
        setState(() => _layoutIds = newIds);
      }
      return;
    }

    if (_sameIdsInDifferentOrder(oldIds, newIds)) {
      _scheduleReorderAnimation(oldIds, newIds);
    } else {
      _layoutIds = newIds;
      _activeOffsets = const {};
      _scheduleHeightCapture();
    }
  }

  void _scheduleHeightCapture() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _captureHeights();
    });
  }

  @override
  void dispose() {
    _curvedAnimation.dispose();
    _controller.dispose();
    super.dispose();
  }

  bool _sameIdsInDifferentOrder(List<String> oldIds, List<String> newIds) {
    if (oldIds.length != newIds.length) return false;
    if (oldIds.length < 2) return false;

    final oldSet = oldIds.toSet();
    final newSet = newIds.toSet();
    if (oldSet.length != newSet.length || !oldSet.containsAll(newSet)) {
      return false;
    }

    return !_listEquals(oldIds, newIds);
  }

  bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  void _scheduleReorderAnimation(List<String> oldIds, List<String> newIds) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _captureHeights();
      _startReorderAnimation(oldIds, newIds);
    });
  }

  void _startReorderAnimation(List<String> oldIds, List<String> newIds) {
    if (_controller.isAnimating) {
      _controller.stop();
    }

    final offsets = <String, double>{};
    for (final id in newIds) {
      final oldIndex = oldIds.indexOf(id);
      final newIndex = newIds.indexOf(id);
      if (oldIndex == -1 || newIndex == -1 || oldIndex == newIndex) continue;

      offsets[id] = _offsetForMove(id, oldIndex, newIndex, oldIds);
    }

    if (offsets.isEmpty) {
      setState(() => _layoutIds = newIds);
      return;
    }

    _controller.duration = widget.animationDuration;

    setState(() {
      _activeOffsets = offsets;
      _layoutIds = newIds;
    });

    _controller.forward(from: 0);
  }

  double _offsetForMove(
    String id,
    int oldIndex,
    int newIndex,
    List<String> oldIds,
  ) {
    if (oldIndex < newIndex) {
      var sum = 0.0;
      for (var i = oldIndex + 1; i <= newIndex; i++) {
        sum += _extentForId(oldIds[i]);
      }
      return -sum;
    }

    var sum = 0.0;
    for (var i = newIndex; i < oldIndex; i++) {
      sum += _extentForId(oldIds[i]);
    }
    return sum;
  }

  double _extentForId(String id) {
    return (_itemHeights[id] ?? _fallbackItemExtent) + widget.separatorExtent;
  }

  GlobalKey _keyFor(String id) {
    return _itemKeys.putIfAbsent(id, GlobalKey.new);
  }

  void _captureHeight(String id) {
    final context = _itemKeys[id]?.currentContext;
    if (context == null) return;

    final box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return;

    final height = box.size.height;
    if (_itemHeights[id] != height) {
      _itemHeights[id] = height;
    }
  }

  void _captureHeights() {
    for (final id in _layoutIds) {
      _captureHeight(id);
    }
  }

  List<T> get _orderedItems {
    final byId = {for (final item in widget.items) widget.itemId(item): item};
    return _layoutIds.map((id) => byId[id]).whereType<T>().toList();
  }

  @override
  Widget build(BuildContext context) {
    final items = _orderedItems;
    final showSlots = widget.showExtractSlots &&
        widget.canAcceptExtract != null &&
        widget.onExtractDrop != null;

    return ListView.separated(
      controller: widget.scrollController,
      clipBehavior: Clip.none,
      padding: widget.padding,
      itemCount: items.length,
      separatorBuilder: (context, index) {
        if (showSlots) {
          return TaskListInsertDropSlot(
            collapsedHeight: widget.separatorExtent,
            expandedHeight: widget.extractSlotHeight,
            canAccept: widget.canAcceptExtract!,
            onAccept: widget.onExtractDrop!,
          );
        }
        return SizedBox(height: widget.separatorExtent);
      },
      itemBuilder: (context, index) {
        final item = items[index];
        final id = widget.itemId(item);
        final initialOffset = _activeOffsets[id] ?? 0;

        Widget child = widget.itemBuilder(context, item);

        if (initialOffset != 0) {
          child = AnimatedBuilder(
            animation: _curvedAnimation,
            builder: (context, child) {
              final progress = _curvedAnimation.value;
              return Transform.translate(
                offset: Offset(0, initialOffset * (1 - progress)),
                child: child,
              );
            },
            child: child,
          );
        }

        if (showSlots && index == 0) {
          child = Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TaskListInsertDropSlot(
                collapsedHeight: widget.separatorExtent,
                expandedHeight: widget.extractSlotHeight,
                canAccept: widget.canAcceptExtract!,
                onAccept: widget.onExtractDrop!,
              ),
              child,
            ],
          );
        }

        if (showSlots && index == items.length - 1) {
          child = Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              child,
              TaskListInsertDropSlot(
                collapsedHeight: widget.separatorExtent,
                expandedHeight: widget.extractSlotHeight,
                canAccept: widget.canAcceptExtract!,
                onAccept: widget.onExtractDrop!,
              ),
            ],
          );
        }

        return KeyedSubtree(
          key: _keyFor(id),
          child: child,
        );
      },
    );
  }
}
