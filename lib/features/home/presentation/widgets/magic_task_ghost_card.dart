import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../app/theme/tasker_colors.dart';
import '../../../tasks/presentation/widgets/task_card.dart';
import '../utils/selected_day_label.dart';

/// Card fantasma exibido enquanto o magic input interpreta e cria a tarefa.
class MagicTaskGhostCard extends StatefulWidget {
  const MagicTaskGhostCard({
    super.key,
    required this.targetDay,
    this.previewText,
  });

  final DateTime targetDay;
  final String? previewText;

  @override
  State<MagicTaskGhostCard> createState() => _MagicTaskGhostCardState();
}

class _MagicTaskGhostCardState extends State<MagicTaskGhostCard>
    with TickerProviderStateMixin {
  late final AnimationController _shimmerController;
  late final AnimationController _borderController;

  static const _gradientColors = [
    Color(0xFF7864FF),
    Color(0xFFFF78C8),
    Color(0xFFFFC878),
    Color(0xFF78DCFF),
    Color(0xFF7864FF),
  ];

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
    _borderController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat();
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    _borderController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dayLabel = SelectedDayLabel.format(widget.targetDay);
    final preview = widget.previewText?.trim();

    return AnimatedBuilder(
      animation: _borderController,
      builder: (context, child) {
        return Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _GhostGlowPainter(
                  progress: _borderController.value,
                  borderRadius: TaskCardTokens.borderRadius + 4,
                ),
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                borderRadius:
                    BorderRadius.circular(TaskCardTokens.borderRadius + 4),
                gradient: SweepGradient(
                  colors: _gradientColors,
                  transform: GradientRotation(
                    _borderController.value * math.pi * 2,
                  ),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(2.25),
                child: child,
              ),
            ),
          ],
        );
      },
      child: TaskCardTokens.shell(
        elevation: 1.5,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
              child: Row(
                children: [
                  Icon(
                    Icons.auto_awesome_rounded,
                    size: 15,
                    color: TaskerColors.primary.withValues(alpha: 0.85),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Criando para $dayLabel',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        height: 1.2,
                        color: TaskerColors.petroleumDark.withValues(alpha: 0.88),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(TaskCardTokens.padding),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ShimmerBlock(
                    animation: _shimmerController,
                    width: TaskCardTokens.iconBoxSize,
                    height: TaskCardTokens.iconBoxSize,
                    borderRadius: 18,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (preview != null && preview.isNotEmpty) ...[
                          Text(
                            preview,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: TaskCardTokens.titleFontSize,
                              fontWeight: FontWeight.w600,
                              height: TaskCardTokens.titleLineHeight,
                              color: TaskerColors.primaryText
                                  .withValues(alpha: 0.42),
                            ),
                          ),
                          const SizedBox(height: 10),
                        ] else ...[
                          _ShimmerBlock(
                            animation: _shimmerController,
                            width: double.infinity,
                            height: 16,
                            borderRadius: 8,
                          ),
                          const SizedBox(height: 8),
                        ],
                        _ShimmerBlock(
                          animation: _shimmerController,
                          width: 120,
                          height: 12,
                          borderRadius: 6,
                        ),
                        const SizedBox(height: 14),
                        _ShimmerBlock(
                          animation: _shimmerController,
                          width: 72,
                          height: 24,
                          borderRadius: 12,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShimmerBlock extends StatelessWidget {
  const _ShimmerBlock({
    required this.animation,
    required this.width,
    required this.height,
    required this.borderRadius,
  });

  final Animation<double> animation;
  final double width;
  final double height;
  final double borderRadius;

  static const _base = Color(0xFFE4E8F2);
  static const _highlight = Color(0xFFF7F9FD);

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return ShaderMask(
          shaderCallback: (bounds) {
            final slide = -1.2 + animation.value * 2.4;
            return LinearGradient(
              begin: Alignment(slide - 0.45, 0),
              end: Alignment(slide + 0.45, 0),
              colors: const [_base, _highlight, _base],
              stops: const [0.0, 0.5, 1.0],
            ).createShader(bounds);
          },
          blendMode: BlendMode.srcATop,
          child: child,
        );
      },
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: _base,
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
    );
  }
}

class _GhostGlowPainter extends CustomPainter {
  const _GhostGlowPainter({
    required this.progress,
    required this.borderRadius,
  });

  final double progress;
  final double borderRadius;

  static const _gradientColors = [
    Color(0xFF7864FF),
    Color(0xFFFF78C8),
    Color(0xFFFFC878),
    Color(0xFF78DCFF),
    Color(0xFF7864FF),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(
      rect,
      Radius.circular(borderRadius),
    );

    final paint = Paint()
      ..shader = SweepGradient(
        colors: _gradientColors.map((c) => c.withValues(alpha: 0.38)).toList(),
        transform: GradientRotation(progress * math.pi * 2),
      ).createShader(rect.inflate(8))
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);

    canvas.drawRRect(rrect, paint);
  }

  @override
  bool shouldRepaint(covariant _GhostGlowPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
