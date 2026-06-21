import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../core/services/connectivity_service.dart';
import '../../../tasks/domain/task.dart';
import '../../../tasks/presentation/state/task_store.dart';
import '../../data/achievement_local_repository.dart';
import '../../data/achievement_supabase_repository.dart';
import '../../domain/achievement_catalog.dart';
import '../../domain/achievement_evaluator.dart';
import '../../domain/achievement_event.dart';
import '../../domain/achievement_progress_state.dart';
import '../../domain/achievement_trail_flags.dart';
import '../../domain/achievement_trail_id.dart';

/// Estado global das conquistas — offline-first, sincronizado com Supabase.
class AchievementController extends ChangeNotifier {
  AchievementController({
    required TaskStore taskStore,
    AchievementLocalRepository? localRepository,
    AchievementSupabaseRepository? supabaseRepository,
    ConnectivityService? connectivity,
  })  : _taskStore = taskStore,
        _local = localRepository ?? AchievementLocalRepository.instance,
        _remote = supabaseRepository ?? AchievementSupabaseRepository(),
        _connectivity = connectivity ?? ConnectivityService() {
    _taskStore.addListener(_onStoreChanged);
    _connectivitySub = _connectivity.onStatusChange.listen((online) {
      if (online && isActive) {
        unawaited(_syncWithCloud());
      }
    });
    _scheduleDayChecks();
  }

  static const guestUserId = '__guest__';

  final TaskStore _taskStore;
  final AchievementLocalRepository _local;
  final AchievementSupabaseRepository _remote;
  final ConnectivityService _connectivity;

  StreamSubscription<bool>? _connectivitySub;
  Timer? _dayCheckTimer;

  String? _userId;
  AchievementProgressState _state = const AchievementProgressState();
  bool _initialized = false;
  bool _loading = false;
  bool _syncing = false;
  bool _processing = false;

  final Map<String, Task> _knownTasks = {};
  final Set<String> _knownPilhaIds = {};
  final List<String> _celebrationQueue = [];
  bool _celebrationsEnabled = false;

  AchievementProgressState get state => _state;
  bool get isInitialized => _initialized;
  bool get isLoading => _loading;
  bool get isSyncing => _syncing;

  /// Conquistas só funcionam com conta logada — não para visitantes.
  bool get isActive => _userId != null && _userId != guestUserId;

  int pointsForTrail(AchievementTrailId trail) => _state.pointsFor(trail);

  bool isMedalUnlocked(String medalId) => _state.isMedalUnlocked(medalId);

  String? get pendingCelebrationMedalId =>
      _celebrationQueue.isEmpty ? null : _celebrationQueue.first;

  List<String> get celebrationQueue =>
      List.unmodifiable(_celebrationQueue);

  void acknowledgeCelebration() {
    if (_celebrationQueue.isEmpty) return;
    _celebrationQueue.removeAt(0);
    notifyListeners();
  }

  @override
  void dispose() {
    _taskStore.removeListener(_onStoreChanged);
    _connectivitySub?.cancel();
    _dayCheckTimer?.cancel();
    super.dispose();
  }

  Future<void> loadForUser(String userId, {bool cloudSync = true}) async {
    if (userId.isEmpty) return;
    if (userId == guestUserId) {
      await disableForGuest();
      return;
    }
    _userId = userId;
    _loading = true;
    notifyListeners();

    try {
      var merged = await _local.read(userId) ?? const AchievementProgressState();

      if (cloudSync) {
        final online = await _connectivity.isOnline();
        if (online) {
          final remote = await _remote.fetchProgress();
          if (remote != null) {
            merged = AchievementProgressState.merge(merged, remote);
          }
        }
      }

      _state = merged;
      _seedKnownSnapshots();
      _initialized = true;
      _loading = false;
      _celebrationsEnabled = false;
      notifyListeners();

      await _processChanges(runDayChecks: true);
      _celebrationsEnabled = true;
      if (cloudSync) unawaited(_syncWithCloud());
    } catch (e, st) {
      debugPrint('AchievementController.loadForUser: $e\n$st');
      _initialized = true;
      _loading = false;
      notifyListeners();
    }
  }

  /// Desliga conquistas no modo visitante — sem progresso, sync ou celebrações.
  Future<void> disableForGuest() async {
    _userId = null;
    _state = const AchievementProgressState();
    _initialized = true;
    _loading = false;
    _syncing = false;
    _processing = false;
    _knownTasks.clear();
    _knownPilhaIds.clear();
    _celebrationQueue.clear();
    _celebrationsEnabled = false;
    notifyListeners();
    await _local.clear(guestUserId);
  }

  Future<void> clear() async {
    final userId = _userId;
    _userId = null;
    _state = const AchievementProgressState();
    _initialized = false;
    _loading = false;
    _knownTasks.clear();
    _knownPilhaIds.clear();
    _celebrationQueue.clear();
    _celebrationsEnabled = false;
    notifyListeners();
    if (userId != null && userId.isNotEmpty) {
      await _local.clear(userId);
    }
  }

  void _seedKnownSnapshots() {
    _knownTasks
      ..clear()
      ..addEntries(
        _taskStore.activeTasks.map((task) => MapEntry(task.id, task)),
      );
    _knownPilhaIds
      ..clear()
      ..addAll(_taskStore.pilhas.map((p) => p.id));
  }

  void _onStoreChanged() {
    if (!_initialized || !isActive) return;
    unawaited(_processChanges());
  }

  void _scheduleDayChecks() {
    _dayCheckTimer?.cancel();
    _dayCheckTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (!_initialized || !isActive) return;
      unawaited(_processChanges(runDayChecks: true));
    });
  }

  Future<void> _processChanges({bool runDayChecks = false}) async {
    if (_processing || !isActive || !_taskStore.isInitialized) return;
    _processing = true;

    try {
      final now = DateTime.now();
      final events = <AchievementEvent>[];

      for (final task in _taskStore.activeTasks) {
        final previous = _knownTasks[task.id];
        if (previous == null) {
          events.addAll(AchievementEvaluator.eventsForTaskCreated(task));
        } else if (previous.data != task.data) {
          final advance = AchievementEvaluator.eventForTaskDateChange(
            previous: previous,
            updated: task,
            now: now,
          );
          if (advance != null) events.add(advance);
        }
        _knownTasks[task.id] = task;
      }

      for (final pilha in _taskStore.pilhas) {
        if (!_knownPilhaIds.contains(pilha.id)) {
          events.add(AchievementEvaluator.eventForPilhaCreated(pilha));
          _knownPilhaIds.add(pilha.id);
        }
      }

      if (runDayChecks) {
        events.addAll(
          AchievementEvaluator.eventsForScheduledDayChecks(
            tasks: _taskStore.activeTasks,
            now: now,
            state: _state,
          ),
        );
      }

      final voiceStreak = AchievementEvaluator.eventForVoiceStreakCatchUp(
        tasks: _taskStore.activeTasks,
        state: _state,
      );
      if (voiceStreak != null) events.add(voiceStreak);

      final stampCollector = AchievementEvaluator.eventForStampCollectorCatchUp(
        tasks: _taskStore.activeTasks,
        state: _state,
      );
      if (stampCollector != null) events.add(stampCollector);

      final apollo13 = AchievementEvaluator.eventForApollo13CatchUp(
        tasks: _taskStore.activeTasks,
        state: _state,
      );
      if (apollo13 != null) events.add(apollo13);

      if (events.isEmpty) return;

      final previous = _state;
      var next = AchievementEvaluator.applyAll(_state, events);

      final apollo13AfterApply = AchievementEvaluator.eventForApollo13CatchUp(
        tasks: _taskStore.activeTasks,
        state: next,
      );
      if (apollo13AfterApply != null) {
        next = AchievementEvaluator.applyAll(next, [apollo13AfterApply]);
      }

      if (_statesEqual(next, previous)) return;

      _state = next;
      _enqueueNewMedals(previous, next);
      notifyListeners();
      await _local.write(_userId!, _state);
      unawaited(_syncWithCloud(previous: previous));
    } finally {
      _processing = false;
    }
  }

  Future<void> _syncWithCloud({AchievementProgressState? previous}) async {
    if (_syncing || _userId == null || _userId == guestUserId) return;
    _syncing = true;
    notifyListeners();

    try {
      final online = await _connectivity.isOnline();
      if (!online) return;

      final remote = await _remote.fetchProgress();
      if (remote != null && _state.synced) {
        final merged = AchievementProgressState.merge(_state, remote);
        if (!_statesEqual(merged, _state)) {
          _state = merged;
          notifyListeners();
          await _local.write(_userId!, _state);
        }
      }

      if (!_state.synced) {
        final before = previous ?? _state;
        await _remote.insertEvents(_state, before);
        await _remote.upsertProgress(_state);
        _state = _state.copyWith(synced: true);
        await _local.write(_userId!, _state);
        notifyListeners();
      }
    } catch (e, st) {
      debugPrint('AchievementController._syncWithCloud: $e\n$st');
    } finally {
      _syncing = false;
      notifyListeners();
    }
  }

  void _enqueueNewMedals(
    AchievementProgressState before,
    AchievementProgressState after,
  ) {
    if (!_celebrationsEnabled) return;

    final newIds = after.unlockedMedalIds.difference(before.unlockedMedalIds);
    if (newIds.isEmpty) return;

    for (final id in newIds) {
      final medal = AchievementCatalog.medalsById[id];
      if (medal != null && !AchievementTrailFlags.isEnabled(medal.trail)) {
        continue;
      }
      if (!_celebrationQueue.contains(id)) {
        _celebrationQueue.add(id);
      }
    }
  }

  bool _statesEqual(AchievementProgressState a, AchievementProgressState b) {
    if (a.recordedEventKeys.length != b.recordedEventKeys.length) return false;
    if (a.unlockedMedalIds.length != b.unlockedMedalIds.length) return false;
    for (final trail in AchievementTrailId.values) {
      if (a.pointsFor(trail) != b.pointsFor(trail)) return false;
    }
    return true;
  }
}
