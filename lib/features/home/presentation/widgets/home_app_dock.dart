import 'package:tasker_project/core/icons/tasker_icon.dart';

import 'package:hugeicons/hugeicons.dart';

import 'package:flutter/material.dart';

import '../../../../app/theme/tasker_colors.dart';
import '../../../../core/layout/tasker_page_chrome.dart';
import '../../../../core/widgets/tasker_glass_surface.dart';
/// Dock inferior flutuante — início, nova tarefa e conquistas.
class HomeAppDock extends StatelessWidget {
  const HomeAppDock({
    super.key,
    required this.onHomeTap,
    required this.onAddTap,
    required this.onAchievementsTap,
    this.homeSelected = true,
    this.achievementsSelected = false,
    this.addMenuOpen = false,
  });

  final VoidCallback onHomeTap;
  final VoidCallback onAddTap;
  final VoidCallback onAchievementsTap;
  final bool homeSelected;
  final bool achievementsSelected;

  /// Quando `true`, o + do dock gira 45° e vira X.
  final bool addMenuOpen;

  static const barHeight = TaskerDockMetrics.barHeight;
  static const horizontalInset = TaskerDockMetrics.horizontalInset;
  static const bottomInset = TaskerDockMetrics.bottomInset;
  /// Meio da altura — cápsula com topo e base bem arredondados.
  static const pillRadius = barHeight / 2;

  /// Espaço total reservado na base (barra flutuante + margem + área segura).
  static double reservedHeight(BuildContext context) {
    return TaskerDockMetrics.reservedHeight(context);
  }

  @override
  Widget build(BuildContext context) {
    final bottomSafe = MediaQuery.paddingOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        horizontalInset,
        0,
        horizontalInset,
        bottomInset + bottomSafe,
      ),
      child: _GlassPill(
        height: barHeight,
        child: Row(
          children: [
            Expanded(
              child: _DockNavItem(
                icon: HugeIcons.strokeRoundedHome03,
                label: 'Início',
                selected: homeSelected,
                onTap: onHomeTap,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: _DockFabButton(
                isOpen: addMenuOpen,
                onTap: onAddTap,
              ),
            ),
            Expanded(
              child: _DockNavItem(
                icon: HugeIcons.strokeRoundedAward01,
                label: 'Conquistas',
                selected: achievementsSelected,
                onTap: onAchievementsTap,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GlassPill extends StatelessWidget {
  const _GlassPill({
    required this.height,
    required this.child,
  });

  final double height;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TaskerGlassSurface(
      shape: TaskerGlassShape.pill,
      height: height,
      child: child,
    );
  }
}

class _DockNavItem extends StatelessWidget {
  const _DockNavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final List<List<dynamic>> icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color =
        selected ? TaskerColors.primary : TaskerColors.secondaryText;

    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(HomeAppDock.pillRadius),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            child: AppHugeIcon(icon: icon, color: color, size: 26),
          ),
        ),
      ),
    );
  }
}

class _DockFabButton extends StatefulWidget {
  const _DockFabButton({
    required this.onTap,
    this.isOpen = false,
  });

  final VoidCallback onTap;
  final bool isOpen;

  static const size = 48.0;
  static const iconSize = 22.0;
  static const iconPadding = 13.0;

  @override
  State<_DockFabButton> createState() => _DockFabButtonState();
}

class _DockFabButtonState extends State<_DockFabButton>
    with SingleTickerProviderStateMixin {
  static const _duration = Duration(milliseconds: 200);

  late final AnimationController _controller;
  late final Animation<double> _rotation;
  late final Animation<double> _scale;
  late final Animation<Color?> _color;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _duration);
    _rotation = Tween<double>(begin: 0, end: 0.125).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );
    _scale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 0.9)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 35,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 0.9, end: 1.0)
            .chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 65,
      ),
    ]).animate(_controller);
    _color = ColorTween(
      begin: TaskerColors.primary,
      end: TaskerColors.petroleumDark,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    if (widget.isOpen) _controller.value = 1;
  }

  @override
  void didUpdateWidget(covariant _DockFabButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isOpen == oldWidget.isOpen) return;
    if (widget.isOpen) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: widget.isOpen ? 'Fechar opções de criação' : 'Nova tarefa',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          customBorder: const CircleBorder(),
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              final color = _color.value ?? TaskerColors.primary;
              return Transform.scale(
                scale: _scale.value,
                child: Container(
                  width: _DockFabButton.size,
                  height: _DockFabButton.size,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.38),
                        blurRadius: 14,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Transform.rotate(
                    angle: _rotation.value * 2 * 3.141592653589793,
                    child: child,
                  ),
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.all(_DockFabButton.iconPadding),
              child: AppHugeIcon(
                icon: HugeIcons.strokeRoundedAdd01,
                color: Colors.white,
                size: _DockFabButton.iconSize,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
