import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../../app/theme/tasker_colors.dart';
import '../../../tasks/presentation/state/task_store.dart';

/// Seletor de dias agrupado por semana (domingo → sábado).
class HomeDaySelector extends StatefulWidget {
  const HomeDaySelector({
    super.key,
    required this.selectedDate,
    required this.onDateSelected,
    this.edgeFadeWidth = 20,
    this.weeksBefore = 26,
    this.weeksAfter = 12,
  });

  final DateTime selectedDate;
  final ValueChanged<DateTime> onDateSelected;

  /// Largura do fade nas bordas (igual ao padding horizontal do app).
  final double edgeFadeWidth;

  /// Semanas anteriores à semana atual (âncora = hoje).
  final int weeksBefore;

  /// Semanas posteriores à semana atual.
  final int weeksAfter;

  @override
  State<HomeDaySelector> createState() => _HomeDaySelectorState();
}

class _HomeDaySelectorState extends State<HomeDaySelector> {
  late final DateTime _firstWeekStart;
  late final int _totalDays;
  late final ScrollController _scrollController;

  double _listWidth = 0;
  bool _pendingInitialScroll = true;
  bool _initialScrollScheduled = false;
  _TodayOffscreenSide _todayOffscreenSide = _TodayOffscreenSide.none;

  static const double _chipSpacing = 3;

  static const double _itemStride = _DayChip.width + _chipSpacing;

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
    final anchorWeek = _weekStart(DateTime.now());
    _firstWeekStart = anchorWeek.subtract(Duration(days: widget.weeksBefore * 7));
    _totalDays = (widget.weeksBefore + widget.weeksAfter + 1) * 7;
    _scrollController = ScrollController()..addListener(_syncTodayVisibility);
  }

  @override
  void didUpdateWidget(covariant HomeDaySelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_sameDay(oldWidget.selectedDate, widget.selectedDate)) return;

    _scheduleAlignToSelected(animate: true);
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
    _scrollController.dispose();
    super.dispose();
  }

  /// Domingo da semana que contém [date].
  static DateTime _weekStart(DateTime date) {
    final d = TaskStore.dateOnly(date);
    return DateTime(d.year, d.month, d.day - (d.weekday % 7));
  }

  static bool _sameDay(DateTime a, DateTime b) {
    final da = TaskStore.dateOnly(a);
    final db = TaskStore.dateOnly(b);
    return da.year == db.year && da.month == db.month && da.day == db.day;
  }

  int _dayIndexFor(DateTime date) {
    return TaskStore.dateOnly(date).difference(_firstWeekStart).inDays;
  }

  DateTime _dateAtIndex(int index) {
    return DateTime(
      _firstWeekStart.year,
      _firstWeekStart.month,
      _firstWeekStart.day + index,
    );
  }

  /// Retorna `true` quando o scroll foi aplicado (lista pronta).
  bool _alignToSelectedDay({required bool animate}) =>
      _alignToDate(widget.selectedDate, animate: animate);

  bool _alignToDate(DateTime date, {required bool animate}) {
    if (!_scrollController.hasClients) return false;

    final index = _dayIndexFor(date).clamp(0, _totalDays - 1);
    final position = _scrollController.position;
    final viewport = _listWidth > 0 ? _listWidth : position.viewportDimension;
    if (viewport <= 0) return false;

    // Lista ainda não mediu o conteúdo — maxScrollExtent 0 com índice > 0.
    if (position.maxScrollExtent <= 0 && index > 0) return false;

    final chipWidth = _DayChip.width;
    final itemStride = _itemStride;
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

  void _syncTodayVisibility() {
    if (!_scrollController.hasClients || _listWidth <= 0) return;

    final today = TaskStore.dateOnly(DateTime.now());
    final todayIndex = _dayIndexFor(today).clamp(0, _totalDays - 1);
    final chipWidth = _DayChip.width;
    final itemStride = _itemStride;
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

            final chipWidth = _DayChip.width;
            final itemStride = _itemStride;
            final fadeWidth = widget.edgeFadeWidth;

            return SizedBox(
              height: _DayChip.outerHeight,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  ClipRect(
                    child: ShaderMask(
                      blendMode: BlendMode.dstIn,
                      shaderCallback: (bounds) =>
                          _horizontalEdgeMaskShader(bounds, fadeWidth),
                      child: ListView.builder(
                        controller: _scrollController,
                        scrollDirection: Axis.horizontal,
                        clipBehavior: Clip.hardEdge,
                        physics: const BouncingScrollPhysics(),
                        itemCount: _totalDays,
                        itemExtent: itemStride,
                        itemBuilder: (context, index) {
                          final day = _dateAtIndex(index);
                          return Padding(
                            padding: const EdgeInsets.only(right: _chipSpacing),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: _DayChip.shadowBleed,
                                ),
                                child: SizedBox(
                                  width: chipWidth,
                                  child: RepaintBoundary(
                                    child: _DayChip(
                                      date: day,
                                      weekdayLabel:
                                          _chipCaptionLabel(day, selected),
                                      isSelected: _sameDay(day, selected),
                                      isToday: _sameDay(day, today),
                                      stats: store.taskStatsForDate(day),
                                      onTap: () => widget.onDateSelected(day),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
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
                ],
              ),
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
                Icon(
                  Icons.chevron_left_rounded,
                  size: 16,
                  color: TaskerColors.primary,
                ),
                const SizedBox(width: 1),
              ],
              Icon(
                Icons.today_rounded,
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
                Icon(
                  Icons.chevron_right_rounded,
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

class _DayChip extends StatelessWidget {
  const _DayChip({
    required this.date,
    required this.weekdayLabel,
    required this.isSelected,
    required this.isToday,
    required this.stats,
    required this.onTap,
  });

  final DateTime date;
  final String weekdayLabel;
  final bool isSelected;
  final bool isToday;
  final ({int total, int completed}) stats;
  final VoidCallback onTap;

  static const double _verticalPadding = 8;
  static const double _horizontalPadding = 4;
  static const double _todayOutlineWidth = 1.5;

  /// Largura fixa — envolve número, rótulo e indicador (não estica com a tela).
  static const double width = 52;
  static const double _dayFontSize = 22;
  static const double _weekdayFontSize = 11;
  static const double _gapDayToWeekday = 3;
  static const double _gapBeforeIndicator = 6;

  /// Espaço mínimo para a sombra da pílula selecionada não ser cortada.
  static const double shadowBleed = 5;

  /// Altura do conteúdo da pílula.
  static double get intrinsicHeight =>
      _verticalPadding * 2 +
      _dayFontSize +
      _gapDayToWeekday +
      _weekdayFontSize +
      _gapBeforeIndicator +
      _DayTaskIndicator.size;

  /// Altura total reservada (conteúdo + margem da sombra).
  static double get outerHeight => intrinsicHeight + shadowBleed * 2;

  @override
  Widget build(BuildContext context) {
    final showTodayOutline = isToday;
    final outlineInset = showTodayOutline ? _todayOutlineWidth : 0.0;

    return Material(
      color: Colors.transparent,
      clipBehavior: Clip.none,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: AnimatedContainer(
          width: double.infinity,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          padding: EdgeInsets.symmetric(
            vertical: _verticalPadding - outlineInset,
            horizontal: _horizontalPadding - outlineInset,
          ),
          decoration: BoxDecoration(
            color: isSelected
                ? TaskerColors.cardBackground
                : const Color(0x66FFFFFF),
            borderRadius: BorderRadius.circular(22),
            border: showTodayOutline
                ? Border.all(
                    color: TaskerColors.primary.withValues(alpha: 0.55),
                    width: _todayOutlineWidth,
                  )
                : null,
            boxShadow: isSelected
                ? const [
                    BoxShadow(
                      color: Color(0x1A000000),
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${date.day}',
                style: TextStyle(
                  fontSize: _dayFontSize,
                  fontWeight: FontWeight.w700,
                  height: 1,
                  color: isSelected
                      ? TaskerColors.primaryText
                      : showTodayOutline
                          ? TaskerColors.primary
                          : TaskerColors.secondaryText,
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
                  color: isSelected
                      ? TaskerColors.secondaryText
                      : showTodayOutline
                          ? TaskerColors.primary.withValues(alpha: 0.75)
                          : TaskerColors.mutedText,
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
  static const Color _successGreen = Color(0xFF3DBE6A);
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
      return Container(
        width: _DayTaskIndicator.size,
        height: _DayTaskIndicator.size,
        decoration: const BoxDecoration(
          color: _successGreen,
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: const Icon(
          Icons.check_rounded,
          size: 18,
          color: Colors.white,
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
