import 'package:flutter/material.dart';

import '../../../../app/theme/tasker_colors.dart';
import '../../../../core/services/geocode_service.dart';
import '../../domain/task.dart';
import '../../domain/task_icon_catalog.dart';

/// Cores e raios alinhados à referência visual do Tasker.
abstract final class TaskCardTokens {
  static const Color cardBackground = Color(0xFFFAFAFA);
  static const Color iconBackground = Color(0xFFD4CCFF);
  static const Color iconForeground = Color(0xFF5A5A5A);
  static const Color primaryText = TaskerColors.primaryText;
  static const Color secondaryText = TaskerColors.secondaryText;
  static const Color mutedText = TaskerColors.mutedText;
  static const Color timeChipBackground = Color(0xFFE8EDF8);
  static const Color timeChipBorder = Color(0xFFD4DCEF);
  static const Color footerDivider = Color(0xFFE4E7EF);
  static const Color doneAccent = Color(0xFF3B71F3);
  static const Color toggleBorder = Color(0xFFC4C4C4);
  static const double borderRadius = 24;
  static const double padding = 22;

  /// Altura do quadrado do ícone — o conteúdo à direita usa a mesma altura.
  static const double iconBoxSize = 66;

  /// Ícone padrão até o usuário poder personalizar por tarefa.
  static const IconData defaultIcon = Icons.home_outlined;

  /// Cor de fundo do ícone — personalizada ou padrão.
  static Color iconBackgroundFor(Task task) =>
      TaskIconCatalog.backgroundFor(task);

  /// Cor do glifo — tom escuro harmonizado com o fundo.
  static Color iconForegroundFor(Task task) =>
      TaskIconCatalog.foregroundFor(task);
}

/// Layout compartilhado do card (home e detalhes).
class TaskCardSurface extends StatelessWidget {
  const TaskCardSurface({
    super.key,
    required this.task,
    this.showTime = true,
    this.showDoneToggle = true,
    this.showTaskType = true,
    this.pinDescriptionToBottom = false,
    this.header,
    this.onTap,
    this.onToggleDone,
    this.showCompletionFlash = false,
    this.applyDoneOpacity = false,
    this.flexibleHeight = false,
    this.titleMaxLines = 1,
    this.descriptionMaxLines = 1,
  });

  final Task task;
  final bool showTime;
  final bool showDoneToggle;
  final bool showTaskType;
  final bool pinDescriptionToBottom;
  final Widget? header;
  final VoidCallback? onTap;
  final VoidCallback? onToggleDone;
  final bool showCompletionFlash;
  final bool applyDoneOpacity;
  final bool flexibleHeight;
  final int titleMaxLines;
  final int descriptionMaxLines;

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: const EdgeInsets.all(TaskCardTokens.padding),
      child: _TaskCardBody(
        task: task,
        showTime: showTime,
        showDoneToggle: showDoneToggle,
        showTaskType: showTaskType,
        pinDescriptionToBottom: pinDescriptionToBottom,
        header: header,
        onToggleDone: onToggleDone,
        titleMaxLines: titleMaxLines,
        descriptionMaxLines: descriptionMaxLines,
        flexibleHeight: flexibleHeight,
      ),
    );

    final card = Material(
      color: TaskCardTokens.cardBackground,
      elevation: 2,
      shadowColor: const Color(0x12000000),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(TaskCardTokens.borderRadius),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          content,
          if (onTap != null)
            Positioned(
              left: 0,
              top: 0,
              right: showDoneToggle ? 62 : 0,
              bottom: 0,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onTap,
                  splashColor: const Color(0x1A000000),
                  highlightColor: const Color(0x0D000000),
                ),
              ),
            ),
          if (showCompletionFlash && task.done)
            const Positioned.fill(
              child: IgnorePointer(child: _CompletionSheen()),
            ),
        ],
      ),
    );

    if (!applyDoneOpacity) return card;

    return AnimatedOpacity(
      opacity: task.done ? 0.78 : 1.0,
      duration: const Duration(milliseconds: 200),
      child: card,
    );
  }
}

class _TaskCardBody extends StatelessWidget {
  const _TaskCardBody({
    required this.task,
    required this.showTime,
    required this.showDoneToggle,
    required this.showTaskType,
    required this.pinDescriptionToBottom,
    required this.flexibleHeight,
    required this.titleMaxLines,
    required this.descriptionMaxLines,
    this.header,
    this.onToggleDone,
  });

  final Task task;
  final bool showTime;
  final bool showDoneToggle;
  final bool showTaskType;
  final bool pinDescriptionToBottom;
  final bool flexibleHeight;
  final int titleMaxLines;
  final int descriptionMaxLines;
  final Widget? header;
  final VoidCallback? onToggleDone;

  @override
  Widget build(BuildContext context) {
    final pinFooterToBottom = flexibleHeight && pinDescriptionToBottom;

    final textColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisAlignment: pinFooterToBottom || !flexibleHeight
          ? MainAxisAlignment.spaceBetween
          : MainAxisAlignment.start,
      mainAxisSize: MainAxisSize.max,
      children: [
        _TopBlock(
          task: task,
          showTime: showTime,
          pinDescriptionToBottom: pinDescriptionToBottom,
          header: header,
          titleMaxLines: titleMaxLines,
          descriptionMaxLines: descriptionMaxLines,
        ),
        _FooterRow(
          task: task,
          showDoneToggle: showDoneToggle,
          showTaskType: showTaskType,
          pinDescriptionToBottom: pinDescriptionToBottom,
          header: header,
          onToggleDone: onToggleDone,
          descriptionMaxLines: descriptionMaxLines,
        ),
      ],
    );

    final contentArea = flexibleHeight
        ? textColumn
        : SizedBox(height: TaskCardTokens.iconBoxSize, child: textColumn);

    if (!flexibleHeight) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _DefaultCategoryIcon(task: task),
          const SizedBox(width: 14),
          Expanded(child: contentArea),
        ],
      );
    }

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _DefaultCategoryIcon(task: task, stretch: true),
          const SizedBox(width: 14),
          Expanded(child: textColumn),
        ],
      ),
    );
  }
}

class _TopBlock extends StatelessWidget {
  const _TopBlock({
    required this.task,
    required this.showTime,
    required this.pinDescriptionToBottom,
    required this.titleMaxLines,
    required this.descriptionMaxLines,
    this.header,
  });

  final Task task;
  final bool showTime;
  final bool pinDescriptionToBottom;
  final int titleMaxLines;
  final int descriptionMaxLines;
  final Widget? header;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (header != null && !pinDescriptionToBottom) ...[
          header!,
          const SizedBox(height: 8),
        ],
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: _TaskTitle(
                task: task,
                done: task.done,
                maxLines: titleMaxLines,
              ),
            ),
            if (showTime) ...[
              const SizedBox(width: 8),
              _TaskTimeLabel(task: task),
            ],
          ],
        ),
        const SizedBox(height: 5),
        _TaskDescription(task: task, maxLines: descriptionMaxLines),
      ],
    );
  }
}

class _FooterRow extends StatelessWidget {
  const _FooterRow({
    required this.task,
    required this.showDoneToggle,
    required this.showTaskType,
    required this.pinDescriptionToBottom,
    required this.descriptionMaxLines,
    this.header,
    this.onToggleDone,
  });

  final Task task;
  final bool showDoneToggle;
  final bool showTaskType;
  final bool pinDescriptionToBottom;
  final int descriptionMaxLines;
  final Widget? header;
  final VoidCallback? onToggleDone;

  @override
  Widget build(BuildContext context) {
    final Widget footerChild;
    if (pinDescriptionToBottom && header != null) {
      footerChild = header!;
    } else if (pinDescriptionToBottom) {
      footerChild = const SizedBox.shrink();
    } else {
      footerChild = showTaskType
          ? _TaskLocationRow(task: task)
          : const SizedBox.shrink();
    }

    if (pinDescriptionToBottom && header != null && !showDoneToggle) {
      return Align(
        alignment: Alignment.bottomLeft,
        child: header!,
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(child: footerChild),
        if (showDoneToggle) ...[
          const SizedBox(width: 12),
          _TaskDoneToggle(task: task, onToggleDone: onToggleDone!),
        ],
      ],
    );
  }
}

/// Badge de status — usado no card de detalhes.
class TaskStatusBadge extends StatelessWidget {
  const TaskStatusBadge({super.key, required this.done});

  final bool done;

  @override
  Widget build(BuildContext context) {
    final bg = done
        ? TaskerColors.primary.withValues(alpha: 0.12)
        : const Color(0xFFFFF3E0);
    final fg = done ? TaskerColors.primary : const Color(0xFFE65100);
    final border = done
        ? TaskerColors.primary.withValues(alpha: 0.25)
        : const Color(0xFFFFCC80);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              done ? Icons.check_circle_rounded : Icons.pending_outlined,
              size: 14,
              color: fg,
            ),
            const SizedBox(width: 5),
            Text(
              done ? 'Concluída' : 'Pendente',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: fg,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Quadrado de ícone — mesmo visual do card de tarefa.
class TaskCardIconBox extends StatelessWidget {
  const TaskCardIconBox({
    super.key,
    required this.icon,
    this.backgroundColor = TaskCardTokens.iconBackground,
    this.iconColor = TaskCardTokens.iconForeground,
    this.size = TaskCardTokens.iconBoxSize,
    this.iconSize = 28,
    this.stretch = false,
  });

  final IconData icon;
  final Color backgroundColor;
  final Color iconColor;
  final double size;
  final double iconSize;
  final bool stretch;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: stretch ? null : size,
      constraints: stretch ? BoxConstraints(minHeight: size) : null,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(icon, size: iconSize, color: iconColor),
    );
  }
}

/// Card de tarefa para a lista da home.
class TaskCard extends StatelessWidget {
  const TaskCard({
    super.key,
    required this.task,
    required this.onOpenDetails,
    required this.onToggleDone,
    this.showCompletionFlash = false,
  });

  final Task task;
  final VoidCallback onOpenDetails;
  final VoidCallback onToggleDone;
  final bool showCompletionFlash;

  @override
  Widget build(BuildContext context) {
    return TaskCardSurface(
      task: task,
      onTap: onOpenDetails,
      onToggleDone: onToggleDone,
      showCompletionFlash: showCompletionFlash,
      applyDoneOpacity: true,
    );
  }
}

/// Ícone personalizado da tarefa.
class _DefaultCategoryIcon extends StatelessWidget {
  const _DefaultCategoryIcon({required this.task, this.stretch = false});

  final Task task;
  final bool stretch;

  @override
  Widget build(BuildContext context) {
    return TaskCardIconBox(
      icon: TaskIconCatalog.iconFor(task),
      backgroundColor: TaskCardTokens.iconBackgroundFor(task),
      iconColor: TaskCardTokens.iconForegroundFor(task),
      stretch: stretch,
    );
  }
}

class _TaskTitle extends StatelessWidget {
  const _TaskTitle({required this.task, required this.done, this.maxLines = 1});

  final Task task;
  final bool done;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Text(
      task.title,
      style:
          const TextStyle(
            color: TaskCardTokens.primaryText,
            fontWeight: FontWeight.w700,
            fontSize: 16,
            height: 1.15,
            letterSpacing: -0.2,
          ).copyWith(
            decoration: done ? TextDecoration.lineThrough : null,
            decorationColor: TaskCardTokens.secondaryText.withValues(
              alpha: 0.45,
            ),
          ),
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
    );
  }
}

class _TaskDescription extends StatelessWidget {
  const _TaskDescription({required this.task, this.maxLines = 1});

  final Task task;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    final description = task.displayDescription;
    final isPlaceholder = description.isEmpty;

    return Text(
      isPlaceholder ? 'Autodescritivo' : description,
      style: TextStyle(
        color: TaskCardTokens.secondaryText.withValues(alpha: 0.8),
        fontSize: 12,
        height: 1.2,
        fontStyle: isPlaceholder ? FontStyle.italic : FontStyle.normal,
        fontWeight: FontWeight.w400,
      ),
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
    );
  }
}

class _TaskLocationRow extends StatefulWidget {
  const _TaskLocationRow({required this.task});

  final Task task;

  @override
  State<_TaskLocationRow> createState() => _TaskLocationRowState();
}

class _TaskLocationRowState extends State<_TaskLocationRow> {
  String? _address;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadAddress();
  }

  @override
  void didUpdateWidget(covariant _TaskLocationRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.task.location != widget.task.location) {
      _address = null;
      _loadAddress();
    }
  }

  Future<void> _loadAddress() async {
    final loc = widget.task.location;
    if (loc == null) return;

    setState(() => _loading = true);
    final address = await GeocodeService.getAddressCached(loc);
    if (!mounted) return;
    setState(() {
      _address = address;
      _loading = false;
    });
  }

  String get _label {
    final loc = widget.task.location;
    if (loc == null) return 'Sem localização disponível';
    if (_loading) return 'Buscando localização…';
    if (_address != null && _address!.isNotEmpty) return _address!;
    return _formatCoords(loc);
  }

  static String _formatCoords(TaskLocation loc) {
    return '${loc.lat.toStringAsFixed(4)}, ${loc.lng.toStringAsFixed(4)}';
  }

  @override
  Widget build(BuildContext context) {
    final hasLocation = widget.task.location != null;
    final muted = TaskCardTokens.mutedText.withValues(alpha: 0.95);

    return Row(
      children: [
        Icon(
          hasLocation
              ? Icons.location_on_outlined
              : Icons.location_off_outlined,
          size: 14,
          color: TaskCardTokens.mutedText.withValues(alpha: 0.85),
        ),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            _label,
            style: TextStyle(
              color: hasLocation ? muted : muted.withValues(alpha: 0.8),
              fontSize: 12,
              fontWeight: FontWeight.w400,
              height: 1.25,
              fontStyle: _loading ? FontStyle.italic : FontStyle.normal,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _TaskTimeLabel extends StatelessWidget {
  const _TaskTimeLabel({required this.task});

  final Task task;

  static String formatTimeLabel(String hora) {
    if (hora.trim().isEmpty) return '—';

    final parts = hora.split(':');
    if (parts.length < 2) return 'Às $hora';

    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null) return 'Às $hora';

    final h = hour.toString().padLeft(2, '0');
    if (minute == null || minute == 0) return 'Às ${h}h';

    final m = minute.toString().padLeft(2, '0');
    return 'Às ${h}h$m';
  }

  @override
  Widget build(BuildContext context) {
    final hasTime = task.hora.isNotEmpty;
    final label = formatTimeLabel(task.hora);

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(
          Icons.alarm_outlined,
          size: 14,
          color: TaskCardTokens.mutedText.withValues(alpha: 0.9),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            color: hasTime
                ? TaskCardTokens.secondaryText.withValues(alpha: 0.65)
                : TaskCardTokens.mutedText,
            fontSize: 12,
            fontWeight: FontWeight.w400,
            height: 1.1,
          ),
        ),
      ],
    );
  }
}

class _TaskDoneToggle extends StatelessWidget {
  const _TaskDoneToggle({required this.task, required this.onToggleDone});

  final Task task;
  final VoidCallback onToggleDone;

  static const _size = 27.0;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: task.done ? 'Marcar como pendente' : 'Marcar como concluída',
      child: GestureDetector(
        onTap: onToggleDone,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: _size,
          height: _size,
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: task.done ? TaskCardTokens.doneAccent : Colors.white,
              border: Border.all(
                color: task.done
                    ? TaskCardTokens.doneAccent
                    : TaskCardTokens.toggleBorder,
                width: 2,
              ),
            ),
            child: task.done
                ? Padding(
                    padding: const EdgeInsets.all(4.5),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                    ),
                  )
                : null,
          ),
        ),
      ),
    );
  }
}

class _CompletionSheen extends StatefulWidget {
  const _CompletionSheen();

  @override
  State<_CompletionSheen> createState() => _CompletionSheenState();
}

class _CompletionSheenState extends State<_CompletionSheen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 500),
  );
  late final Animation<double> _progress = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeInOut,
  );

  @override
  void initState() {
    super.initState();
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _progress,
      builder: (context, child) {
        return CustomPaint(painter: _SheenPainter(progress: _progress.value));
      },
    );
  }
}

class _SheenPainter extends CustomPainter {
  _SheenPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width * 0.55;
    final left = -w + (size.width + w * 2) * progress;
    final rect = Rect.fromLTWH(left, 0, w, size.height);
    final paint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [Color(0x00FFFFFF), Color(0x80FFFFFF), Color(0x00FFFFFF)],
        stops: [0.0, 0.5, 1.0],
      ).createShader(rect);
    canvas.drawRect(rect, paint);
  }

  @override
  bool shouldRepaint(covariant _SheenPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
