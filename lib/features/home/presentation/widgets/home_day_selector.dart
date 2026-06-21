import 'dart:async' show Timer, unawaited;
import 'package:tasker_project/core/icons/tasker_icon.dart';

import 'package:hugeicons/hugeicons.dart';

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../../app/theme/tasker_colors.dart';
import '../../../tasks/domain/task.dart';
import '../../../tasks/presentation/state/task_store.dart';
import '../../../tasks/presentation/widgets/task_stack_drag.dart';
import 'home_day_selector_drag_scope.dart';

/// Seletor horizontal de dias com janela lazy (carrega mais ao rolar).
class HomeDaySelector extends StatefulWidget {
  const HomeDaySelector({
    super.key,
    required this.selectedDate,
    required this.onDateSelected,
    this.edgeFadeWidth = 20,
    this.initialDaysBefore = 10,
    this.initialDaysAfter = 10,
    this.loadPageSize = 10,
    this.dragController,
    this.onTaskDroppedOnDay,
  });

  final DateTime selectedDate;
  final ValueChanged<DateTime> onDateSelected;

  /// Largura do fade nas bordas (igual ao padding horizontal do app).
  final double edgeFadeWidth;

  /// Dias carregados inicialmente antes e depois de hoje.
  final int initialDaysBefore;
  final int initialDaysAfter;

  /// Quantos dias extras carregar ao chegar perto de uma borda.
  final int loadPageSize;

  /// Ponte para receber posição do arrasto de tarefas.
  final HomeDaySelectorDragController? dragController;

  /// Soltar uma tarefa em um dia — reagendar.
  final Future<void> Function(Task task, DateTime day)? onTaskDroppedOnDay;

  @override
  State<HomeDaySelector> createState() => _HomeDaySelectorState();
}

class _HomeDaySelectorState extends State<HomeDaySelector>
    with TickerProviderStateMixin {
  late DateTime _firstDay;
  late DateTime _lastDay;
  late final ScrollController _scrollController;

  double _listWidth = 0;
  bool _pendingInitialScroll = true;
  bool _initialScrollScheduled = false;
  _TodayOffscreenSide _todayOffscreenSide = _TodayOffscreenSide.none;
  bool _loadingEarlier = false;
  bool _loadingLater = false;

  final GlobalKey _viewportKey = GlobalKey();
  Timer? _dragAutoScrollTimer;
  double _dragScrollVelocity = 0;
  bool _isDragOverSelector = false;

  late final AnimationController _expandController;
  late final CurvedAnimation _expandAnim;

  Ticker? _expandFollowTicker;
  Duration _expandFollowLastElapsed = Duration.zero;
  double _expandRawTarget = 0;

  /// Velocidade do acompanhamento suave durante o arrasto (maior = mais snappy).
  static const double _expandFollowSpeed = 26;

  static const double _chipSpacing = 6;
  static const double _dragDropZoneHeight = 96;
  static const double _dragEdgeThreshold = 56;
  static const double _dragMaxScrollSpeed = 20;

  /// Distância abaixo do seletor onde as pílulas começam a crescer.
  static const double _dragApproachBelow = 56;

  /// Distância acima do seletor (menor — tarefas vêm da lista abaixo).
  static const double _dragApproachAbove = 22;

  /// Tolerância horizontal fora da faixa do seletor.
  static const double _dragApproachHorizontal = 10;

  /// Expansão mínima visível + pausa do scroll vertical da lista.
  static const double _dragApproachActivate = 0.1;

  double get _expandT => _expandAnim.value.clamp(0.0, 1.0);

  double _chipWidthForExpand([double? t]) =>
      _DayChip.width + _DayChip.dragWidthExpand * (t ?? _expandT);

  double _itemStrideForExpand([double? t]) =>
      _chipWidthForExpand(t) + _chipSpacing;

  /// Itens visíveis antes do fim da janela para disparar o próximo lote.
  static const int _loadThresholdItems = 3;

  /// Recuo lateral do botão «Hoje».
  static const double _returnToTodaySideInset = 14;

  static const double _visibilityEpsilon = 2;

  static final _weekdayFormat = DateFormat('EEE', 'pt_BR');
  static final _monthFormat = DateFormat('MMM', 'pt_BR');

  /// Dia da semana no mês em foco; mês abreviado fora do mês selecionado.
  static String _chipCaptionLabel(DateTime day, DateTime viewedDay) {
    final d = TaskStore.dateOnly(day);
    final viewed = TaskStore.dateOnly(viewedDay);
    if (d.year == viewed.year && d.month == viewed.month) {
      return _weekdayFormat.format(d).toUpperCase();
    }
    return _monthFormat.format(d).toUpperCase();
  }

  @override
  void initState() {
    super.initState();
    final today = TaskStore.dateOnly(DateTime.now());
    _firstDay = today.subtract(Duration(days: widget.initialDaysBefore));
    _lastDay = today.add(Duration(days: widget.initialDaysAfter));
    _scrollController = ScrollController()..addListener(_onScroll);
    _expandController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 340),
      reverseDuration: const Duration(milliseconds: 220),
    );
    _expandAnim = CurvedAnimation(
      parent: _expandController,
      curve: Curves.easeOutBack,
      reverseCurve: Curves.easeInCubic,
    );
    _attachDragController();
  }

  void _attachDragController() {
    widget.dragController?.attach((
      handleDragPosition: _handleDragPosition,
      stopAutoScroll: _stopDragAutoScroll,
      onDragEnded: _onExternalDragEnded,
    ));
  }

  @override
  void didUpdateWidget(covariant HomeDaySelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.dragController != widget.dragController) {
      oldWidget.dragController?.detach();
      _attachDragController();
    }
    if (!_sameDay(oldWidget.selectedDate, widget.selectedDate)) {
      _collapseDragExpand();
      _ensureDateInWindow(widget.selectedDate);
      _scheduleAlignToSelected(animate: true);
    }
  }

  double get _dropZoneHeight => _dragDropZoneHeight * _expandT;

  /// Sombra superior + pílula + extensão inferior + margem de sombra.
  double get _selectorHeight => _DayChip.outerHeight + _dropZoneHeight;

  /// 0 = longe · 1 = sobre o seletor (com rampa de aproximação).
  double _expandTargetForDragPosition(Offset local, Size size) {
    final inside = local.dx >= 0 &&
        local.dx <= size.width &&
        local.dy >= 0 &&
        local.dy <= size.height;
    if (inside) return 1.0;

    if (local.dx < -_dragApproachHorizontal ||
        local.dx > size.width + _dragApproachHorizontal) {
      return 0.0;
    }

    if (local.dy > size.height) {
      final distance = local.dy - size.height;
      if (distance >= _dragApproachBelow) return 0.0;
      final t = 1 - (distance / _dragApproachBelow);
      return Curves.easeOutCubic.transform(t.clamp(0.0, 1.0));
    }

    if (local.dy < 0) {
      final distance = -local.dy;
      if (distance >= _dragApproachAbove) return 0.0;
      final t = 1 - (distance / _dragApproachAbove);
      return Curves.easeOutCubic.transform(t.clamp(0.0, 1.0)) * 0.85;
    }

    return 0.0;
  }

  void _stopExpandFollow() {
    _expandFollowTicker?.stop();
    _expandFollowLastElapsed = Duration.zero;
  }

  void _tickExpandFollow(Duration elapsed) {
    if (!mounted) return;

    final dt = _expandFollowLastElapsed == Duration.zero
        ? 0
        : (elapsed - _expandFollowLastElapsed).inMicroseconds / 1000000.0;
    _expandFollowLastElapsed = elapsed;
    if (dt <= 0) return;

    final target = _expandRawTarget;
    final current = _expandController.value;
    final delta = target - current;

    if (delta.abs() < 0.0015) {
      if (current != target) _expandController.value = target;
      _stopExpandFollow();
      return;
    }

    final step = (1 - math.exp(-dt * _expandFollowSpeed)).clamp(0.0, 1.0);
    _expandController.value = current + delta * step;
  }

  void _ensureExpandFollowTicking() {
    _expandFollowTicker ??= createTicker(_tickExpandFollow);
    if (!_expandFollowTicker!.isActive) {
      _expandFollowLastElapsed = Duration.zero;
      _expandFollowTicker!.start();
    }
  }

  void _applyDragExpand(double target) {
    final clamped = target.clamp(0.0, 1.0);
    final active = clamped > 0.001;
    _expandRawTarget = clamped;
    _isDragOverSelector = active;

    if ((clamped - _expandController.value).abs() < 0.0015 &&
        (_expandFollowTicker == null || !_expandFollowTicker!.isActive)) {
      return;
    }
    _ensureExpandFollowTicking();
  }

  bool _handleDragPosition(Offset globalPosition) {
    final box =
        _viewportKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) {
      _applyDragExpand(0);
      _stopDragAutoScroll();
      return false;
    }

    final local = box.globalToLocal(globalPosition);
    final size = box.size;
    final expandTarget = _expandTargetForDragPosition(local, size);
    _applyDragExpand(expandTarget);

    final directlyOver = expandTarget >= 1.0;

    if (!directlyOver) {
      _stopDragAutoScroll();
      return expandTarget >= _dragApproachActivate;
    }

    double velocity = 0;
    if (local.dx < _dragEdgeThreshold) {
      velocity = -_dragSpeedForDistance(local.dx, _dragEdgeThreshold);
    } else if (local.dx > size.width - _dragEdgeThreshold) {
      velocity =
          _dragSpeedForDistance(size.width - local.dx, _dragEdgeThreshold);
    }

    if (velocity == 0) {
      _stopDragAutoScroll();
      return true;
    }

    _dragScrollVelocity = velocity;
    _dragAutoScrollTimer ??= Timer.periodic(
      const Duration(milliseconds: 16),
      (_) => _tickDragAutoScroll(),
    );
    return true;
  }

  double _dragSpeedForDistance(double distanceFromEdge, double threshold) {
    final t = (1 - (distanceFromEdge / threshold).clamp(0.0, 1.0));
    return _dragMaxScrollSpeed * t * t;
  }

  void _tickDragAutoScroll() {
    if (!_scrollController.hasClients) return;

    final position = _scrollController.position;
    final next = (position.pixels + _dragScrollVelocity)
        .clamp(position.minScrollExtent, position.maxScrollExtent);

    if ((next - position.pixels).abs() < 0.1) {
      _stopDragAutoScroll();
      return;
    }

    _scrollController.jumpTo(next);
    _maybeLoadMoreDays();
  }

  void _stopDragAutoScroll() {
    _dragScrollVelocity = 0;
    _dragAutoScrollTimer?.cancel();
    _dragAutoScrollTimer = null;
  }

  void _onExternalDragEnded() {
    _collapseDragExpand();
  }

  void _collapseDragExpand() {
    _stopDragAutoScroll();
    _stopExpandFollow();
    _expandRawTarget = 0;
    final needsUpdate =
        _isDragOverSelector || _expandController.value > 0.001;
    _isDragOverSelector = false;
    if (!needsUpdate) return;
    if (_expandController.value > 0) {
      _expandController.stop();
      _expandController.animateTo(
        0,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeInCubic,
      );
    } else {
      _expandController.value = 0;
    }
  }

  bool _canDropTaskOnDay(Task task, DateTime day) {
    if (widget.onTaskDroppedOnDay == null) return false;
    final targetYmd = TaskStore.formatDateYmd(day);
    final todayYmd = TaskStore.formatDateYmd(DateTime.now());
    final taskYmd = task.data.isEmpty ? todayYmd : task.data;
    return taskYmd != targetYmd;
  }

  Future<void> _handleTaskDrop(Task task, DateTime day) async {
    _collapseDragExpand();
    await widget.onTaskDroppedOnDay?.call(task, day);
  }

  void _onScroll() {
    _syncTodayVisibility();
    _maybeLoadMoreDays();
  }

  int get _totalDays => _lastDay.difference(_firstDay).inDays + 1;

  double get _loadThresholdPx => _itemStrideForExpand(0) * _loadThresholdItems;

  void _ensureDateInWindow(DateTime date) {
    final d = TaskStore.dateOnly(date);
    if (d.isBefore(_firstDay)) {
      final needed = _firstDay.difference(d).inDays;
      final expand = ((needed + widget.loadPageSize) ~/ widget.loadPageSize) *
          widget.loadPageSize;
      _firstDay = _firstDay.subtract(Duration(days: expand));
    }
    if (d.isAfter(_lastDay)) {
      final needed = d.difference(_lastDay).inDays;
      final expand = ((needed + widget.loadPageSize) ~/ widget.loadPageSize) *
          widget.loadPageSize;
      _lastDay = _lastDay.add(Duration(days: expand));
    }
  }

  void _maybeLoadMoreDays() {
    if (!_scrollController.hasClients || _listWidth <= 0) return;

    final position = _scrollController.position;
    final offset = position.pixels;
    final max = position.maxScrollExtent;
    final threshold = _loadThresholdPx;

    if (offset <= threshold) {
      unawaited(_loadEarlierDays());
    } else if (max - offset <= threshold) {
      unawaited(_loadLaterDays());
    }
  }

  Future<void> _loadEarlierDays() async {
    if (_loadingEarlier) return;
    _loadingEarlier = true;
    if (mounted) setState(() {});

    // Deixa o spinner aparecer antes de expandir a lista (scroll rápido).
    await Future<void>.delayed(const Duration(milliseconds: 50));
    if (!mounted) return;

    final addCount = widget.loadPageSize;
    final offsetDelta = addCount * _itemStrideForExpand(0);
    final currentOffset =
        _scrollController.hasClients ? _scrollController.offset : 0.0;

    setState(() {
      _firstDay = _firstDay.subtract(Duration(days: addCount));
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      _scrollController.jumpTo(currentOffset + offsetDelta);
      _syncTodayVisibility();
      if (mounted) {
        setState(() => _loadingEarlier = false);
        _maybeLoadMoreDays();
      }
    });
  }

  Future<void> _loadLaterDays() async {
    if (_loadingLater) return;
    _loadingLater = true;
    if (mounted) setState(() {});

    await Future<void>.delayed(const Duration(milliseconds: 50));
    if (!mounted) return;

    setState(() {
      _lastDay = _lastDay.add(Duration(days: widget.loadPageSize));
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _syncTodayVisibility();
      if (mounted) {
        setState(() => _loadingLater = false);
        _maybeLoadMoreDays();
      }
    });
  }

  void _scheduleAlignToSelected({required bool animate, int attempt = 0}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final aligned = _alignToSelectedDay(animate: animate);
      if (!aligned && attempt < 10) {
        _scheduleAlignToSelected(animate: animate, attempt: attempt + 1);
      } else {
        _pendingInitialScroll = false;
      }
    });
  }

  @override
  void dispose() {
    widget.dragController?.detach();
    _stopDragAutoScroll();
    _stopExpandFollow();
    _expandFollowTicker?.dispose();
    _expandAnim.dispose();
    _expandController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  int _dayIndexFor(DateTime date) {
    return TaskStore.dateOnly(date).difference(_firstDay).inDays;
  }

  DateTime _dateAtIndex(int index) {
    return DateTime(
      _firstDay.year,
      _firstDay.month,
      _firstDay.day + index,
    );
  }

  /// Retorna `true` quando o scroll foi aplicado (lista pronta).
  bool _alignToSelectedDay({required bool animate}) =>
      _alignToDate(widget.selectedDate, animate: animate);

  bool _alignToDate(DateTime date, {required bool animate}) {
    if (!_scrollController.hasClients) return false;

    _ensureDateInWindow(date);

    final index = _dayIndexFor(date).clamp(0, _totalDays - 1);
    final position = _scrollController.position;
    final viewport = _listWidth > 0 ? _listWidth : position.viewportDimension;
    if (viewport <= 0) return false;

    // Lista ainda não mediu o conteúdo — maxScrollExtent 0 com índice > 0.
    if (position.maxScrollExtent <= 0 && index > 0) return false;

    final chipWidth = _chipWidthForExpand(0);
    final itemStride = _itemStrideForExpand(0);
    final target = (index * itemStride) - (viewport - chipWidth) / 2;
    final clamped = target.clamp(0.0, position.maxScrollExtent);

    if (animate) {
      _scrollController.animateTo(
        clamped,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    } else {
      _scrollController.jumpTo(clamped);
    }
    _syncTodayVisibility();
    return true;
  }

  static bool _sameDay(DateTime a, DateTime b) {
    final da = TaskStore.dateOnly(a);
    final db = TaskStore.dateOnly(b);
    return da.year == db.year && da.month == db.month && da.day == db.day;
  }

  void _syncTodayVisibility() {
    if (!_scrollController.hasClients || _listWidth <= 0) return;

    final today = TaskStore.dateOnly(DateTime.now());
    final todayIndex = _dayIndexFor(today).clamp(0, _totalDays - 1);
    final chipWidth = _chipWidthForExpand(0);
    final itemStride = _itemStrideForExpand(0);
    final offset = _scrollController.offset;
    final viewportEnd = offset + _listWidth;

    final todayStart = todayIndex * itemStride;
    final todayEnd = todayStart + chipWidth;

    final next = todayEnd <= offset + _visibilityEpsilon
        ? _TodayOffscreenSide.left
        : todayStart >= viewportEnd - _visibilityEpsilon
            ? _TodayOffscreenSide.right
            : _TodayOffscreenSide.none;

    if (next == _todayOffscreenSide) return;
    setState(() => _todayOffscreenSide = next);
  }

  void _returnToToday() {
    final today = TaskStore.dateOnly(DateTime.now());
    if (!_sameDay(widget.selectedDate, today)) {
      widget.onDateSelected(today);
      return;
    }
    _alignToDate(today, animate: true);
  }

  @override
  Widget build(BuildContext context) {
    final selected = TaskStore.dateOnly(widget.selectedDate);
    final today = TaskStore.dateOnly(DateTime.now());

    return Selector<TaskStore, int>(
      selector: (_, store) => store.statsVersion,
      builder: (context, _, __) {
        final store = context.read<TaskStore>();

        return LayoutBuilder(
          builder: (context, constraints) {
            _listWidth = constraints.maxWidth;

            if (_pendingInitialScroll && !_initialScrollScheduled) {
              _initialScrollScheduled = true;
              _scheduleAlignToSelected(animate: false);
            }

            final fadeWidth = widget.edgeFadeWidth;

            return AnimatedBuilder(
              animation: _expandAnim,
              builder: (context, _) {
                final expandT = _expandT;
                final chipWidth = _chipWidthForExpand(expandT);
                final itemStride = _itemStrideForExpand(expandT);

                return SizedBox(
                  height: _selectorHeight,
                  child: ClipRect(
                    child: Stack(
                      key: _viewportKey,
                      clipBehavior: Clip.hardEdge,
                      children: [
                        ClipRect(
                          child: ShaderMask(
                            blendMode: BlendMode.dstIn,
                            shaderCallback: (bounds) =>
                                _horizontalEdgeMaskShader(bounds, fadeWidth),
                            child: RepaintBoundary(
                              child: ListView.builder(
                                controller: _scrollController,
                                scrollDirection: Axis.horizontal,
                                clipBehavior: Clip.hardEdge,
                                physics: const BouncingScrollPhysics(),
                                addRepaintBoundaries: false,
                                itemCount: _totalDays,
                                itemExtent: itemStride,
                                itemBuilder: (context, index) {
                                  final day = _dateAtIndex(index);
                                  return _DayChipSlot(
                                    key: ValueKey(day),
                                    day: day,
                                    itemStride: itemStride,
                                    chipWidth: chipWidth,
                                    expandT: expandT,
                                    dropZoneHeight: _dragDropZoneHeight,
                                    enabled:
                                        widget.onTaskDroppedOnDay != null,
                                    weekdayLabel: _chipCaptionLabel(
                                        day, selected),
                                    isSelected: _sameDay(day, selected),
                                    isToday: _sameDay(day, today),
                                    stats: store.taskStatsForDate(day),
                                    onTap: () => widget.onDateSelected(day),
                                    canAccept: (data) =>
                                        _canDropTaskOnDay(data.task, day),
                                    onAccept: (data) =>
                                        _handleTaskDrop(data.task, day),
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                        if (_todayOffscreenSide == _TodayOffscreenSide.left)
                          Positioned(
                            left: _returnToTodaySideInset,
                            top: 0,
                            bottom: 0,
                            child: Center(
                              child: _ReturnToTodayButton(
                                todayOnLeft: true,
                                onPressed: _returnToToday,
                              ),
                            ),
                          ),
                        if (_todayOffscreenSide == _TodayOffscreenSide.right)
                          Positioned(
                            right: _returnToTodaySideInset,
                            top: 0,
                            bottom: 0,
                            child: Center(
                              child: _ReturnToTodayButton(
                                todayOnLeft: false,
                                onPressed: _returnToToday,
                              ),
                            ),
                          ),
                        if (_loadingEarlier)
                          const Positioned(
                            left: 6,
                            top: 0,
                            bottom: 0,
                            child: Center(
                              child: _DaySelectorEdgeSpinner(),
                            ),
                          ),
                        if (_loadingLater)
                          const Positioned(
                            right: 6,
                            top: 0,
                            bottom: 0,
                            child: Center(
                              child: _DaySelectorEdgeSpinner(),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  /// Máscara horizontal: bordas transparentes, centro opaco — elimina vazamento.
  static Shader _horizontalEdgeMaskShader(Rect bounds, double fadeWidth) {
    if (bounds.width <= 0 || fadeWidth <= 0) {
      return const LinearGradient(
        colors: [Color(0xFFFFFFFF), Color(0xFFFFFFFF)],
      ).createShader(bounds);
    }

    final stop = (fadeWidth / bounds.width).clamp(0.05, 0.45);
    return LinearGradient(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
      colors: const [
        Color(0x00000000),
        Color(0xFFFFFFFF),
        Color(0xFFFFFFFF),
        Color(0x00000000),
      ],
      stops: [0, stop, 1 - stop, 1],
    ).createShader(bounds);
  }
}

enum _TodayOffscreenSide { none, left, right }

/// Spinner nas bordas enquanto mais dias são carregados.
class _DaySelectorEdgeSpinner extends StatelessWidget {
  const _DaySelectorEdgeSpinner();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 22,
      height: 22,
      child: CircularProgressIndicator(
        strokeWidth: 2.2,
        color: TaskerColors.primary.withValues(alpha: 0.85),
      ),
    );
  }
}

/// Atalho para recentralizar o scroll no dia de hoje quando ele sai da vista.
class _ReturnToTodayButton extends StatelessWidget {
  const _ReturnToTodayButton({
    required this.todayOnLeft,
    required this.onPressed,
  });

  /// Hoje ficou à esquerda da área visível — seta aponta para a esquerda.
  final bool todayOnLeft;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: TaskerColors.cardBackground,
      elevation: 3,
      shadowColor: const Color(0x22000000),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (todayOnLeft) ...[
                AppHugeIcon(icon: HugeIcons.strokeRoundedArrowLeft01,
                  size: 16,
                  color: TaskerColors.primary,
                ),
                const SizedBox(width: 1),
              ],
              AppHugeIcon(icon: HugeIcons.strokeRoundedCalendarCheckIn01,
                size: 14,
                color: TaskerColors.primary,
              ),
              const SizedBox(width: 4),
              Text(
                'Hoje',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: TaskerColors.primary,
                  letterSpacing: -0.1,
                ),
              ),
              if (!todayOnLeft) ...[
                const SizedBox(width: 1),
                AppHugeIcon(icon: HugeIcons.strokeRoundedArrowRight01,
                  size: 16,
                  color: TaskerColors.primary,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Slot de layout de uma pílula — estável entre frames via [ValueKey] do dia.
class _DayChipSlot extends StatelessWidget {
  const _DayChipSlot({
    super.key,
    required this.day,
    required this.itemStride,
    required this.chipWidth,
    required this.expandT,
    required this.dropZoneHeight,
    required this.enabled,
    required this.weekdayLabel,
    required this.isSelected,
    required this.isToday,
    required this.stats,
    required this.onTap,
    required this.canAccept,
    required this.onAccept,
  });

  final DateTime day;
  final double itemStride;
  final double chipWidth;
  final double expandT;
  final double dropZoneHeight;
  final bool enabled;
  final String weekdayLabel;
  final bool isSelected;
  final bool isToday;
  final ({int total, int completed}) stats;
  final VoidCallback onTap;
  final bool Function(TaskDragData data) canAccept;
  final ValueChanged<TaskDragData> onAccept;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: itemStride,
      child: Padding(
        padding: const EdgeInsets.only(right: 6),
        child: Align(
          alignment: Alignment.topLeft,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              vertical: _DayChip.shadowBleed,
            ),
            child: SizedBox(
              width: chipWidth,
              child: RepaintBoundary(
                child: _DayChipDropTarget(
                  enabled: enabled,
                  expandT: expandT,
                  dropZoneHeight: dropZoneHeight,
                  canAccept: canAccept,
                  onAccept: onAccept,
                  date: day,
                  weekdayLabel: weekdayLabel,
                  isSelected: isSelected,
                  isToday: isToday,
                  stats: stats,
                  onTap: onTap,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Destino de soltura — a própria pílula cresce para baixo mantendo conteúdo no topo.
class _DayChipDropTarget extends StatelessWidget {
  const _DayChipDropTarget({
    required this.date,
    required this.weekdayLabel,
    required this.isSelected,
    required this.isToday,
    required this.stats,
    required this.onTap,
    required this.expandT,
    required this.dropZoneHeight,
    required this.canAccept,
    required this.onAccept,
    this.enabled = true,
  });

  final DateTime date;
  final String weekdayLabel;
  final bool isSelected;
  final bool isToday;
  final ({int total, int completed}) stats;
  final VoidCallback onTap;
  final double expandT;
  final double dropZoneHeight;
  final bool Function(TaskDragData data) canAccept;
  final ValueChanged<TaskDragData> onAccept;
  final bool enabled;

  void _handleAccept(TaskDragData data) {
    HapticFeedback.lightImpact();
    onAccept(data);
  }

  @override
  Widget build(BuildContext context) {
    if (!enabled) {
      return _DayChip(
        date: date,
        weekdayLabel: weekdayLabel,
        isSelected: isSelected,
        isToday: isToday,
        stats: stats,
        onTap: onTap,
        expandT: expandT,
        dropZoneHeight: dropZoneHeight,
      );
    }

    return DragTarget<TaskDragData>(
      onWillAcceptWithDetails: (details) => canAccept(details.data),
      onAcceptWithDetails: (details) => _handleAccept(details.data),
      builder: (context, candidate, rejected) {
        return _DayChip(
          date: date,
          weekdayLabel: weekdayLabel,
          isSelected: isSelected,
          isToday: isToday,
          stats: stats,
          onTap: onTap,
          expandT: expandT,
          dropZoneHeight: dropZoneHeight,
          dropHovering: candidate.isNotEmpty,
        );
      },
    );
  }
}

class _DayChip extends StatelessWidget {
  const _DayChip({
    required this.date,
    required this.weekdayLabel,
    required this.isSelected,
    required this.isToday,
    required this.stats,
    required this.onTap,
    required this.expandT,
    required this.dropZoneHeight,
    this.dropHovering = false,
  });

  final DateTime date;
  final String weekdayLabel;
  final bool isSelected;
  final bool isToday;
  final ({int total, int completed}) stats;
  final VoidCallback onTap;
  final double expandT;
  final double dropZoneHeight;
  final bool dropHovering;

  static const double _horizontalPadding = 4;
  static const double _verticalPadding = 12;

  /// Largura base — envolve número, rótulo e indicador (não estica com a tela).
  static const double width = 58;

  /// Largura extra durante arrasto (distribuída no layout, sem sobreposição).
  static const double dragWidthExpand = 6;

  static const double borderRadius = 22;
  static const double _dayFontSize = 22;
  static const double _weekdayFontSize = 11;
  static const double _gapDayToWeekday = 3;
  static const double _gapBeforeIndicator = 6;

  /// Espaço para sombra da pílula selecionada não ser cortada (topo + base).
  static const double shadowBleed = 6;

  /// Extensão inferior da [BoxShadow] do dia selecionado (offset + blur).
  static const double selectedShadowExtent = 4;

  static const double _dropHighlightBorderWidth = 2;

  /// Altura do conteúdo da pílula.
  static double get intrinsicHeight =>
      _verticalPadding * 2 +
      _dayFontSize +
      _gapDayToWeekday +
      _weekdayFontSize +
      _gapBeforeIndicator +
      _DayTaskIndicator.size;

  /// Altura total reservada (conteúdo + margem da sombra + sombra do selecionado).
  static double get outerHeight =>
      intrinsicHeight + shadowBleed * 2 + selectedShadowExtent;

  @override
  Widget build(BuildContext context) {
    final dayColor = isToday
        ? TaskerColors.primary
        : isSelected
            ? TaskerColors.primaryText
            : TaskerColors.secondaryText;
    final weekdayColor = isToday
        ? TaskerColors.primary
        : isSelected
            ? TaskerColors.secondaryText
            : TaskerColors.mutedText;

    final chipWidth = width + dragWidthExpand * expandT;
    final extraBottomExtent = expandT * dropZoneHeight;
    final shellHeight = intrinsicHeight + extraBottomExtent;
    final shadowTail = isSelected ? selectedShadowExtent : 0.0;
    final bgColor = isSelected
        ? TaskerColors.cardBackground
        : dropHovering
            ? TaskerColors.cardBackground.withValues(alpha: 0.92)
            : const Color(0x66FFFFFF);

    return Material(
      color: Colors.transparent,
      clipBehavior: Clip.none,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(borderRadius),
        splashColor: TaskerColors.primary.withValues(alpha: 0.1),
        highlightColor: Colors.transparent,
        child: SizedBox(
          width: chipWidth,
          height: shellHeight + shadowTail,
          child: Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: chipWidth,
              height: shellHeight,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: double.infinity,
                    height: shellHeight,
                    padding: EdgeInsets.fromLTRB(
                      _horizontalPadding,
                      _verticalPadding,
                      _horizontalPadding,
                      _verticalPadding + extraBottomExtent,
                    ),
                    decoration: BoxDecoration(
                      color: bgColor,
                      borderRadius: BorderRadius.circular(borderRadius),
                      boxShadow: isSelected
                          ? const [
                              BoxShadow(
                                color: Color.fromARGB(41, 0, 0, 0),
                                blurRadius: 1,
                                offset: Offset(0, 1),
                              ),
                            ]
                          : dropHovering
                              ? [
                                  BoxShadow(
                                    color: TaskerColors.primary
                                        .withValues(alpha: 0.18),
                                    blurRadius: 10,
                                  ),
                                ]
                              : null,
                    ),
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${date.day}',
                            style: TextStyle(
                              fontSize: _dayFontSize,
                              fontWeight: FontWeight.w700,
                              height: 1,
                              color: dayColor,
                            ),
                          ),
                          const SizedBox(height: _gapDayToWeekday),
                          Text(
                            weekdayLabel,
                            style: TextStyle(
                              fontSize: _weekdayFontSize,
                              fontWeight: FontWeight.w600,
                              height: 1,
                              letterSpacing: 0.3,
                              color: weekdayColor,
                            ),
                          ),
                          const SizedBox(height: _gapBeforeIndicator),
                          _DayTaskIndicator(
                            total: stats.total,
                            completed: stats.completed,
                            isSelected: isSelected,
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (dropHovering)
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      height: shellHeight,
                      child: IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius:
                                BorderRadius.circular(borderRadius),
                            border: Border.all(
                              color: TaskerColors.primary
                                  .withValues(alpha: 0.9),
                              width: _dropHighlightBorderWidth,
                            ),
                          ),
                        ),
                      ),
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

class _DayTaskIndicator extends StatefulWidget {
  const _DayTaskIndicator({
    required this.total,
    required this.completed,
    required this.isSelected,
  });

  final int total;
  final int completed;
  final bool isSelected;

  static const double size = 30;

  @override
  State<_DayTaskIndicator> createState() => _DayTaskIndicatorState();
}

class _DayTaskIndicatorState extends State<_DayTaskIndicator>
    with SingleTickerProviderStateMixin {
  static const Color _dayCompleteGreen = Color(0xFF3DBE6A);
  static const Color _progressYellow = Color(0xFFFFC107);
  static const Duration _progressDuration = Duration(milliseconds: 480);

  late final AnimationController _controller;
  late Animation<double> _progressAnim;

  double _animatedProgress = 0;
  bool _showCheck = false;

  bool get _allDone => widget.total > 0 && widget.completed >= widget.total;
  bool get _isEmpty => widget.total == 0;

  double _targetProgress() {
    if (widget.total == 0) return 0;
    if (_allDone) return 1;
    return widget.completed / widget.total;
  }

  @override
  void initState() {
    super.initState();
    _animatedProgress = _targetProgress();
    _showCheck = _allDone;
    _controller = AnimationController(vsync: this, duration: _progressDuration)
      ..addStatusListener(_onAnimationStatus);
    _progressAnim = AlwaysStoppedAnimation(_animatedProgress);
  }

  @override
  void didUpdateWidget(covariant _DayTaskIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.completed == widget.completed &&
        oldWidget.total == widget.total) {
      return;
    }

    final target = _targetProgress();
    if (target < _animatedProgress || !_allDone) {
      _showCheck = false;
    }

    _progressAnim = Tween<double>(
      begin: _animatedProgress,
      end: target,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));

    _controller.forward(from: 0);
  }

  void _onAnimationStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      _animatedProgress = _targetProgress();
      if (_allDone && mounted) {
        setState(() => _showCheck = true);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_showCheck) {
      return SizedBox(
        width: _DayTaskIndicator.size,
        height: _DayTaskIndicator.size,
        child: AppHugeIcon(
          icon: HugeIcons.strokeRoundedCheckmarkCircle02,
          size: _DayTaskIndicator.size,
          color: _dayCompleteGreen,
        ),
      );
    }

    final trackColor = _isEmpty
        ? (widget.isSelected
            ? const Color(0xFFD8DEE8).withValues(alpha: 0.42)
            : const Color(0xFFC8CDD6).withValues(alpha: 0.32))
        : widget.isSelected
            ? const Color(0xFFD8DEE8)
            : const Color(0xFFC8CDD6);
    final progressColor =
        widget.isSelected ? TaskerColors.primary : _progressYellow;

    return AnimatedBuilder(
      animation: _progressAnim,
      builder: (context, child) {
        return SizedBox(
          width: _DayTaskIndicator.size,
          height: _DayTaskIndicator.size,
          child: CustomPaint(
            painter: _DayProgressRingPainter(
              progress: _progressAnim.value.clamp(0.0, 1.0),
              trackColor: trackColor,
              progressColor: progressColor,
              strokeWidth: 3,
            ),
            child: child,
          ),
        );
      },
      child: Center(
        child: Text(
          '${widget.total}',
          style: TextStyle(
            fontSize: widget.total > 9 ? 10 : 13,
            fontWeight: FontWeight.w700,
            color: _isEmpty
                ? (widget.isSelected
                    ? TaskerColors.primaryText.withValues(alpha: 0.42)
                    : TaskerColors.secondaryText.withValues(alpha: 0.38))
                : widget.isSelected
                    ? TaskerColors.primaryText
                    : TaskerColors.secondaryText,
          ),
        ),
      ),
    );
  }
}

class _DayProgressRingPainter extends CustomPainter {
  _DayProgressRingPainter({
    required this.progress,
    required this.trackColor,
    required this.progressColor,
    required this.strokeWidth,
  });

  final double progress;
  final Color trackColor;
  final Color progressColor;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    canvas.drawCircle(center, radius, trackPaint);

    if (progress <= 0) return;

    final progressPaint = Paint()
      ..color = progressColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final rect = Rect.fromCircle(center: center, radius: radius);
    canvas.drawArc(
      rect,
      -math.pi / 2,
      2 * math.pi * progress.clamp(0.0, 1.0),
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _DayProgressRingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.trackColor != trackColor ||
        oldDelegate.progressColor != progressColor ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}
