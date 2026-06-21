import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:hugeicons/hugeicons.dart';

import '../../../../app/theme/tasker_colors.dart';
import '../../../../core/icons/tasker_icon.dart';
import '../../../../core/icons/tasker_icon_glyph.dart';
import 'package:tasker_nlp/tasker_nlp.dart';
import '../../../../core/services/geocode_service.dart';
import '../../domain/task.dart';
import '../../domain/task_icon_catalog.dart';
import '../state/task_store.dart';

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

  /// Tipografia do conteúdo principal — hierarquia título > descrição > metadados.
  static const double titleFontSize = 17;
  static const double titleLineHeight = 1.16;
  static const double descriptionFontSize = 13;
  static const double descriptionLineHeight = 1.18;
  static const double metadataFontSize = 12;
  static const double titleDescriptionGap = 4;

  /// Sombra padrão de todos os cards (home, pilha fechada/aberta, detalhes).
  static const double cardElevation = 2;
  static const Color cardShadowColor = Color.fromARGB(99, 0, 0, 0);

  /// Envolve o conteúdo do card com fundo, raio e sombra.
  static Widget shell({required Widget child, double? elevation}) {
    return Material(
      color: cardBackground,
      elevation: elevation ?? cardElevation,
      shadowColor: cardShadowColor,
      surfaceTintColor: Colors.transparent,
      borderRadius: BorderRadius.circular(borderRadius),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }

  /// Altura do quadrado do ícone — o conteúdo à direita usa a mesma altura.
  static const double iconBoxSize = 66;

  /// Ícone padrão até o usuário poder personalizar por tarefa.
  static const TaskerIconGlyph defaultIcon = HugeIcons.strokeRoundedGuestHouse;

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
    this.descriptionOverride,
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

  /// Substitui [Task.displayDescription] no card (ex.: «Lista de afazeres»).
  final String? descriptionOverride;

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
        descriptionOverride: descriptionOverride,
        flexibleHeight: flexibleHeight,
      ),
    );

    final card = TaskCardTokens.shell(
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
    this.descriptionOverride,
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
  final String? descriptionOverride;
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
          descriptionOverride: descriptionOverride,
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
    this.descriptionOverride,
    this.header,
  });

  final Task task;
  final bool showTime;
  final bool pinDescriptionToBottom;
  final int titleMaxLines;
  final int descriptionMaxLines;
  final String? descriptionOverride;
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
            _SyncStatusIcon(synced: task.synced),
            const SizedBox(width: 6),
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
        const SizedBox(height: TaskCardTokens.titleDescriptionGap),
        _TaskDescription(
          task: task,
          maxLines: descriptionMaxLines,
          overrideText: descriptionOverride,
        ),
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
            AppHugeIcon(
              icon: done
                  ? HugeIcons.strokeRoundedCheckmarkCircle01
                  : HugeIcons.strokeRoundedHourglass,
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

  final TaskerIconGlyph icon;
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
      child: TaskerIcon(icon: icon, size: iconSize, color: iconColor),
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

/// Indicador de sincronização à esquerda do título.
///
/// - Sincronizada (na nuvem): nuvem com check, em verde discreto.
/// - Pendente (offline / aguardando envio): nuvem cortada, em âmbar.
class _SyncStatusIcon extends StatelessWidget {
  const _SyncStatusIcon({required this.synced});

  final bool synced;

  static const Color _syncedColor = Color(0xFF3BA55D);
  static const Color _pendingColor = Color(0xFFE6A100);

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: synced ? 'Sincronizada' : 'Aguardando sincronização',
      child: AppHugeIcon(
        icon: synced
            ? HugeIcons.strokeRoundedCloudSavingDone01
            : HugeIcons.strokeRoundedCloudLoading,
        size: 16,
        color: synced ? _syncedColor : _pendingColor,
      ),
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
            fontSize: TaskCardTokens.titleFontSize,
            height: TaskCardTokens.titleLineHeight,
            letterSpacing: -0.25,
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
  const _TaskDescription({
    required this.task,
    this.maxLines = 1,
    this.overrideText,
  });

  final Task task;
  final int maxLines;
  final String? overrideText;

  @override
  Widget build(BuildContext context) {
    final override = overrideText?.trim();
    final description = task.displayDescription;
    final isPlaceholder = override == null && description.isEmpty;
    final text = override ??
        (isPlaceholder
            ? 'Autodescritivo'
            : _descriptionForDisplay(description, maxLines: maxLines));

    return Text(
      text,
      style: TextStyle(
        color: TaskCardTokens.secondaryText.withValues(alpha: 0.82),
        fontSize: TaskCardTokens.descriptionFontSize,
        height: TaskCardTokens.descriptionLineHeight,
        fontStyle: isPlaceholder ? FontStyle.italic : FontStyle.normal,
        fontWeight: isPlaceholder ? FontWeight.w400 : FontWeight.w500,
      ),
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
    );
  }
}

String _descriptionForDisplay(String description, {required int maxLines}) {
  if (maxLines == 1 && isErrandListDescription(description)) {
    return errandListInlineFromDescription(description);
  }
  return description;
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

    final persisted = loc.formattedAddress?.trim();
    if (persisted != null && persisted.isNotEmpty) {
      setState(() {
        _address = persisted;
        _loading = false;
      });
      return;
    }

    setState(() => _loading = true);
    final address = await GeocodeService.getAddressCached(loc);
    if (!mounted) return;
    setState(() {
      _address = address;
      _loading = false;
    });

    if (address != null && address.trim().isNotEmpty) {
      await context
          .read<TaskStore>()
          .persistTaskLocationAddress(widget.task.id, address);
    }
  }

  String get _label {
    final loc = widget.task.location;
    if (loc == null) return 'Sem localização disponível';
    if (_loading) return 'Buscando localização…';
    if (_address != null && _address!.isNotEmpty) {
      return TaskLocation.formatAddressLine(
        location: loc,
        streetAddress: _address,
      );
    }
    return TaskLocation.formatAddressLine(location: loc);
  }

  @override
  Widget build(BuildContext context) {
    final hasLocation = widget.task.location != null;
    final muted = TaskCardTokens.mutedText.withValues(alpha: 0.95);

    return Row(
      children: [
        AppHugeIcon(
          icon: hasLocation
              ? HugeIcons.strokeRoundedLocation01
              : HugeIcons.strokeRoundedLocationOffline01,
          size: 14,
          color: TaskCardTokens.mutedText.withValues(alpha: 0.85),
        ),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            _label,
            style: TextStyle(
              color: hasLocation ? muted : muted.withValues(alpha: 0.8),
              fontSize: TaskCardTokens.metadataFontSize,
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
        AppHugeIcon(icon: HugeIcons.strokeRoundedAlarmClock,
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
            fontSize: TaskCardTokens.metadataFontSize,
            fontWeight: FontWeight.w400,
            height: 1.1,
          ),
        ),
      ],
    );
  }
}

/// Círculo preenchido com anel branco e check central — toggle concluído.
class FilledCheckCircleBadge extends StatelessWidget {
  const FilledCheckCircleBadge({
    super.key,
    required this.color,
    this.size = 24,
  });

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final outerBorder = size * (1.75 / 24);
    final ringInset = size * (6 / 24);
    final ringBorder = size * (1.25 / 24);
    final checkSize = size * (10 / 24);

    return SizedBox(
      width: size,
      height: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
          border: Border.all(color: color, width: outerBorder),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Padding(
              padding: EdgeInsets.all(ringInset),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: ringBorder),
                ),
              ),
            ),
            AppHugeIcon(
              icon: HugeIcons.strokeRoundedTick01,
              size: checkSize,
              color: Colors.white,
            ),
          ],
        ),
      ),
    );
  }
}

/// Círculo azul com anel branco e check — estado concluído do toggle de tarefa.
class TaskDoneCheckCircle extends StatelessWidget {
  const TaskDoneCheckCircle({super.key, this.size = 24});

  final double size;

  @override
  Widget build(BuildContext context) {
    return FilledCheckCircleBadge(
      color: TaskCardTokens.doneAccent,
      size: size,
    );
  }
}

class _TaskDoneToggle extends StatelessWidget {
  const _TaskDoneToggle({required this.task, required this.onToggleDone});

  final Task task;
  final VoidCallback onToggleDone;

  static const _size = 24.0;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: task.done ? 'Marcar como pendente' : 'Marcar como concluída',
      child: GestureDetector(
        onTap: onToggleDone,
        behavior: HitTestBehavior.opaque,
        child: task.done
            ? const TaskDoneCheckCircle(size: _size)
            : SizedBox(
                width: _size,
                height: _size,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    border: Border.all(
                      color: TaskCardTokens.toggleBorder,
                      width: 1.75,
                    ),
                  ),
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
