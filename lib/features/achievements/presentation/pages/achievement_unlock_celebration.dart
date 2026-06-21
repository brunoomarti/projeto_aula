import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/theme/tasker_colors.dart';
import '../../domain/achievement_medal.dart';
import '../widgets/achievement_confetti_overlay.dart';
import '../widgets/achievement_hexagon_placeholder.dart';
import '../widgets/achievement_pop_in.dart';
import '../widgets/achievement_sunburst_background.dart';
import '../widgets/circle_iris_reveal.dart';

/// Tela cheia celebrando uma ou várias medalhas na mesma sessão.
class AchievementUnlockCelebration extends StatefulWidget {
  const AchievementUnlockCelebration({
    super.key,
    required this.medals,
    required this.onFinished,
  });

  final List<AchievementMedal> medals;
  final VoidCallback onFinished;

  @override
  State<AchievementUnlockCelebration> createState() =>
      _AchievementUnlockCelebrationState();
}

class _AchievementUnlockCelebrationState extends State<AchievementUnlockCelebration>
    with TickerProviderStateMixin {
  late final AnimationController _irisController;
  late final Animation<double> _iris;
  late final AnimationController _staggerController;
  late final Animation<double> _headlinePop;
  late final Animation<double> _stripPop;
  late final Animation<double> _cardPop;
  late final Animation<double> _emblemPop;
  late final Animation<double> _titlePop;
  late final Animation<double> _milestonePop;
  late final Animation<double> _buttonPop;

  int _currentIndex = 0;
  bool _confettiPlaying = false;
  bool _closing = false;
  int _confettiGeneration = 0;

  static const _irisDuration = Duration(milliseconds: 460);
  static const _staggerDuration = Duration(milliseconds: 980);

  AchievementMedal get _currentMedal => widget.medals[_currentIndex];

  bool get _hasMultiple => widget.medals.length > 1;
  bool get _isLast => _currentIndex >= widget.medals.length - 1;

  @override
  void initState() {
    super.initState();
    _irisController = AnimationController(
      vsync: this,
      duration: _irisDuration,
    );
    _iris = CurvedAnimation(
      parent: _irisController,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );

    _staggerController = AnimationController(
      vsync: this,
      duration: _staggerDuration,
    );
    _rebuildStaggerAnimations();
    _open();
  }

  void _rebuildStaggerAnimations() {
    _headlinePop = _bubbleInterval(0.00, 0.78);
    _stripPop = _bubbleInterval(0.06, 0.82);
    _cardPop = _bubbleInterval(0.10, 0.86);
    _emblemPop = _bubbleInterval(0.22, 0.92);
    _titlePop = _bubbleInterval(0.34, 0.96);
    _milestonePop = _bubbleInterval(0.46, 1.00);
    _buttonPop = _bubbleInterval(0.58, 1.00);
  }

  CurvedAnimation _bubbleInterval(double begin, double end) {
    return CurvedAnimation(
      parent: _staggerController,
      curve: Interval(begin, end, curve: Curves.easeOutBack),
    );
  }

  Future<void> _open() async {
    HapticFeedback.mediumImpact();
    await _irisController.forward();
    if (!mounted) return;
    setState(() {
      _confettiPlaying = true;
      _confettiGeneration++;
    });
    await _staggerController.forward();
  }

  Future<void> _advanceToNext() async {
    HapticFeedback.lightImpact();
    await _staggerController.reverse();
    if (!mounted) return;

    setState(() {
      _currentIndex++;
      _confettiPlaying = true;
      _confettiGeneration++;
    });
    _staggerController.reset();
    await _staggerController.forward();
  }

  Future<void> _confirm() async {
    if (_closing) return;

    if (!_isLast) {
      await _advanceToNext();
      return;
    }

    setState(() => _closing = true);
    HapticFeedback.lightImpact();
    await _staggerController.reverse();
    if (!mounted) return;
    await _irisController.reverse();
    if (!mounted) return;
    widget.onFinished();
  }

  @override
  void dispose() {
    _irisController.dispose();
    _staggerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final earned = widget.medals.sublist(0, _currentIndex);

    return PopScope(
      canPop: false,
      child: Material(
        type: MaterialType.transparency,
        child: AnimatedBuilder(
          animation: _iris,
          builder: (context, child) {
            return CircleIrisReveal(
              progress: _iris.value,
              child: child!,
            );
          },
          child: Stack(
            fit: StackFit.expand,
            children: [
              const AchievementSunburstBackground(color: TaskerColors.primary),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      const Spacer(flex: 2),
                      AchievementPopIn(
                        animation: _headlinePop,
                        child: Text(
                          _hasMultiple
                              ? 'Conquistas desbloqueadas!'
                              : 'Conquista desbloqueada!',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                            color: Colors.white.withValues(alpha: 0.96),
                            shadows: [
                              Shadow(
                                color: Colors.black.withValues(alpha: 0.18),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (_hasMultiple) ...[
                        const SizedBox(height: 8),
                        AchievementPopIn(
                          animation: _headlinePop,
                          child: Text(
                            '${_currentIndex + 1} de ${widget.medals.length}',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Colors.white.withValues(alpha: 0.82),
                            ),
                          ),
                        ),
                      ],
                      if (earned.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        AchievementPopIn(
                          animation: _stripPop,
                          child: _EarnedMedalsStrip(medals: earned),
                        ),
                      ],
                      const SizedBox(height: 20),
                      AchievementPopIn(
                        key: ValueKey(_currentMedal.id),
                        animation: _cardPop,
                        child: SizedBox(
                          width: double.infinity,
                          child: _CelebrationCard(
                            emblemPop: _emblemPop,
                            titlePop: _titlePop,
                            milestonePop: _milestonePop,
                            medal: _currentMedal,
                          ),
                        ),
                      ),
                      const Spacer(flex: 2),
                      AchievementPopIn(
                        animation: _buttonPop,
                        child: SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: _closing ? null : _confirm,
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: TaskerColors.primary,
                              disabledBackgroundColor:
                                  Colors.white.withValues(alpha: 0.6),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              elevation: 4,
                              shadowColor: Colors.black.withValues(alpha: 0.22),
                            ),
                            child: Text(
                              _isLast ? 'Continuar' : 'Próxima conquista',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),
              IgnorePointer(
                child: AchievementConfettiOverlay(
                  key: ValueKey(_confettiGeneration),
                  playing: _confettiPlaying,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Medalhas já reveladas nesta sessão — permanecem visíveis com destaque suave.
class _EarnedMedalsStrip extends StatelessWidget {
  const _EarnedMedalsStrip({required this.medals});

  final List<AchievementMedal> medals;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          for (var i = 0; i < medals.length; i++) ...[
            if (i > 0) const SizedBox(width: 10),
            _EarnedMedalChip(medal: medals[i]),
          ],
        ],
      ),
    );
  }
}

class _EarnedMedalChip extends StatelessWidget {
  const _EarnedMedalChip({required this.medal});

  final AchievementMedal medal;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 148),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const AchievementHexagonPlaceholder(size: 36, unlocked: true),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              medal.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                height: 1.2,
                color: Colors.white.withValues(alpha: 0.95),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CelebrationCard extends StatelessWidget {
  const _CelebrationCard({
    required this.emblemPop,
    required this.titlePop,
    required this.milestonePop,
    required this.medal,
  });

  final Animation<double> emblemPop;
  final Animation<double> titlePop;
  final Animation<double> milestonePop;
  final AchievementMedal medal;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 6,
      shadowColor: Colors.black.withValues(alpha: 0.28),
      color: TaskerColors.cardBackground,
      borderRadius: BorderRadius.circular(28),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(40, 52, 40, 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AchievementPopIn(
              animation: emblemPop,
              child: const AchievementHexagonPlaceholder(
                size: 132,
                unlocked: true,
              ),
            ),
            const SizedBox(height: 32),
            AchievementPopIn(
              animation: titlePop,
              child: Text(
                medal.title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  height: 1.2,
                  letterSpacing: -0.35,
                  color: TaskerColors.primaryText,
                ),
              ),
            ),
            const SizedBox(height: 14),
            AchievementPopIn(
              animation: milestonePop,
              child: Text(
                medal.milestoneLabel,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  height: 1.35,
                  color: TaskerColors.secondaryText.withValues(alpha: 0.95),
                ),
              ),
            ),
            if (medal.flavorText case final flavor?) ...[
              const SizedBox(height: 12),
              AchievementPopIn(
                animation: milestonePop,
                child: Text(
                  flavor,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.35,
                    fontStyle: FontStyle.italic,
                    color: TaskerColors.secondaryText.withValues(alpha: 0.85),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
