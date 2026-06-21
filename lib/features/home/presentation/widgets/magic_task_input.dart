import 'dart:async';
import 'package:tasker_project/core/icons/tasker_icon.dart';

import 'package:hugeicons/hugeicons.dart';

import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../../app/theme/tasker_colors.dart';
import '../../../../core/config/env_config.dart';
import '../../../../core/config/magic_input_parser_config.dart';
import '../../../../core/config/magic_input_placeholder_config.dart';
import 'package:tasker_nlp/tasker_nlp.dart';
import '../../../../core/services/magic_task_builder.dart';
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

/// Padding interno uniforme do campo.
const _kInputInsetH = 14.0;
const _kInputInsetV = 12.0;
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

/// Campo mágico da home — NLP + voz + criação rápida de tarefa.
class MagicTaskInput extends StatefulWidget {
  const MagicTaskInput({
    super.key,
    required this.selectedDate,
    this.placeholder = 'Nova tarefa — digite ou fale…',
    this.onCreated,
    this.onCreateTask,
    this.isCreating = false,
    this.autofocus = false,
    this.onChromeActiveChanged,
    this.onHasTextChanged,
  });

  /// Dia selecionado na home — usado quando o NLP não extrai data.
  final DateTime selectedDate;
  final String placeholder;
  final VoidCallback? onCreated;

  /// Dispara a criação na home — não aguarda (evita perder a tarefa ao fechar).
  final void Function(String text)? onCreateTask;

  /// Estado de criação controlado pela home (sobrevive ao fechar o teclado).
  final bool isCreating;
  final bool autofocus;
  final ValueChanged<bool>? onChromeActiveChanged;
  final ValueChanged<bool>? onHasTextChanged;

  @override
  State<MagicTaskInput> createState() => MagicTaskInputState();
}

class MagicTaskInputState extends State<MagicTaskInput>
    with TickerProviderStateMixin, WidgetsBindingObserver {
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
  Timer? _fadeCycleTimer;
  Timer? _hintTimer;

  int _fadeCycleGeneration = 0;
  double _placeholderOpacity = 1.0;

  late List<String> _phraseQueue;
  late AnimationController _borderController;

  String _liveTranscript = '';

  /// Incrementado ao parar/enviar — ignora [onText] tardio do motor de voz.
  int _voiceSessionId = 0;

  /// Gravação contínua ao segurar o microfone — soltar cria a tarefa.
  bool _isHoldToTalk = false;

  double _lastViewInsetBottom = 0;
  DateTime? _suppressOutsideDismissUntil;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _lastViewInsetBottom = MediaQuery.viewInsetsOf(context).bottom;
    });
  }

  @override
  void didUpdateWidget(MagicTaskInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isCreating && !_borderController.isAnimating) {
      _borderController.duration = const Duration(milliseconds: 2200);
      _borderController.repeat();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(TaskSpeechService.stopListening());
    _typingTimer?.cancel();
    _cursorTimer?.cancel();
    _fadeCycleTimer?.cancel();
    _hintTimer?.cancel();
    _borderController.dispose();
    _focusNode.removeListener(_onFocusChanged);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    if (_focusNode.hasFocus) {
      _suppressOutsideDismissUntil = DateTime.now().add(
        const Duration(milliseconds: 450),
      );
      _typingTimer?.cancel();
      _fadeCycleTimer?.cancel();
      _fadeCycleGeneration++;
      _cursorTimer?.cancel();
      if (!_borderController.isAnimating) {
        _borderController.repeat();
      }
    } else if (!_isListening && !widget.isCreating) {
      _borderController.stop();
      _resumePlaceholderIfIdle();
      _startCursorBlink();
    }
    _notifyChromeActive();
  }

  void _notifyChromeActive() {
    widget.onChromeActiveChanged?.call(_focusNode.hasFocus || _isListening);
  }

  void _notifyHasText() {
    widget.onHasTextChanged?.call(_controller.text.trim().isNotEmpty);
  }

  /// Fecha teclado, foco e gravação de voz (ex.: botão voltar).
  void dismissChrome() => _dismissInputChrome();

  /// Abre o teclado após o magic input aparecer no overlay.
  void requestInputFocus() {
    if (!mounted) return;
    _focusNode.requestFocus();
  }

  bool get isChromeActive => _focusNode.hasFocus || _isListening;

  /// Verdadeiro enquanto interpreta/cria a tarefa.
  bool get isSubmitting => widget.isCreating || _isSubmitting;

  /// Chamado pela home quando a criação assíncrona termina.
  void onExternalCreationFinished({required bool success}) {
    if (!mounted) return;
    _liveTranscript = '';
    _controller.clear();
    _notifyHasText();
    if (success) {
      _setHint('Tarefa criada ✅');
      _releaseFocus();
    } else {
      _setHint(
        'Falha ao criar tarefa',
        duration: const Duration(milliseconds: 1800),
      );
    }
    if (!_focusNode.hasFocus && !_isListening) {
      _borderController
        ..stop()
        ..reset();
    }
    _resumePlaceholderIfIdle();
  }

  void _releaseFocus({bool hideKeyboard = true}) {
    if (hideKeyboard) {
      SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
    }

    final textLen = _controller.text.length;
    _controller.selection = TextSelection.collapsed(offset: textLen);

    if (_focusNode.hasFocus) {
      _focusNode.unfocus(disposition: UnfocusDisposition.scope);
    }

    final primary = FocusManager.instance.primaryFocus;
    if (primary != null &&
        primary.context?.findAncestorStateOfType<MagicTaskInputState>() !=
            null) {
      primary.unfocus(disposition: UnfocusDisposition.scope);
    }

    if (!_isListening) {
      _borderController
        ..stop()
        ..reset();
    }

    if (mounted) {
      setState(() {});
      _notifyChromeActive();
    }
  }

  @override
  void didChangeMetrics() {
    if (!mounted) return;
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    final previous = _lastViewInsetBottom;
    _lastViewInsetBottom = bottom;

    // Só reage ao fechamento estável do teclado — evita falso positivo na abertura.
    if (previous < 80 || bottom >= 80 || !_focusNode.hasFocus) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_focusNode.hasFocus || isSubmitting) return;
      if (MediaQuery.viewInsetsOf(context).bottom >= 80) return;
      _releaseFocus(hideKeyboard: false);
    });
  }

  void _dismissInputChrome() {
    if (_isListening) {
      unawaited(_cancelHoldVoice());
      return;
    }
    _releaseFocus();
  }

  void _handleTapOutside() {
    if (isSubmitting) return;
    if (_suppressOutsideDismissUntil != null &&
        DateTime.now().isBefore(_suppressOutsideDismissUntil!)) {
      return;
    }
    if (_isListening) {
      unawaited(_cancelHoldVoice());
      return;
    }
    _releaseFocus();
  }

  bool get _placeholderPaused =>
      _focusNode.hasFocus ||
      _controller.text.isNotEmpty ||
      _isListening ||
      isSubmitting;

  void _startCursorBlink() {
    if (!MagicInputPlaceholderConfig.useTypingAnimation) return;
    _cursorTimer?.cancel();
    _cursorTimer = Timer.periodic(const Duration(milliseconds: _kBlinkMs), (_) {
      if (!mounted || _placeholderPaused) return;
      setState(() => _cursorOn = !_cursorOn);
    });
  }

  void _resumePlaceholderIfIdle() {
    if (_placeholderPaused) return;
    if (MagicInputPlaceholderConfig.useTypingAnimation) {
      _typedLen = 0;
      _deleting = false;
      _animatedPhrase = '';
      _cursorOn = true;
      _startCursorBlink();
    } else {
      _placeholderOpacity = 1.0;
    }
    _startPlaceholderCycle();
  }

  void _startPlaceholderCycle() {
    if (MagicInputPlaceholderConfig.useTypingAnimation) {
      _startTypingPlaceholderCycle();
    } else {
      _startFadePlaceholderCycle();
    }
  }

  void _startFadePlaceholderCycle() {
    _typingTimer?.cancel();
    _fadeCycleTimer?.cancel();
    _fadeCycleGeneration++;

    if (_placeholderPaused) {
      setState(() => _animatedPhrase = '');
      return;
    }

    if (_phraseQueue.isEmpty) {
      _phraseQueue = _shuffleSuggestions(_kSuggestions);
    }
    if (_animatedPhrase.isEmpty) {
      _animatedPhrase = _phraseQueue.first;
      _placeholderOpacity = 1.0;
    }

    _fadeCycleTimer = Timer.periodic(
      MagicInputPlaceholderConfig.fadeCycleInterval,
      (_) => _advanceFadePlaceholder(),
    );
  }

  void _advanceFadePlaceholder() {
    if (!mounted || _placeholderPaused) return;

    final generation = ++_fadeCycleGeneration;
    setState(() => _placeholderOpacity = 0);

    Future<void>.delayed(MagicInputPlaceholderConfig.fadeDuration, () {
      if (!mounted ||
          _placeholderPaused ||
          generation != _fadeCycleGeneration) {
        return;
      }

      if (_phraseQueue.isEmpty) {
        _phraseQueue = _shuffleSuggestions(_kSuggestions);
      } else {
        _phraseQueue.removeAt(0);
        if (_phraseQueue.isEmpty) {
          _phraseQueue = _shuffleSuggestions(_kSuggestions);
        }
      }

      setState(() {
        _animatedPhrase = _phraseQueue.first;
        _placeholderOpacity = 1.0;
      });
    });
  }

  /// Animação legada caractere a caractere — reativar via
  /// [MagicInputPlaceholderConfig.useTypingAnimation].
  void _startTypingPlaceholderCycle() {
    _typingTimer?.cancel();
    _fadeCycleTimer?.cancel();
    _fadeCycleGeneration++;
    if (_placeholderPaused) {
      setState(() => _animatedPhrase = '');
      return;
    }

    if (_phraseQueue.isEmpty) {
      _phraseQueue = _shuffleSuggestions(_kSuggestions);
    }

    void step() {
      if (!mounted || _placeholderPaused || isSubmitting) return;

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
          _typingTimer = Timer(const Duration(milliseconds: _kTypeMs), step);
        } else {
          _typingTimer = Timer(const Duration(milliseconds: _kHoldEndMs), () {
            if (!mounted) return;
            setState(() => _deleting = true);
            _typingTimer = Timer(
              const Duration(milliseconds: _kDeleteMs),
              step,
            );
          });
        }
      } else {
        if (_typedLen > 0) {
          setState(() {
            _typedLen--;
            _animatedPhrase = phrase.substring(0, _typedLen);
          });
          _typingTimer = Timer(const Duration(milliseconds: _kDeleteMs), step);
        } else {
          _phraseQueue.removeAt(0);
          if (_phraseQueue.isEmpty) {
            _phraseQueue = _shuffleSuggestions(_kSuggestions);
          }
          setState(() => _deleting = false);
          _typingTimer = Timer(
            const Duration(milliseconds: _kHoldStartMs),
            step,
          );
        }
      }
    }

    _typingTimer = Timer(
      Duration(milliseconds: _deleting ? _kDeleteMs : _kTypeMs),
      step,
    );
  }

  void _setHint(
    String message, {
    Duration duration = const Duration(milliseconds: 1200),
  }) {
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
    color: TaskerColors.mutedText.withValues(alpha: 0.92),
    fontSize: 15,
    height: 1.25,
  );

  Future<Task> _buildTaskFromText(String text) {
    return MagicTaskBuilder.buildFromText(
      text: text,
      referenceDate: widget.selectedDate,
    );
  }

  void _createTaskFromText(String text) {
    final trimmed = text.trim();
    if (isSubmitting || trimmed.isEmpty) return;

    debugPrint('MagicTaskInput: enviando "$trimmed"');

    if (widget.onCreateTask != null) {
      if (MagicInputParserConfig.useGeminiParser &&
          EnvConfig.isGeminiConfigured) {
        _setHint('Interpretando com IA…', duration: const Duration(seconds: 12));
      } else {
        final placeHint = extractPlacePTBR(trimmed);
        if (placeHint != null && !placeHint.skipGeocoding) {
          _setHint(
            'Localizando endereço…',
            duration: const Duration(seconds: 8),
          );
        } else {
          _setHint('Criando tarefa…', duration: const Duration(seconds: 8));
        }
      }
      if (!_borderController.isAnimating) {
        _borderController.duration = const Duration(milliseconds: 2200);
        _borderController.repeat();
      }
      widget.onCreateTask!(trimmed);
      return;
    }

    unawaited(_createTaskFromTextInline(trimmed));
  }

  Future<void> _createTaskFromTextInline(String text) async {
    if (_isSubmitting || text.trim().isEmpty) return;

    setState(() => _isSubmitting = true);
    if (!_borderController.isAnimating) {
      _borderController.duration = const Duration(milliseconds: 2200);
      _borderController.repeat();
    }
    try {
      final task = await _buildTaskFromText(text.trim());
      if (!mounted) return;
      await context.read<TaskStore>().addTask(task);

      final selectedYmd = TaskStore.formatDateYmd(
        TaskStore.dateOnly(widget.selectedDate),
      );
      if (task.data == selectedYmd) widget.onCreated?.call();

      if (!mounted) return;

      _liveTranscript = '';
      _controller.clear();
      _notifyHasText();
      _releaseFocus();
      _setHint('Tarefa criada ✅');
    } catch (e, st) {
      debugPrint('MagicTaskInput._createTaskFromTextInline: $e\n$st');
      if (mounted) {
        _setHint(
          'Falha ao criar tarefa',
          duration: const Duration(milliseconds: 1800),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
        if (!_focusNode.hasFocus && !_isListening) {
          _borderController
            ..stop()
            ..reset();
        } else {
          _borderController.duration = const Duration(seconds: 4);
        }
        _resumePlaceholderIfIdle();
      }
    }
  }

  Future<void> _startVoice({bool holdToTalk = false}) async {
    if (_isListening || isSubmitting) return;

    final sessionId = ++_voiceSessionId;

    setState(() {
      _isListening = true;
      _isHoldToTalk = holdToTalk;
      _liveTranscript = '';
    });
    _notifyChromeActive();
    _controller.clear();
    _notifyHasText();
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
        if (!mounted || sessionId != _voiceSessionId || isSubmitting) return;
        _liveTranscript = transcript;
        _controller.text = transcript;
        _controller.selection = TextSelection.collapsed(
          offset: transcript.length,
        );
      },
      onError: (message) {
        if (!mounted) return;
        _voiceSessionId++;
        setState(() {
          _isListening = false;
          _isHoldToTalk = false;
          _liveTranscript = '';
        });
        _notifyChromeActive();
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
      _notifyChromeActive();
    }
  }

  Future<void> _cancelHoldVoice() async {
    _voiceSessionId++;
    setState(() {
      _isListening = false;
      _isHoldToTalk = false;
      _liveTranscript = '';
    });
    _notifyChromeActive();
    _controller.clear();
    _notifyHasText();
    _borderController.duration = const Duration(seconds: 4);
    await TaskSpeechService.stopListening();
    _setHint('Gravação cancelada');
    _resumePlaceholderIfIdle();
  }

  Future<void> _stopVoiceAndSubmit() async {
    if (isSubmitting) return;

    final wasListening = _isListening;
    setState(() {
      _isListening = false;
      _isHoldToTalk = false;
    });
    _notifyChromeActive();
    _borderController.duration = const Duration(seconds: 4);

    if (wasListening) {
      _setHint('Processando fala…', duration: const Duration(seconds: 4));
    }

    final finalized = wasListening
        ? await TaskSpeechService.finalizeListening()
        : TaskSpeechService.accumulatedTranscript.trim();

    // Invalida callbacks tardios só depois de aguardar o ASR finalizar.
    _voiceSessionId++;

    final finalTranscript =
        (finalized.isNotEmpty
                ? finalized
                : (_liveTranscript.isNotEmpty
                      ? _liveTranscript
                      : _controller.text))
            .trim();

    _liveTranscript = '';
    _controller.clear();
    _notifyHasText();

    if (!wasListening) {
      await TaskSpeechService.stopListening();
    }

    if (finalTranscript.isEmpty) {
      _setHint('Nada foi captado');
      _resumePlaceholderIfIdle();
      return;
    }
    _createTaskFromText(finalTranscript);
  }

  bool get _showSend =>
      !_isHoldToTalk &&
      (_isListening || _controller.text.trim().isNotEmpty) &&
      !isSubmitting;

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): _dismissInputChrome,
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_hint.isNotEmpty) ...[
            _MagicInputHintBubble(message: _hint),
            const SizedBox(height: 8),
          ],
          RepaintBoundary(
            child: ListenableBuilder(
              listenable: _focusNode,
              builder: (context, child) {
                return _MagicInputShell(
                  focused: _focusNode.hasFocus,
                  listening: _isListening,
                  submitting: isSubmitting,
                  borderAnimation: _borderController,
                  child: child!,
                );
              },
              child: Padding(
              padding: const EdgeInsets.fromLTRB(
                _kInputInsetH,
                _kInputInsetV,
                _kInputInsetH - 2,
                _kInputInsetV,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  TaskerAccentIconBadge(
                    icon: HugeIcons.strokeRoundedAiMagic,
                    accent: TaskerColors.primary,
                  ),
                  const SizedBox(width: _kIconTextGap),
                  Expanded(
                    child: Stack(
                      alignment: Alignment.centerLeft,
                      children: [
                        if (_showAnimatedPlaceholder)
                          IgnorePointer(
                            child: MagicInputPlaceholderConfig.useTypingAnimation
                                ? Row(
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
                                  )
                                : AnimatedOpacity(
                                    opacity: _placeholderOpacity,
                                    duration:
                                        MagicInputPlaceholderConfig.fadeDuration,
                                    curve: Curves.easeInOut,
                                    child: Text(
                                      _animatedPhrase,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: _hintTextStyle,
                                    ),
                                  ),
                          ),
                        TextField(
                          controller: _controller,
                          focusNode: _focusNode,
                          enabled: !isSubmitting,
                          onTapOutside: (_) => _handleTapOutside(),
                          onChanged: (_) {
                            setState(() {
                              if (_controller.text.isNotEmpty) {
                                _animatedPhrase = '';
                              } else {
                                _resumePlaceholderIfIdle();
                              }
                            });
                            _notifyHasText();
                          },
                          onSubmitted: (value) {
                            final trimmed = value.trim();
                            if (trimmed.isNotEmpty &&
                                !_isListening &&
                                !isSubmitting) {
                              _createTaskFromText(trimmed);
                            } else if (!isSubmitting) {
                              _releaseFocus();
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
                            fontSize: 15,
                            height: 1.25,
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
                    isSubmitting: isSubmitting,
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
          ),
        ],
      ),
    );
  }
}

class _MagicInputHintBubble extends StatelessWidget {
  const _MagicInputHintBubble({required this.message});

  final String message;

  static const _radius = 12.0;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(_radius),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 14,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Text(
          message,
          style: const TextStyle(
            fontSize: 13,
            height: 1.35,
            color: TaskerColors.secondaryText,
          ),
        ),
      ),
    );
  }
}

class _MagicInputShell extends StatelessWidget {
  const _MagicInputShell({
    required this.child,
    required this.focused,
    required this.listening,
    required this.submitting,
    required this.borderAnimation,
  });

  final Widget child;
  final bool focused;
  final bool listening;
  final bool submitting;
  final Animation<double> borderAnimation;

  static const _radius = 20.0;
  static const _borderWidth = 2.0;
  static const _glowBleed = 7.0;
  static const _idleBorderColor = Color(0xFFD6DAE8);

  static const _gradientColors = [
    Color(0xFF7864FF),
    Color(0xFFFF78C8),
    Color(0xFFFFC878),
    Color(0xFF78DCFF),
    Color(0xFF7864FF),
  ];

  @override
  Widget build(BuildContext context) {
    final active = focused || listening || submitting;
    final border = listening ? 2.25 : _borderWidth;
    final innerRadius = _radius - border;

    // Conteúdo interno estável — BackdropFilter não roda a cada tick da borda.
    final innerContent = ClipRRect(
      borderRadius: BorderRadius.circular(innerRadius),
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
              borderRadius: BorderRadius.circular(innerRadius),
            ),
            child: child,
          ),
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.all(_glowBleed),
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: borderAnimation,
          builder: (context, stableInner) {
            return Stack(
              clipBehavior: Clip.none,
              children: [
                if (active)
                  Positioned.fill(
                    child: RepaintBoundary(
                      child: CustomPaint(
                        painter: _MagicInputGlowPainter(
                          progress: borderAnimation.value,
                          borderRadius: _radius,
                        ),
                      ),
                    ),
                  ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(_radius),
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
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(_radius),
                      gradient: active
                          ? SweepGradient(
                              colors: _gradientColors,
                              transform: GradientRotation(
                                borderAnimation.value * math.pi * 2,
                              ),
                            )
                          : null,
                      color: active ? null : _idleBorderColor,
                    ),
                    padding: EdgeInsets.all(border),
                    child: stableInner,
                  ),
                ),
              ],
            );
          },
          child: innerContent,
        ),
      ),
    );
  }
}

/// Halo colorido que acompanha a rotação da borda ativa.
class _MagicInputGlowPainter extends CustomPainter {
  const _MagicInputGlowPainter({
    required this.progress,
    required this.borderRadius,
  });

  final double progress;
  final double borderRadius;

  static const _gradientColors = _MagicInputShell._gradientColors;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(borderRadius));
    final shader = SweepGradient(
      colors: _gradientColors,
      transform: GradientRotation(progress * math.pi * 2),
    ).createShader(rect);

    final outerGlow = Paint()
      ..shader = shader
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawRRect(rrect, outerGlow);

    final innerGlow = Paint()
      ..shader = shader
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.5);
    canvas.drawRRect(rrect, innerGlow);
  }

  @override
  bool shouldRepaint(covariant _MagicInputGlowPainter oldDelegate) {
    return oldDelegate.progress != progress;
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
    _holdTimer = Timer(const Duration(milliseconds: _kHoldToTalkDelayMs), () {
      if (!mounted || !_holdActive) return;
      _holdTriggered = true;
      widget.onMicHoldStart();
    });
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
                _SwapIcon(icon: HugeIcons.strokeRoundedMic01, visible: micVisual),
                _SwapIcon(icon: HugeIcons.strokeRoundedSent, visible: !micVisual),
              ],
            ),
    );

    if (widget.showSend && !widget.isHoldToTalk) {
      return Material(
        color: const Color(0xFFF2F3F8),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: widget.isSubmitting ? null : widget.onSend,
          borderRadius: BorderRadius.circular(12),
          child: child,
        ),
      );
    }

    return Material(
      color: const Color(0xFFF2F3F8),
      borderRadius: BorderRadius.circular(12),
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

  final List<List<dynamic>> icon;
  final bool visible;

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: visible ? 1 : 0,
      duration: const Duration(milliseconds: 180),
      child: AnimatedScale(
        scale: visible ? 1 : 0.85,
        duration: const Duration(milliseconds: 180),
        child: AppHugeIcon(icon: icon, size: 22, color: TaskerColors.secondaryText),
      ),
    );
  }
}
