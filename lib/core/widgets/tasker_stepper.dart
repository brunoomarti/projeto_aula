import 'package:flutter/material.dart';

import 'package:hugeicons/hugeicons.dart';
import 'package:tasker_project/core/icons/tasker_icon.dart';

import '../../app/theme/tasker_card_style.dart';
import '../../app/theme/tasker_colors.dart';

/// Indicador horizontal de progresso — reutilizável e animado.
class TaskerStepper extends StatelessWidget {
  const TaskerStepper({
    super.key,
    required this.currentStep,
    required this.labels,
    this.duration = const Duration(milliseconds: 320),
    this.curve = Curves.easeInOutCubic,
    this.showSurface = true,
    this.padding = const EdgeInsets.fromLTRB(10, 14, 10, 12),
  });

  final int currentStep;
  final List<String> labels;
  final Duration duration;
  final Curve curve;
  final bool showSurface;
  final EdgeInsetsGeometry padding;

  static const nodeSize = 22.0;
  static const trackHeight = 22.0;
  static const lineHeight = 1.5;
  static const lineGap = 5.0;
  static const surfaceRadius = 18.0;

  static Color get completedFill => TaskerColors.primary.withValues(alpha: 0.16);

  static Color get completedLine => TaskerColors.primary.withValues(alpha: 0.28);

  static const futureNodeFill = Color(0xFFE2E6EF);
  static const futureLine = Color(0xFFD6DCE6);

  @override
  Widget build(BuildContext context) {
    assert(labels.isNotEmpty);
    assert(currentStep >= 0 && currentStep < labels.length);

    final content = Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: _TaskerStepColumn(
                index: i,
                stepCount: labels.length,
                currentStep: currentStep,
                label: labels[i],
                duration: duration,
                curve: curve,
              ),
            ),
        ],
      ),
    );

    if (!showSurface) return content;

    return Material(
      color: TaskerCardStyle.background,
      elevation: TaskerCardStyle.elevation,
      shadowColor: TaskerCardStyle.shadowColor,
      surfaceTintColor: Colors.transparent,
      borderRadius: BorderRadius.circular(surfaceRadius),
      clipBehavior: Clip.antiAlias,
      child: content,
    );
  }
}

enum _TaskerStepPhase { completed, active, future }

class _TaskerStepColumn extends StatelessWidget {
  const _TaskerStepColumn({
    required this.index,
    required this.stepCount,
    required this.currentStep,
    required this.label,
    required this.duration,
    required this.curve,
  });

  final int index;
  final int stepCount;
  final int currentStep;
  final String label;
  final Duration duration;
  final Curve curve;

  _TaskerStepPhase get _phase {
    if (index < currentStep) return _TaskerStepPhase.completed;
    if (index == currentStep) return _TaskerStepPhase.active;
    return _TaskerStepPhase.future;
  }

  bool get _hasLeftLine => index > 0;
  bool get _hasRightLine => index < stepCount - 1;

  bool get _leftLineCompleted => index <= currentStep && index > 0;
  bool get _rightLineCompleted => index < currentStep;

  Color get _labelColor {
    return switch (_phase) {
      _TaskerStepPhase.completed =>
        TaskerColors.primary.withValues(alpha: 0.72),
      _TaskerStepPhase.active => TaskerColors.primary,
      _TaskerStepPhase.future =>
        TaskerColors.mutedText.withValues(alpha: 0.62),
    };
  }

  FontWeight get _labelWeight {
    return _phase == _TaskerStepPhase.active
        ? FontWeight.w700
        : FontWeight.w500;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: TaskerStepper.trackHeight,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: _hasLeftLine
                    ? _TaskerStepConnector(
                        completed: _leftLineCompleted,
                        alignRight: true,
                        duration: duration,
                        curve: curve,
                      )
                    : const SizedBox.shrink(),
              ),
              _TaskerStepNode(
                phase: _phase,
                duration: duration,
                curve: curve,
              ),
              Expanded(
                child: _hasRightLine
                    ? _TaskerStepConnector(
                        completed: _rightLineCompleted,
                        alignRight: false,
                        duration: duration,
                        curve: curve,
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        AnimatedDefaultTextStyle(
          duration: duration,
          curve: curve,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: _labelWeight,
            letterSpacing: -0.08,
            height: 1.15,
            color: _labelColor,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _TaskerStepConnector extends StatelessWidget {
  const _TaskerStepConnector({
    required this.completed,
    required this.alignRight,
    required this.duration,
    required this.curve,
  });

  final bool completed;
  final bool alignRight;
  final Duration duration;
  final Curve curve;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignRight ? Alignment.centerRight : Alignment.centerLeft,
      child: Padding(
        padding: EdgeInsets.only(
          left: alignRight ? 0 : TaskerStepper.lineGap,
          right: alignRight ? TaskerStepper.lineGap : 0,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(TaskerStepper.lineHeight),
          child: SizedBox(
            height: TaskerStepper.lineHeight,
            width: double.infinity,
            child: Stack(
              fit: StackFit.expand,
              children: [
                ColoredBox(color: TaskerStepper.futureLine),
                AnimatedAlign(
                  duration: duration,
                  curve: curve,
                  alignment:
                      alignRight ? Alignment.centerRight : Alignment.centerLeft,
                  widthFactor: completed ? 1 : 0,
                  child: ColoredBox(color: TaskerStepper.completedLine),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TaskerStepNode extends StatelessWidget {
  const _TaskerStepNode({
    required this.phase,
    required this.duration,
    required this.curve,
  });

  final _TaskerStepPhase phase;
  final Duration duration;
  final Curve curve;

  @override
  Widget build(BuildContext context) {
    final (fill, border, scale) = switch (phase) {
      _TaskerStepPhase.completed => (
          TaskerStepper.completedFill,
          TaskerColors.primary.withValues(alpha: 0.22),
          1.0,
        ),
      _TaskerStepPhase.active => (
          TaskerColors.primary,
          TaskerColors.primary,
          1.08,
        ),
      _TaskerStepPhase.future => (
          TaskerStepper.futureNodeFill,
          const Color(0xFFD0D7E4),
          1.0,
        ),
    };

    return AnimatedScale(
      scale: scale,
      duration: duration,
      curve: curve,
      child: AnimatedContainer(
        duration: duration,
        curve: curve,
        width: TaskerStepper.nodeSize,
        height: TaskerStepper.nodeSize,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: fill,
          shape: BoxShape.circle,
          border: Border.all(color: border, width: 1),
        ),
        child: AnimatedSwitcher(
          duration: duration,
          switchInCurve: Curves.easeOutBack,
          switchOutCurve: Curves.easeIn,
          transitionBuilder: (child, animation) {
            return ScaleTransition(
              scale: animation,
              child: FadeTransition(opacity: animation, child: child),
            );
          },
          child: switch (phase) {
            _TaskerStepPhase.completed => AppHugeIcon(
                key: const ValueKey('completed'),
                icon: HugeIcons.strokeRoundedTick01,
                size: 11,
                color: TaskerColors.primary.withValues(alpha: 0.82),
              ),
            _TaskerStepPhase.active => Container(
                key: const ValueKey('active'),
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
              ),
            _TaskerStepPhase.future => const SizedBox(
                key: ValueKey('future'),
                width: 6,
                height: 6,
              ),
          },
        ),
      ),
    );
  }
}
