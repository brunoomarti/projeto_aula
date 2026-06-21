import 'package:flutter/material.dart';

import '../../app/theme/tasker_colors.dart';

/// Opção de um [TaskerSlidingSegmentedControl].
class TaskerSegment<T> {
  const TaskerSegment({
    required this.value,
    required this.label,
    this.icon,
    this.enabled = true,
  });

  final T value;
  final String label;
  final Widget? icon;
  final bool enabled;
}

/// Segmented control estilo iOS — indicador branco desliza entre as opções.
class TaskerSlidingSegmentedControl<T> extends StatelessWidget {
  const TaskerSlidingSegmentedControl({
    super.key,
    required this.segments,
    required this.selected,
    this.onChanged,
    this.height = 44,
  });

  final List<TaskerSegment<T>> segments;
  final T selected;
  final ValueChanged<T>? onChanged;
  final double height;

  static const _trackColor = Color(0xFFE8EBF2);
  static const _thumbShadow = [
    BoxShadow(
      color: Color(0x1A000000),
      blurRadius: 8,
      offset: Offset(0, 2),
    ),
    BoxShadow(
      color: Color(0x0F000000),
      blurRadius: 1,
      offset: Offset(0, 1),
    ),
  ];

  static const _animationDuration = Duration(milliseconds: 260);

  bool get _enabled => onChanged != null;

  int get _selectedIndex {
    final index = segments.indexWhere((segment) => segment.value == selected);
    return index < 0 ? 0 : index;
  }

  double get _thumbAlignmentX {
    final count = segments.length;
    if (count <= 1) return 0;
    return -1 + (2 * _selectedIndex / (count - 1));
  }

  @override
  Widget build(BuildContext context) {
    assert(segments.isNotEmpty, 'segments cannot be empty');

    final inset = height * 0.09;
    final thumbRadius = (height - inset * 2) / 2;

    return Opacity(
      opacity: _enabled ? 1 : 0.55,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: _trackColor,
          borderRadius: BorderRadius.circular(height / 2),
        ),
        child: SizedBox(
          height: height,
          width: double.infinity,
          child: Padding(
            padding: EdgeInsets.all(inset),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                AnimatedAlign(
                  alignment: Alignment(_thumbAlignmentX, 0),
                  duration: _animationDuration,
                  curve: Curves.easeOutCubic,
                  child: FractionallySizedBox(
                    widthFactor: 1 / segments.length,
                    heightFactor: 1,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(thumbRadius),
                        boxShadow: _thumbShadow,
                      ),
                    ),
                  ),
                ),
                Row(
                  children: [
                    for (var i = 0; i < segments.length; i++)
                      Expanded(
                        child: _SegmentCell(
                          segment: segments[i],
                          selected: i == _selectedIndex,
                          enabled: _enabled && segments[i].enabled,
                          onTap: _enabled && segments[i].enabled
                              ? () => onChanged!(segments[i].value)
                              : null,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SegmentCell extends StatelessWidget {
  const _SegmentCell({
    required this.segment,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final TaskerSegment<dynamic> segment;
  final bool selected;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final labelColor = selected
        ? TaskerColors.primaryText
        : TaskerColors.secondaryText.withValues(alpha: 0.82);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        splashColor: TaskerColors.primary.withValues(alpha: 0.08),
        highlightColor: TaskerColors.primary.withValues(alpha: 0.04),
        child: SizedBox(
          height: double.infinity,
          child: Center(
            child: Opacity(
              opacity: enabled ? 1 : 0.42,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (segment.icon != null) ...[
                    IconTheme.merge(
                      data: IconThemeData(
                        color: labelColor,
                        size: 17,
                      ),
                      child: segment.icon!,
                    ),
                    const SizedBox(width: 6),
                  ],
                  Flexible(
                    child: Text(
                      segment.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight:
                            selected ? FontWeight.w700 : FontWeight.w600,
                        letterSpacing: -0.12,
                        color: labelColor,
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
