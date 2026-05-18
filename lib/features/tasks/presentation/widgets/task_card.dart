import 'package:flutter/material.dart';

import '../../../../app/theme/tasker_colors.dart';
import '../../domain/task.dart';

/// Cores e raios de [tasker-main/src/css/task.css] via [TaskerColors].
abstract final class TaskCardTokens {
  static const Color cardBackground = TaskerColors.cardBackground;
  static const Color iconBackground = TaskerColors.iconBackground;
  static const Color primaryText = TaskerColors.primaryText;
  static const Color secondaryText = TaskerColors.secondaryText;
  static const Color mutedText = TaskerColors.mutedText;
  static const Color doneAccent = TaskerColors.primary;
  static const double borderRadius = 12;
  static const double iconRadius = 8;
  static const double padding = 14;
}

/// Card de tarefa para lista: título, descrição, horário e toggle de concluído.
///
/// Toque na área do card (exceto o círculo de concluir) deve ser tratado por [onOpenDetails] (ex.: navegar para a tela de detalhes).
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

  /// Efeito visual breve ao marcar como feita (equivalente a `anim-reflexo` no CSS).
  final bool showCompletionFlash;

  @override
  Widget build(BuildContext context) {
    final opacity = task.done ? 0.72 : 1.0;

    return AnimatedOpacity(
      opacity: opacity,
      duration: const Duration(milliseconds: 200),
      child: Material(
        color: TaskCardTokens.cardBackground,
        elevation: 2,
        shadowColor: TaskerColors.cardShadow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(TaskCardTokens.borderRadius),
          side: const BorderSide(color: TaskerColors.cardBorder),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            Positioned.fill(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onOpenDetails,
                  splashColor: const Color(0x1A000000),
                  highlightColor: const Color(0x0D000000),
                  child: Padding(
                    padding: const EdgeInsets.all(TaskCardTokens.padding),
                    child: Stack(
                      clipBehavior: Clip.hardEdge,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const _IconBadge(),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(
                                  right: 52,
                                  bottom: 28,
                                ),
                                child: _TaskMainColumn(task: task),
                              ),
                            ),
                          ],
                        ),
                        Positioned(
                          top: 0,
                          right: 0,
                          width: 52,
                          child: _TaskTimeRow(task: task),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              right: TaskCardTokens.padding,
              bottom: TaskCardTokens.padding,
              width: 52,
              child: _TaskDoneToggle(
                task: task,
                onToggleDone: onToggleDone,
              ),
            ),
            if (showCompletionFlash && task.done)
              Positioned.fill(
                child: IgnorePointer(
                  child: ClipRRect(
                    borderRadius:
                        BorderRadius.circular(TaskCardTokens.borderRadius),
                    child: const _CompletionSheen(),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _IconBadge extends StatelessWidget {
  const _IconBadge();
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: TaskCardTokens.iconBackground,
        borderRadius: BorderRadius.circular(TaskCardTokens.iconRadius),
      ),
      child: Icon(
        Icons.assignment_outlined,
        size: 22,
        color: TaskCardTokens.primaryText.withValues(alpha: 0.65),
      ),
    );
  }
}

class _TaskMainColumn extends StatelessWidget {
  const _TaskMainColumn({required this.task});

  final Task task;

  @override
  Widget build(BuildContext context) {
    final description = task.displayDescription;
    final descWidget = description.isEmpty
        ? Text(
            'Autodescritiva',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: TaskCardTokens.secondaryText,
                  fontStyle: FontStyle.italic,
                ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          )
        : Text(
            description,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: TaskCardTokens.secondaryText,
                ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          task.title,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: TaskCardTokens.primaryText,
                fontWeight: FontWeight.w600,
              ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        descWidget,
        const SizedBox(height: 8),
        Text(
          'Tarefa individual',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: TaskCardTokens.mutedText,
              ),
        ),
      ],
    );
  }
}

class _TaskTimeRow extends StatelessWidget {
  const _TaskTimeRow({required this.task});

  final Task task;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Icon(
          Icons.schedule,
          size: 16,
          color: TaskCardTokens.secondaryText.withValues(alpha: 0.75),
        ),
        const SizedBox(width: 3),
        Expanded(
          child: Text(
            task.hora.isEmpty ? '—' : task.hora,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color:
                      TaskCardTokens.secondaryText.withValues(alpha: 0.85),
                ),
            textAlign: TextAlign.end,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _TaskDoneToggle extends StatelessWidget {
  const _TaskDoneToggle({
    required this.task,
    required this.onToggleDone,
  });

  final Task task;
  final VoidCallback onToggleDone;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Semantics(
        button: true,
        label: task.done ? 'Marcar como pendente' : 'Marcar como concluída',
        child: GestureDetector(
          onTap: onToggleDone,
          behavior: HitTestBehavior.opaque,
          child: Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
                  border: Border.all(color: TaskerColors.statusBorder),
            ),
            alignment: Alignment.center,
            padding: const EdgeInsets.all(3),
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: task.done ? TaskCardTokens.doneAccent : Colors.transparent,
              ),
              child: const SizedBox.expand(),
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
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 500),
  );
  late final Animation<double> _t = CurvedAnimation(
    parent: _c,
    curve: Curves.easeInOut,
  );

  @override
  void initState() {
    super.initState();
    _c.forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _t,
      builder: (context, child) {
        return CustomPaint(
          painter: _SheenPainter(progress: _t.value),
        );
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
        colors: [
          Color(0x00FFFFFF),
          Color(0x80FFFFFF),
          Color(0x00FFFFFF),
        ],
        stops: [0.0, 0.5, 1.0],
      ).createShader(rect);
    canvas.drawRect(rect, paint);
  }

  @override
  bool shouldRepaint(covariant _SheenPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
