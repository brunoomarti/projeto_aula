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

  static const double _chipSpacing = 3;

  /// Largura visível ≈ 7,15 pílulas — mostra um pedaço da anterior/próxima na borda.
  static const double _visibleChips = 7.15;

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
    _scrollController = ScrollController();
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
  bool _alignToSelectedDay({required bool animate}) {
    if (!_scrollController.hasClients) return false;

    final index = _dayIndexFor(widget.selectedDate).clamp(0, _totalDays - 1);
    final position = _scrollController.position;
    final viewport = _listWidth > 0 ? _listWidth : position.viewportDimension;
    if (viewport <= 0) return false;

    // Lista ainda não mediu o conteúdo — maxScrollExtent 0 com índice > 0.
    if (position.maxScrollExtent <= 0 && index > 0) return false;

    final chipWidth = viewport / _visibleChips;
    final itemStride = chipWidth + _chipSpacing;
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
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<TaskStore>();
    final selected = TaskStore.dateOnly(widget.selectedDate);

    return ClipRect(
      clipBehavior: Clip.none,
      child: LayoutBuilder(
        builder: (context, constraints) {
          _listWidth = constraints.maxWidth;

          if (_pendingInitialScroll && !_initialScrollScheduled) {
            _initialScrollScheduled = true;
            _scheduleAlignToSelected(animate: false);
          }

          final chipWidth = constraints.maxWidth / _visibleChips;
          final itemStride = chipWidth + _chipSpacing;

          final fadeWidth = widget.edgeFadeWidth;

          return SizedBox(
            height: _DayChip.outerHeight,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                ListView.builder(
                  controller: _scrollController,
                  scrollDirection: Axis.horizontal,
                  clipBehavior: Clip.none,
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
                            child: _DayChip(
                              date: day,
                              weekdayLabel: _chipCaptionLabel(day, selected),
                              isSelected: _sameDay(day, selected),
                              stats: store.taskStatsForDate(day),
                              onTap: () => widget.onDateSelected(day),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
                if (fadeWidth > 0) ...[
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    width: fadeWidth,
                    child: _EdgeFade(
                      alignment: Alignment.centerLeft,
                    ),
                  ),
                  Positioned(
                    right: 0,
                    top: 0,
                    bottom: 0,
                    width: fadeWidth,
                    child: _EdgeFade(
                      alignment: Alignment.centerRight,
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _DayChip extends StatelessWidget {
  const _DayChip({
    required this.date,
    required this.weekdayLabel,
    required this.isSelected,
    required this.stats,
    required this.onTap,
  });

  final DateTime date;
  final String weekdayLabel;
  final bool isSelected;
  final ({int total, int completed}) stats;
  final VoidCallback onTap;

  static const double _verticalPadding = 8;
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
    return Material(
      color: Colors.transparent,
      clipBehavior: Clip.none,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(
            vertical: _verticalPadding,
            horizontal: 4,
          ),
          decoration: BoxDecoration(
            color: isSelected
                ? TaskerColors.cardBackground
                : const Color(0x66FFFFFF),
            borderRadius: BorderRadius.circular(22),
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

    final trackColor = widget.isSelected
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
            color: widget.isSelected
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

/// Fade na borda do seletor, alinhado ao fundo da home.
class _EdgeFade extends StatelessWidget {
  const _EdgeFade({required this.alignment});

  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    final isLeft = alignment == Alignment.centerLeft;
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: isLeft ? Alignment.centerLeft : Alignment.centerRight,
            end: isLeft ? Alignment.centerRight : Alignment.centerLeft,
            colors: [
              TaskerColors.appBackground,
              TaskerColors.appBackground.withValues(alpha: 0),
            ],
          ),
        ),
      ),
    );
  }
}
