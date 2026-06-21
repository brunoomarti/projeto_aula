import 'dart:ui';

import 'package:tasker_project/core/icons/tasker_icon.dart';

import 'package:hugeicons/hugeicons.dart';

import 'package:flutter/material.dart';

import '../../../../app/theme/tasker_colors.dart';
/// Overlay do menu de criação — fade suave + blur leve.
class CreateMenuScrim extends StatefulWidget {
  const CreateMenuScrim({
    super.key,
    required this.visible,
    required this.onTap,
  });

  final bool visible;
  final VoidCallback onTap;

  @override
  State<CreateMenuScrim> createState() => _CreateMenuScrimState();
}

class _CreateMenuScrimState extends State<CreateMenuScrim>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;

  static const _duration = Duration(milliseconds: 220);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _duration);
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    if (widget.visible) _controller.value = 1;
  }

  @override
  void didUpdateWidget(covariant CreateMenuScrim oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.visible == oldWidget.visible) return;
    if (widget.visible) {
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
    return AnimatedBuilder(
      animation: _fade,
      builder: (context, _) {
        final t = _fade.value;
        if (t <= 0.001) {
          return const IgnorePointer(child: SizedBox.shrink());
        }

        return IgnorePointer(
          ignoring: t < 0.04,
          child: GestureDetector(
            onTap: widget.onTap,
            behavior: HitTestBehavior.opaque,
            child: SizedBox.expand(
              child: RepaintBoundary(
                child: ClipRect(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 3.5 * t, sigmaY: 3.5 * t),
                    child: ColoredBox(
                      color: Colors.black.withValues(alpha: 0.18 * t),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Balões de escolha ao tocar no + do dock — criação inteligente ou formulário.
class HomeCreateTaskMenu extends StatefulWidget {
  const HomeCreateTaskMenu({
    super.key,
    required this.visible,
    required this.onMagicTap,
    required this.onManualTap,
    this.magicInputEnabled = true,
  });

  final bool visible;
  final VoidCallback onMagicTap;
  final VoidCallback onManualTap;
  final bool magicInputEnabled;

  static const bubbleGap = 8.0;

  /// Recuo mínimo entre o último balão e o topo do dock.
  static const dockGap = 6.0;

  @override
  State<HomeCreateTaskMenu> createState() => _HomeCreateTaskMenuState();
}

class _HomeCreateTaskMenuState extends State<HomeCreateTaskMenu>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _magicBubble;
  late final Animation<double> _manualBubble;

  static const _duration = Duration(milliseconds: 300);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _duration);
    _magicBubble = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.82, curve: Curves.easeOutBack),
    );
    _manualBubble = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.12, 0.94, curve: Curves.easeOutBack),
    );
    if (widget.visible) _controller.value = 1;
  }

  @override
  void didUpdateWidget(covariant HomeCreateTaskMenu oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.visible == oldWidget.visible) return;
    if (widget.visible) {
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
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        if (_controller.value <= 0.001) {
          return const SizedBox.shrink();
        }

        final interactive = _controller.value > 0.04;
        return IgnorePointer(
          ignoring: !interactive,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _PopBubble(
                animation: _magicBubble,
                child: _CreateTaskBubble(
                  icon: HugeIcons.strokeRoundedAiMagic,
                  title: 'Criação inteligente',
                  subtitle: widget.magicInputEnabled
                      ? 'Fale ou digite — a gente organiza'
                      : 'Disponível após fazer login',
                  accent: TaskerColors.primary,
                  enabled: widget.magicInputEnabled,
                  onTap: widget.onMagicTap,
                ),
              ),
              const SizedBox(height: HomeCreateTaskMenu.bubbleGap),
              _PopBubble(
                animation: _manualBubble,
                child: _CreateTaskBubble(
                  icon: HugeIcons.strokeRoundedNoteEdit,
                  title: 'Formulário completo',
                  subtitle: 'Data, horário e todos os detalhes',
                  accent: TaskerColors.petroleumDark,
                  onTap: widget.onManualTap,
                ),
              ),
              const SizedBox(height: HomeCreateTaskMenu.dockGap),
            ],
          ),
        );
      },
    );
  }
}

/// Pop + bounce com leve deslocamento vertical.
class _PopBubble extends StatelessWidget {
  const _PopBubble({
    required this.animation,
    required this.child,
  });

  final Animation<double> animation;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final t = animation.value;
        return Opacity(
          opacity: t.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, (1 - t) * 16),
            child: Transform.scale(
              scale: t,
              alignment: Alignment.bottomCenter,
              child: child,
            ),
          ),
        );
      },
      child: child,
    );
  }
}

class _CreateTaskBubble extends StatelessWidget {
  const _CreateTaskBubble({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.onTap,
    this.enabled = true,
  });

  final List<List<dynamic>> icon;
  final String title;
  final String subtitle;
  final Color accent;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final effectiveAccent =
        enabled ? accent : TaskerColors.mutedText.withValues(alpha: 0.55);

    return Opacity(
      opacity: enabled ? 1 : 0.72,
      child: Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: const [
              BoxShadow(
                color: Color(0x22000000),
                blurRadius: 20,
                offset: Offset(0, 8),
              ),
              BoxShadow(
                color: Color(0x0F000000),
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Stack(
              children: [
                Positioned.fill(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                    child: const ColoredBox(color: Colors.transparent),
                  ),
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.94),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        TaskerAccentIconBadge(icon: icon, accent: effectiveAccent),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                  color: TaskerColors.primaryText,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                subtitle,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  height: 1.25,
                                  color: TaskerColors.mutedText
                                      .withValues(alpha: 0.95),
                                ),
                              ),
                            ],
                          ),
                        ),
                        AppHugeIcon(
                          icon: HugeIcons.strokeRoundedArrowRight01,
                          size: 20,
                          color: TaskerColors.mutedText.withValues(alpha: 0.7),
                        ),
                      ],
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
