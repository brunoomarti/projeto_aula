import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import 'transcript_accumulator.dart';

/// Reconhecimento de voz para o [MagicTaskInput] — espelha [listenTaskByVoice].
class TaskSpeechService {
  TaskSpeechService._();

  static final stt.SpeechToText _speech = stt.SpeechToText();
  static bool _initialized = false;
  static Timer? _watchdog;
  static Timer? _restartTimer;

  static TranscriptAccumulator? _accumulator;
  static bool _sessionActive = false;
  static bool _continuous = false;
  static bool _finalizing = false;
  static Completer<void>? _finalizeCompleter;
  static Timer? _finalizeIdleTimer;
  static Timer? _finalizeMaxTimer;
  static DateTime? _finalizeStartedAt;
  static Duration _pauseFor = const Duration(seconds: 6);
  static void Function(String transcript)? _onText;
  static void Function(String message)? _onError;

  /// Silêncio após o último trecho antes de encerrar a captura.
  static const _finalizeIdlePeriod = Duration(milliseconds: 650);

  /// Tempo mínimo após parar o microfone (ASR ainda decodifica).
  static const _finalizeMinWait = Duration(milliseconds: 400);

  /// Limite total para não travar a UI.
  static const _finalizeMaxWait = Duration(milliseconds: 2200);

  static bool get isListening => _speech.isListening;

  static Future<bool> ensureInitialized() async {
    if (_initialized) return _speech.isAvailable;
    try {
      _initialized = await _speech.initialize(
        onError: (e) => debugPrint('TaskSpeechService: ${e.errorMsg}'),
        onStatus: _handleStatus,
      );
    } catch (e, st) {
      debugPrint('TaskSpeechService.ensureInitialized: $e\n$st');
      _initialized = false;
    }
    return _initialized && _speech.isAvailable;
  }

  static void _onListenStopForRestart() {
    _accumulator?.flush();
    _emitTranscript();
  }

  static void _handleStatus(String status) {
    debugPrint('TaskSpeechService status: $status');
    if (_finalizing) {
      if (status == 'done' ||
          status == 'notListening' ||
          status == 'doneNoResult') {
        _scheduleFinalizeCompletion();
      }
      return;
    }

    if (!_sessionActive || !_continuous) return;

    if (status == 'done' ||
        status == 'notListening' ||
        status == 'doneNoResult') {
      _onListenStopForRestart();
      _scheduleRestart();
    }
  }

  static void _completeFinalize() {
    final c = _finalizeCompleter;
    if (c != null && !c.isCompleted) {
      c.complete();
    }
  }

  static void _clearFinalizeTimers() {
    _finalizeIdleTimer?.cancel();
    _finalizeIdleTimer = null;
    _finalizeMaxTimer?.cancel();
    _finalizeMaxTimer = null;
    _finalizeStartedAt = null;
  }

  static void _scheduleFinalizeCompletion() {
    if (!_finalizing || _finalizeStartedAt == null) return;

    _finalizeIdleTimer?.cancel();
    final elapsed = DateTime.now().difference(_finalizeStartedAt!);
    final idleDelay = elapsed < _finalizeMinWait
        ? _finalizeIdlePeriod + (_finalizeMinWait - elapsed)
        : _finalizeIdlePeriod;

    _finalizeIdleTimer = Timer(idleDelay, _completeFinalize);
  }

  static void _onFinalizeResult() {
    if (!_finalizing) return;
    _emitTranscript();
    _scheduleFinalizeCompletion();
  }

  static void _scheduleRestart() {
    if (!_sessionActive || _speech.isListening) return;
    _restartTimer?.cancel();
    _restartTimer = Timer(const Duration(milliseconds: 120), () {
      if (_sessionActive && !_speech.isListening) {
        unawaited(_beginListen());
      }
    });
  }

  static void _armWatchdog(void Function(String message) onError) {
    _watchdog?.cancel();
    _watchdog = Timer(const Duration(seconds: 15), () {
      unawaited(stopListening());
      onError('Tempo esgotado sem captar fala');
    });
  }

  static void _emitTranscript() {
    final text = _accumulator?.text ?? '';
    _onText?.call(text);
  }

  static Future<void> _beginListen() async {
    if (!_sessionActive || _onText == null) return;

    if (_speech.isListening) {
      await _speech.stop();
    }

    var lastEmit = DateTime.fromMillisecondsSinceEpoch(0);

    try {
      await _speech.listen(
        onResult: (result) {
          if (!_sessionActive && !_finalizing) return;
          if (_onError != null) _armWatchdog(_onError!);
          _accumulator?.apply(
            result.recognizedWords,
            isFinal: result.finalResult,
          );

          if (_finalizing) {
            _onFinalizeResult();
          } else {
            final now = DateTime.now();
            if (now.difference(lastEmit).inMilliseconds > 60) {
              _emitTranscript();
              lastEmit = now;
            }
          }
        },
        listenOptions: stt.SpeechListenOptions(
          partialResults: true,
          listenMode: stt.ListenMode.dictation,
          cancelOnError: false,
          localeId: 'pt_BR',
          listenFor: const Duration(minutes: 2),
          pauseFor: _pauseFor,
        ),
      );
    } catch (e, st) {
      debugPrint('TaskSpeechService._beginListen: $e\n$st');
      if (_sessionActive) {
        _scheduleRestart();
      }
    }
  }

  static Future<void> startListening({
    required void Function(String transcript) onText,
    required void Function(String message) onError,
    Duration pauseFor = const Duration(seconds: 6),
    bool continuous = true,
  }) async {
    if (!await ensureInitialized()) {
      onError('Seu dispositivo não suporta voz');
      return;
    }

    if (!await _speech.hasPermission) {
      onError('Permissão negada ao microfone');
      return;
    }

    await stopListening(resetTranscript: false);

    _accumulator = TranscriptAccumulator()..reset();
    _sessionActive = true;
    _continuous = continuous;
    _pauseFor = pauseFor;
    _onText = onText;
    _onError = onError;

    _armWatchdog(onError);
    await _beginListen();
  }

  static Future<void> stopListening({bool resetTranscript = true}) async {
    _finalizing = false;
    _finalizeCompleter = null;
    _clearFinalizeTimers();
    _sessionActive = false;
    _continuous = false;
    _restartTimer?.cancel();
    _restartTimer = null;
    _watchdog?.cancel();
    _watchdog = null;

    if (_speech.isListening) {
      _accumulator?.flush();
      await _speech.stop();
    }

    if (resetTranscript) {
      _accumulator?.reset();
      _accumulator = null;
    }

    _onText = null;
    _onError = null;
  }

  /// Para o microfone e aguarda o ASR enviar o trecho final antes de devolver o texto.
  static Future<String> finalizeListening() async {
    _continuous = false;
    _restartTimer?.cancel();
    _restartTimer = null;
    _watchdog?.cancel();
    _watchdog = null;

    final shouldWait = _speech.isListening || _sessionActive;
    if (shouldWait) {
      _finalizing = true;
      _finalizeStartedAt = DateTime.now();
      _finalizeCompleter = Completer<void>();

      _finalizeMaxTimer = Timer(_finalizeMaxWait, _completeFinalize);
      _scheduleFinalizeCompletion();

      if (_speech.isListening) {
        try {
          await _speech.stop();
        } catch (e, st) {
          debugPrint('TaskSpeechService.finalizeListening stop: $e\n$st');
        }
      }

      await _finalizeCompleter!.future;
    }

    _finalizing = false;
    _finalizeCompleter = null;
    _clearFinalizeTimers();
    _accumulator?.flush();
    final text = _accumulator?.text.trim() ?? '';

    _sessionActive = false;
    _onText = null;
    _onError = null;
    _accumulator = null;

    return text;
  }

  /// Texto acumulado da sessão ativa (útil antes de [stopListening]).
  static String get accumulatedTranscript => _accumulator?.text ?? '';
}
