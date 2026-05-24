import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../../../app/theme/tasker_colors.dart';
import '../../../../core/nlp/extract_place_pt_br.dart';
import '../../../../core/nlp/extract_when_pt_br.dart';
import '../../../../core/nlp/infer_task_icon_pt_br.dart';
import '../../../../core/nlp/resolve_place_location.dart';
import '../../../../core/services/location_service.dart';
import '../../../../core/services/task_speech_service.dart';
import '../../../tasks/domain/task.dart';
import '../../../tasks/presentation/state/task_store.dart';

import 'magic_input_suggestions.dart';

/// Sugestões animadas no placeholder — [magicTaskInput.jsx].
const _kSuggestions = kMagicInputSuggestions;

const _kCursorChar = '▏';
const _kBlinkMs = 250;
const _kTypeMs = 50;
const _kDeleteMs = 30;
const _kHoldEndMs = 1500;
const _kHoldStartMs = 350;

/// Padding interno uniforme do campo — espelha 14px do [magicInput.css].
const _kInputInset = 6.0;
const _kIconLeftExtra = 4.0;
const _kIconTextGap = 8.0;
const _kHoldToTalkDelayMs = 280;

List<String> _shuffleSuggestions(List<String> source) {
  final list = source.toList();
  final rng = math.Random();
  for (var i = list.length - 1; i > 0; i--) {
    final j = rng.nextInt(i + 1);
    final tmp = list[i];
    list[i] = list[j];
    list[j] = tmp;
  }
  return list;
}

String _capFirst(String str) {
  final match = RegExp(r'^\s*(\p{L})', unicode: true).firstMatch(str);
  if (match == null) return str;
  final start = match.start;
  final letter = match.group(1)!;
  return str.replaceRange(start, match.end, letter.toUpperCase());
}

/// Campo mágico da home — NLP + voz + criação rápida de tarefa.
class MagicTaskInput extends StatefulWidget {
  const MagicTaskInput({
    super.key,
    this.placeholder = 'Digite ou fale o que você quer fazer…',
    this.onCreated,
    this.autofocus = false,
  });

  final String placeholder;
  final VoidCallback? onCreated;
  final bool autofocus;

  @override
  State<MagicTaskInput> createState() => _MagicTaskInputState();
}

class _MagicTaskInputState extends State<MagicTaskInput>
    with TickerProviderStateMixin {
  static final _uuid = Uuid();

  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  bool _isListening = false;
  bool _isSubmitting = false;
  String _hint = '';

  String _animatedPhrase = '';
  int _typedLen = 0;
  bool _deleting = false;
  bool _cursorOn = true;

  Timer? _typingTimer;
  Timer? _cursorTimer;
  Timer? _hintTimer;

  late List<String> _phraseQueue;
  late AnimationController _borderController;

  String _liveTranscript = '';

  /// Incrementado ao parar/enviar — ignora [onText] tardio do motor de voz.
  int _voiceSessionId = 0;

  /// Gravação contínua ao segurar o microfone — soltar cria a tarefa.
  bool _isHoldToTalk = false;

  @override
  void initState() {
    super.initState();
    _phraseQueue = _shuffleSuggestions(_kSuggestions);
    _borderController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );
    _focusNode.addListener(_onFocusChanged);
    if (widget.autofocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focusNode.requestFocus();
      });
    }
    _startPlaceholderCycle();
    _startCursorBlink();
  }

  @override
  void dispose() {
    unawaited(TaskSpeechService.stopListening());
    _typingTimer?.cancel();
    _cursorTimer?.cancel();
    _hintTimer?.cancel();
    _borderController.dispose();
    _focusNode.removeListener(_onFocusChanged);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    if (_focusNode.hasFocus) {
      if (!_borderController.isAnimating) {
        _borderController.repeat();
      }
    } else if (!_isListening) {
      _borderController.stop();
    }
    setState(() {});
  }

  bool get _placeholderPaused =>
      _controller.text.isNotEmpty || _isListening || _isSubmitting;

  void _startCursorBlink() {
    _cursorTimer?.cancel();
    _cursorTimer = Timer.periodic(const Duration(milliseconds: _kBlinkMs), (_) {
      if (!mounted || _placeholderPaused) return;
      setState(() => _cursorOn = !_cursorOn);
    });
  }

  void _resumePlaceholderIfIdle() {
    if (_placeholderPaused) return;
    _typedLen = 0;
    _deleting = false;
    _animatedPhrase = '';
    _cursorOn = true;
    _startPlaceholderCycle();
  }

  void _startPlaceholderCycle() {
    _typingTimer?.cancel();
    if (_placeholderPaused) {
      setState(() => _animatedPhrase = '');
      return;
    }

    if (_phraseQueue.isEmpty) {
      _phraseQueue = _shuffleSuggestions(_kSuggestions);
    }

    void step() {
      if (!mounted || _placeholderPaused || _isSubmitting) return;

      if (_phraseQueue.isEmpty) {
        _phraseQueue = _shuffleSuggestions(_kSuggestions);
      }
      final phrase = _phraseQueue.first;

      if (!_deleting) {
        if (_typedLen < phrase.length) {
          setState(() {
            _typedLen++;
            _animatedPhrase = phrase.substring(0, _typedLen);
          });
          _typingTimer = Timer(
            const Duration(milliseconds: _kTypeMs),
            step,
          );
        } else {
          _typingTimer = Timer(const Duration(milliseconds: _kHoldEndMs), () {
            if (!mounted) return;
            setState(() => _deleting = true);
            _typingTimer = Timer(const Duration(milliseconds: _kDeleteMs), step);
          });
        }
      } else {
        if (_typedLen > 0) {
          setState(() {
            _typedLen--;
            _animatedPhrase = phrase.substring(0, _typedLen);
          });
          _typingTimer = Timer(
            const Duration(milliseconds: _kDeleteMs),
            step,
          );
        } else {
          _phraseQueue.removeAt(0);
          if (_phraseQueue.isEmpty) {
            _phraseQueue = _shuffleSuggestions(_kSuggestions);
          }
          setState(() => _deleting = false);
          _typingTimer = Timer(const Duration(milliseconds: _kHoldStartMs), step);
        }
      }
    }

    _typingTimer = Timer(
      Duration(milliseconds: _deleting ? _kDeleteMs : _kTypeMs),
      step,
    );
  }

  void _setHint(String message, {Duration duration = const Duration(milliseconds: 1200)}) {
    _hintTimer?.cancel();
    setState(() => _hint = message);
    _hintTimer = Timer(duration, () {
      if (mounted) setState(() => _hint = '');
    });
  }

  String? get _fieldHintText {
    if (_controller.text.isNotEmpty) return null;
    if (_placeholderPaused) return widget.placeholder;
    return null;
  }

  bool get _showAnimatedPlaceholder =>
      !_placeholderPaused && _controller.text.isEmpty;

  TextStyle get _hintTextStyle => TextStyle(
        color: TaskerColors.secondaryText.withValues(alpha: 0.6),
        fontSize: 14,
        height: 1.2,
      );

  Future<Task> _buildTaskFromText(String text) async {
    final normalized = dedupeRepeatedSpeech(text.trim());
    final placeExtract = extractPlacePTBR(normalized);
    final parsed = extractWhenPTBR(normalized, DateTime.now());
    final icon = inferTaskIconPTBR(normalized);

    var rawTitle = (parsed.title.isNotEmpty ? parsed.title : normalized).trim();
    if (placeExtract != null) {
      rawTitle = stripPlaceFromTitle(rawTitle, placeExtract);
      if (rawTitle.isEmpty) {
        rawTitle = stripPlaceFromTitle(normalized, placeExtract);
      }
    }

    final title = _capFirst(
      rawTitle.isNotEmpty ? rawTitle : (parsed.title.isNotEmpty ? parsed.title : normalized),
    );
    final data = parsed.dateYmd ?? TaskStore.formatDateYmd(DateTime.now());
    final hora = parsed.timeHHMM ?? '';

    TaskLocation? location;
    if (placeExtract != null) {
      var near = await LocationService.getQuickLocationForMap();
      near ??= await LocationService.refineLocationForMap();
      final resolved = await resolvePlaceLocation(placeExtract, near: near);
      location = resolved?.location;
    }

    final now = DateTime.now();

    return Task(
      id: _uuid.v4(),
      title: title,
      data: data,
      hora: hora,
      location: location,
      iconKey: icon.iconKey,
      iconBackgroundArgb: icon.backgroundArgb,
      createdAt: now,
      lastUpdated: now,
    );
  }

  Future<void> _createTaskFromText(String text) async {
    if (_isSubmitting || text.trim().isEmpty) return;

    setState(() => _isSubmitting = true);
    try {
      if (extractPlacePTBR(text.trim()) != null) {
        _setHint('Localizando endereço…', duration: const Duration(seconds: 6));
      }
      final task = await _buildTaskFromText(text.trim());
      if (!mounted) return;
      await context.read<TaskStore>().addTask(task);

      final isToday = task.data == TaskStore.formatDateYmd(DateTime.now());
      if (isToday) widget.onCreated?.call();

      _liveTranscript = '';
      _controller.clear();
      _setHint('Tarefa criada ✅');
    } catch (e, st) {
      debugPrint('MagicTaskInput._createTaskFromText: $e\n$st');
      _setHint('Falha ao criar tarefa', duration: const Duration(milliseconds: 1500));
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
        _resumePlaceholderIfIdle();
      }
    }
  }

  Future<void> _startVoice({bool holdToTalk = false}) async {
    if (_isListening || _isSubmitting) return;

    final sessionId = ++_voiceSessionId;

    setState(() {
      _isListening = true;
      _isHoldToTalk = holdToTalk;
      _liveTranscript = '';
    });
    _controller.clear();
    _setHint(
      holdToTalk
          ? 'Gravando… solte para criar a tarefa'
          : 'Gravando… clique em enviar para finalizar',
      duration: const Duration(seconds: 8),
    );
    _borderController.duration = const Duration(milliseconds: 2200);
    if (!_borderController.isAnimating) _borderController.repeat();

    await TaskSpeechService.startListening(
      pauseFor: holdToTalk
          ? const Duration(seconds: 20)
          : const Duration(seconds: 8),
      continuous: true,
      onText: (transcript) {
        if (!mounted || sessionId != _voiceSessionId || _isSubmitting) return;
        _liveTranscript = transcript;
        _controller.text = transcript;
        _controller.selection = TextSelection.collapsed(offset: transcript.length);
      },
      onError: (message) {
        if (!mounted) return;
        _voiceSessionId++;
        setState(() {
          _isListening = false;
          _isHoldToTalk = false;
          _liveTranscript = '';
        });
        _borderController.duration = const Duration(seconds: 4);
        final hint = message.contains('Permiss') || message.contains('perm')
            ? 'Permissão negada ao microfone'
            : message;
        _setHint(hint, duration: const Duration(milliseconds: 1800));
      },
    );

    if (!TaskSpeechService.isListening && mounted) {
      _voiceSessionId++;
      setState(() {
        _isListening = false;
        _isHoldToTalk = false;
        _liveTranscript = '';
      });
    }
  }

  Future<void> _cancelHoldVoice() async {
    _voiceSessionId++;
    setState(() {
      _isListening = false;
      _isHoldToTalk = false;
      _liveTranscript = '';
    });
    _controller.clear();
    _borderController.duration = const Duration(seconds: 4);
    await TaskSpeechService.stopListening();
    _setHint('Gravação cancelada');
    _resumePlaceholderIfIdle();
  }

  Future<void> _stopVoiceAndSubmit() async {
    if (_isSubmitting) return;

    final wasListening = _isListening;
    setState(() {
      _isListening = false;
      _isHoldToTalk = false;
    });
    _borderController.duration = const Duration(seconds: 4);

    if (wasListening) {
      _setHint('Processando fala…', duration: const Duration(seconds: 4));
    }

    final finalized = wasListening
        ? await TaskSpeechService.finalizeListening()
        : TaskSpeechService.accumulatedTranscript.trim();

    // Invalida callbacks tardios só depois de aguardar o ASR finalizar.
    _voiceSessionId++;

    final finalTranscript = (finalized.isNotEmpty
            ? finalized
            : (_liveTranscript.isNotEmpty
                ? _liveTranscript
                : _controller.text))
        .trim();

    _liveTranscript = '';
    _controller.clear();

    if (!wasListening) {
      await TaskSpeechService.stopListening();
    }

    if (finalTranscript.isEmpty) {
      _setHint('Nada foi captado');
      _resumePlaceholderIfIdle();
      return;
    }
    await _createTaskFromText(finalTranscript);
  }

  bool get _showSend =>
      !_isHoldToTalk &&
      (_isListening || _controller.text.trim().isNotEmpty) &&
      !_isSubmitting;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_hint.isNotEmpty) ...[
          Text(
            _hint,
            style: TextStyle(
              fontSize: 13,
              color: TaskerColors.secondaryText.withValues(alpha: 0.9),
            ),
          ),
          const SizedBox(height: 8),
        ],
        _MagicInputShell(
          focused: _focusNode.hasFocus,
          listening: _isListening,
          borderAnimation: _borderController,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              _kInputInset + _kIconLeftExtra,
              _kInputInset,
              _kInputInset,
              _kInputInset,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Icon(
                  Icons.auto_awesome,
                  size: 20,
                  color: TaskerColors.primary,
                ),
                const SizedBox(width: _kIconTextGap),
                Expanded(
                  child: Stack(
                    alignment: Alignment.centerLeft,
                    children: [
                      if (_showAnimatedPlaceholder)
                        IgnorePointer(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Text(
                                  _animatedPhrase,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: _hintTextStyle,
                                ),
                              ),
                              Opacity(
                                opacity: _cursorOn ? 1 : 0,
                                child: Text(
                                  _kCursorChar,
                                  style: _hintTextStyle,
                                ),
                              ),
                            ],
                          ),
                        ),
                      TextField(
                        controller: _controller,
                        focusNode: _focusNode,
                        enabled: !_isSubmitting,
                        onChanged: (_) => setState(() {
                          if (_controller.text.isNotEmpty) {
                            _animatedPhrase = '';
                          } else {
                            _resumePlaceholderIfIdle();
                          }
                        }),
                        onSubmitted: (value) {
                          if (value.trim().isNotEmpty &&
                              !_isListening &&
                              !_isSubmitting) {
                            _createTaskFromText(value);
                          }
                        },
                        decoration: InputDecoration(
                          hintText: _fieldHintText,
                          hintStyle: _hintTextStyle,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                          isCollapsed: true,
                        ),
                        style: const TextStyle(
                          fontSize: 14,
                          height: 1.2,
                          color: TaskerColors.primaryText,
                        ),
                        textInputAction: TextInputAction.done,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: _kIconTextGap),
                _MagicActionButton(
                  showSend: _showSend,
                  isListening: _isListening,
                  isHoldToTalk: _isHoldToTalk,
                  isSubmitting: _isSubmitting,
                  onMicTap: () => _startVoice(),
                  onMicHoldStart: () => _startVoice(holdToTalk: true),
                  onMicHoldEnd: _stopVoiceAndSubmit,
                  onMicHoldCancel: _cancelHoldVoice,
                  onSend: _isListening
                      ? _stopVoiceAndSubmit
                      : () => _createTaskFromText(_controller.text),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _MagicInputShell extends StatelessWidget {
  const _MagicInputShell({
    required this.child,
    required this.focused,
    required this.listening,
    required this.borderAnimation,
  });

  final Widget child;
  final bool focused;
  final bool listening;
  final Animation<double> borderAnimation;

  static const _radius = 14.0;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: borderAnimation,
      builder: (context, _) {
        return CustomPaint(
          painter: _MagicGradientBorderPainter(
            progress: borderAnimation.value,
            borderRadius: _radius,
            active: focused || listening,
            listening: listening,
          ),
          child: Container(
            margin: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(_radius - 2),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x0A000000),
                  blurRadius: 14,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: child,
          ),
        );
      },
    );
  }
}

class _MagicGradientBorderPainter extends CustomPainter {
  _MagicGradientBorderPainter({
    required this.progress,
    required this.borderRadius,
    required this.active,
    required this.listening,
  });

  final double progress;
  final double borderRadius;
  final bool active;
  final bool listening;

  static const _gradientColors = [
    Color.fromRGBO(120, 100, 255, 0.55),
    Color.fromRGBO(255, 120, 200, 0.55),
    Color.fromRGBO(255, 200, 120, 0.55),
    Color.fromRGBO(120, 220, 255, 0.55),
    Color.fromRGBO(120, 100, 255, 0.55),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(borderRadius));
    final shift = progress * 2;

    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment(-1 + shift, 0),
        end: Alignment(1 + shift, 0),
        colors: _gradientColors,
      ).createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    canvas.drawRRect(rrect, paint);
  }

  @override
  bool shouldRepaint(covariant _MagicGradientBorderPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.active != active ||
        oldDelegate.listening != listening;
  }
}

class _MagicActionButton extends StatefulWidget {
  const _MagicActionButton({
    required this.showSend,
    required this.isListening,
    required this.isHoldToTalk,
    required this.isSubmitting,
    required this.onMicTap,
    required this.onMicHoldStart,
    required this.onMicHoldEnd,
    required this.onMicHoldCancel,
    required this.onSend,
  });

  final bool showSend;
  final bool isListening;
  final bool isHoldToTalk;
  final bool isSubmitting;
  final VoidCallback onMicTap;
  final VoidCallback onMicHoldStart;
  final VoidCallback onMicHoldEnd;
  final VoidCallback onMicHoldCancel;
  final VoidCallback onSend;

  @override
  State<_MagicActionButton> createState() => _MagicActionButtonState();
}

class _MagicActionButtonState extends State<_MagicActionButton> {
  Timer? _holdTimer;
  bool _holdActive = false;
  bool _holdTriggered = false;

  @override
  void dispose() {
    _holdTimer?.cancel();
    super.dispose();
  }

  void _clearHoldState() {
    _holdTimer?.cancel();
    _holdTimer = null;
    _holdActive = false;
    _holdTriggered = false;
  }

  void _onPointerDown(PointerDownEvent event) {
    if (widget.isSubmitting || widget.showSend) return;

    _holdTriggered = false;
    _holdActive = true;
    _holdTimer = Timer(
      const Duration(milliseconds: _kHoldToTalkDelayMs),
      () {
        if (!mounted || !_holdActive) return;
        _holdTriggered = true;
        widget.onMicHoldStart();
      },
    );
  }

  void _onPointerUp(PointerUpEvent event) {
    if (widget.isSubmitting) return;

    if (_holdTriggered) {
      _clearHoldState();
      widget.onMicHoldEnd();
      return;
    }

    _holdTimer?.cancel();
    _holdTimer = null;
    final wasHoldAttempt = _holdActive;
    _holdActive = false;

    if (wasHoldAttempt && !widget.showSend) {
      widget.onMicTap();
    }
  }

  void _onPointerCancel(PointerCancelEvent event) {
    if (_holdTriggered) {
      _clearHoldState();
      widget.onMicHoldCancel();
      return;
    }
    _clearHoldState();
  }

  @override
  Widget build(BuildContext context) {
    final micVisual = !widget.showSend || widget.isHoldToTalk;

    final child = SizedBox(
      width: 42,
      height: 42,
      child: widget.isSubmitting
          ? const Padding(
              padding: EdgeInsets.all(11),
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Stack(
              alignment: Alignment.center,
              children: [
                _SwapIcon(
                  icon: Icons.mic,
                  visible: micVisual,
                ),
                _SwapIcon(
                  icon: Icons.send_rounded,
                  visible: !micVisual,
                ),
              ],
            ),
    );

    if (widget.showSend && !widget.isHoldToTalk) {
      return Material(
        color: const Color(0xFFF2F3F8),
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: widget.isSubmitting ? null : widget.onSend,
          borderRadius: BorderRadius.circular(10),
          child: child,
        ),
      );
    }

    return Material(
      color: const Color(0xFFF2F3F8),
      borderRadius: BorderRadius.circular(10),
      child: Listener(
        onPointerDown: _onPointerDown,
        onPointerUp: _onPointerUp,
        onPointerCancel: _onPointerCancel,
        child: child,
      ),
    );
  }
}

class _SwapIcon extends StatelessWidget {
  const _SwapIcon({required this.icon, required this.visible});

  final IconData icon;
  final bool visible;

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: visible ? 1 : 0,
      duration: const Duration(milliseconds: 180),
      child: AnimatedScale(
        scale: visible ? 1 : 0.85,
        duration: const Duration(milliseconds: 180),
        child: Icon(icon, size: 22, color: TaskerColors.secondaryText),
      ),
    );
  }
}
