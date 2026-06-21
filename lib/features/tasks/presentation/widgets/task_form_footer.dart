import 'package:flutter/material.dart';

import '../../../../app/theme/tasker_colors.dart';
import '../../../../core/layout/tasker_page_chrome.dart';

/// Métricas internas do footer — padding block == padding inline.
abstract final class TaskFormFooterMetrics {
  static const innerPadding = 6.0;
  static const barHeight = TaskerDockMetrics.barHeight;
  static const contentHeight = barHeight - innerPadding * 2;
  static const buttonGap = 10.0;
}

/// Destaque visual do botão de avanço no footer do formulário.
enum TaskFormFooterNextEmphasis {
  /// “Próximo” — mais forte que Voltar, mais suave que criar/salvar.
  standard,

  /// “Criar tarefa” / “Salvar” — call-to-action principal.
  primary,
}

/// Footer de navegação entre etapas — voltar + avançar com animação de largura.
class TaskFormStepNavFooter extends StatefulWidget {
  const TaskFormStepNavFooter({
    super.key,
    required this.onNext,
    this.onBack,
    this.showBack = true,
    this.backEnabled = true,
    this.nextEnabled = true,
    this.nextLabel = 'Próximo',
    this.backLabel = 'Voltar',
    this.nextEmphasis = TaskFormFooterNextEmphasis.standard,
    this.animationDuration = const Duration(milliseconds: 320),
    this.animationCurve = Curves.easeInOutCubic,
  });

  final VoidCallback? onBack;
  final VoidCallback? onNext;
  final bool showBack;
  final bool backEnabled;
  final bool nextEnabled;
  final String nextLabel;
  final String backLabel;
  final TaskFormFooterNextEmphasis nextEmphasis;
  final Duration animationDuration;
  final Curve animationCurve;

  @override
  State<TaskFormStepNavFooter> createState() => _TaskFormStepNavFooterState();
}

class _TaskFormStepNavFooterState extends State<TaskFormStepNavFooter>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _backPresence;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.animationDuration,
      value: widget.showBack ? 1 : 0,
    );
    _backPresence = CurvedAnimation(
      parent: _controller,
      curve: widget.animationCurve,
    );
  }

  @override
  void didUpdateWidget(covariant TaskFormStepNavFooter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animationDuration != oldWidget.animationDuration) {
      _controller.duration = widget.animationDuration;
    }
    if (widget.showBack != oldWidget.showBack) {
      if (widget.showBack) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _buildNextButton({
    required double height,
    required bool enabled,
  }) {
    final onPressed = enabled ? widget.onNext : null;

    return switch (widget.nextEmphasis) {
      TaskFormFooterNextEmphasis.standard => _TaskFormAccentTextButton(
          label: widget.nextLabel,
          onPressed: onPressed,
          height: height,
        ),
      TaskFormFooterNextEmphasis.primary => _TaskFormPrimaryTextButton(
          label: widget.nextLabel,
          onPressed: onPressed,
          height: height,
        ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final height = TaskFormFooterMetrics.contentHeight;
    final nextEnabled = widget.nextEnabled;

    return Padding(
      padding: const EdgeInsets.all(TaskFormFooterMetrics.innerPadding),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return RepaintBoundary(
            child: AnimatedBuilder(
              animation: _backPresence,
              builder: (context, _) {
                final t = _backPresence.value;
                final totalWidth = constraints.maxWidth;
                final gap = TaskFormFooterMetrics.buttonGap * t;
                final available = totalWidth - gap;
                final backWidth = available * 0.5 * t;
                final nextWidth = available - backWidth;
                final backInteractive = t > 0.92;

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ClipRect(
                      child: SizedBox(
                        width: backWidth,
                        child: Opacity(
                          opacity: t.clamp(0.0, 1.0),
                          child: IgnorePointer(
                            ignoring: !backInteractive,
                            child: _TaskFormGlassTextButton(
                              label: widget.backLabel,
                              onPressed:
                                  widget.backEnabled ? widget.onBack : null,
                              height: height,
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: gap),
                    SizedBox(
                      width: nextWidth,
                      child: _buildNextButton(
                        height: height,
                        enabled: nextEnabled,
                      ),
                    ),
                  ],
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _TaskFormGlassTextButton extends StatelessWidget {
  const _TaskFormGlassTextButton({
    required this.label,
    required this.onPressed,
    required this.height,
  });

  final String label;
  final VoidCallback? onPressed;
  final double height;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final radius = BorderRadius.circular(height / 2);
    final foreground = enabled
        ? TaskerColors.secondaryText.withValues(alpha: 0.88)
        : TaskerColors.mutedText.withValues(alpha: 0.65);

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        color: enabled
            ? const Color(0x0F1A3D47)
            : const Color(0x081A3D47),
        border: Border.all(
          color: const Color(0xFFD4DAE4).withValues(alpha: enabled ? 0.9 : 0.55),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          borderRadius: radius,
          splashColor: TaskerColors.primaryText.withValues(alpha: 0.06),
          highlightColor: TaskerColors.primaryText.withValues(alpha: 0.04),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.15,
                color: foreground,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Avanço intermediário — destaque moderado (entre Voltar e criar/salvar).
class _TaskFormAccentTextButton extends StatelessWidget {
  const _TaskFormAccentTextButton({
    required this.label,
    required this.onPressed,
    required this.height,
  });

  final String label;
  final VoidCallback? onPressed;
  final double height;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final radius = BorderRadius.circular(height / 2);

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: enabled
              ? [
                  TaskerColors.primary.withValues(alpha: 0.16),
                  TaskerColors.primary.withValues(alpha: 0.26),
                ]
              : [
                  TaskerColors.primary.withValues(alpha: 0.08),
                  TaskerColors.primary.withValues(alpha: 0.1),
                ],
        ),
        border: Border.all(
          color: TaskerColors.primary.withValues(alpha: enabled ? 0.38 : 0.2),
          width: 1,
        ),
        boxShadow: enabled
            ? [
                BoxShadow(
                  color: TaskerColors.primary.withValues(alpha: 0.14),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          borderRadius: radius,
          splashColor: TaskerColors.primary.withValues(alpha: 0.08),
          highlightColor: TaskerColors.primary.withValues(alpha: 0.05),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.15,
                color: enabled
                    ? TaskerColors.primary.withValues(alpha: 0.92)
                    : TaskerColors.primary.withValues(alpha: 0.45),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// CTA final — gradiente completo para criar/salvar.
class _TaskFormPrimaryTextButton extends StatelessWidget {
  const _TaskFormPrimaryTextButton({
    required this.label,
    required this.onPressed,
    required this.height,
  });

  final String label;
  final VoidCallback? onPressed;
  final double height;

  static const _shadow = BoxShadow(
    color: Color.fromARGB(41, 0, 0, 0),
    blurRadius: 1,
    offset: Offset(0, 1),
  );

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final radius = BorderRadius.circular(height / 2);

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: enabled
              ? [
                  Color.lerp(TaskerColors.primary, Colors.white, 0.22)!,
                  TaskerColors.primary,
                  Color.lerp(TaskerColors.primary, Colors.black, 0.14)!,
                ]
              : [
                  TaskerColors.primary.withValues(alpha: 0.42),
                  TaskerColors.primary.withValues(alpha: 0.36),
                  TaskerColors.primary.withValues(alpha: 0.32),
                ],
        ),
        border: Border.all(
          color: Colors.white.withValues(alpha: enabled ? 0.58 : 0.32),
          width: 1,
        ),
        boxShadow: enabled ? const [_shadow] : null,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          borderRadius: radius,
          splashColor: Colors.white.withValues(alpha: 0.12),
          highlightColor: Colors.white.withValues(alpha: 0.08),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.15,
                color: Colors.white.withValues(alpha: enabled ? 1 : 0.55),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
