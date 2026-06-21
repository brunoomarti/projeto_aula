import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../core/services/connectivity_service.dart';
import '../../../tasks/presentation/state/task_store.dart';
import '../../data/daily_combo_local_repository.dart';
import '../../data/daily_combo_supabase_repository.dart';
import '../../domain/daily_combo_calculator.dart';
import '../../domain/daily_combo_evaluator.dart';
import '../../domain/daily_combo_state.dart';
import '../../domain/daily_combo_task_rules.dart';

/// Estado global do combo diário — offline-first, sincronizado com Supabase.
class DailyComboController extends ChangeNotifier {
  DailyComboController({
    required TaskStore taskStore,
    DailyComboLocalRepository? localRepository,
    DailyComboSupabaseRepository? supabaseRepository,
    ConnectivityService? connectivity,
  })  : _taskStore = taskStore,
        _local = localRepository ?? DailyComboLocalRepository.instance,
        _remote = supabaseRepository ?? DailyComboSupabaseRepository(),
        _connectivity = connectivity ?? ConnectivityService() {
    _taskStore.addListener(_onTasksChanged);
    _connectivitySub =
        _connectivity.onStatusChange.listen((online) {
      if (online && _userId != null) {
        unawaited(_syncWithCloud());
      }
    });
  }

  final TaskStore _taskStore;
  final DailyComboLocalRepository _local;
  final DailyComboSupabaseRepository _remote;
  final ConnectivityService _connectivity;

  StreamSubscription<bool>? _connectivitySub;

  String? _userId;
  DailyComboState _state = const DailyComboState();
  bool _initialized = false;
  bool _loading = false;
  bool _syncing = false;
  bool _evaluating = false;

  int get currentStreak => _state.currentStreak;
  DailyComboState get state => _state;
  bool get isInitialized => _initialized;
  bool get isLoading => _loading;
  bool get isSyncing => _syncing;

  @override
  void dispose() {
    _taskStore.removeListener(_onTasksChanged);
    _connectivitySub?.cancel();
    super.dispose();
  }

  Future<void> loadForUser(String userId) async {
    if (userId.isEmpty) return;
    _userId = userId;
    _loading = true;
    notifyListeners();

    try {
      final local = await _local.read(userId);
      var merged = local ?? const DailyComboState();

      final online = await _connectivity.isOnline();
      if (online) {
        final remote = await _remote.fetchState();
        if (remote != null) {
          merged = _mergeInitial(merged, remote);
        }
      }

      _state = merged;
      _initialized = true;
      _loading = false;
      notifyListeners();

      await _evaluateAndPersist();
      unawaited(_syncWithCloud());
    } catch (e, st) {
      debugPrint('DailyComboController.loadForUser: $e\n$st');
      _initialized = true;
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> clear() async {
    final userId = _userId;
    _userId = null;
    _state = const DailyComboState();
    _initialized = false;
    _loading = false;
    notifyListeners();
    if (userId != null && userId.isNotEmpty) {
      await _local.clear(userId);
    }
  }

  void _onTasksChanged() {
    if (!_initialized || _userId == null) return;
    unawaited(_evaluateAndPersist());
  }

  Future<void> evaluateNow() async {
    if (!_initialized || _userId == null) return;
    await _evaluateAndPersist();
  }

  Future<void> _evaluateAndPersist() async {
    if (_evaluating || _userId == null) return;
    _evaluating = true;
    try {
      if (!_taskStore.isInitialized) return;

      final today = TaskStore.dateOnly(DateTime.now());
      ({int total, int completed}) statsForDate(DateTime date) {
        final dayTasks = _taskStore.tasksForDate(date, now: today);
        return DailyComboTaskRules.statsForDay(dayTasks, date, now: today);
      }

      final computed = DailyComboCalculator.compute(
        today: today,
        statsForDate: statsForDate,
      );

      final next = DailyComboEvaluator.evaluate(
        persisted: _state,
        computed: computed,
        today: today,
        statsForDate: statsForDate,
      );

      if (_statesEqual(_state, next)) return;

      _state = next;
      notifyListeners();
      await _local.write(_userId!, _state);
      unawaited(_syncWithCloud());
    } finally {
      _evaluating = false;
    }
  }

  Future<void> _syncWithCloud() async {
    if (_syncing || _userId == null || !_initialized) return;
    _syncing = true;
    notifyListeners();

    try {
      final online = await _connectivity.isOnline();
      if (!online) return;

      final remote = await _remote.fetchState();
      if (remote != null && _state.synced) {
        _state = _mergeRemote(remote, _state);
        notifyListeners();
        await _local.write(_userId!, _state);
      }

      if (!_state.synced || _state.pendingHistory.any((e) => !e.synced)) {
        await _remote.upsertState(_state);
        final toUpload = _state.pendingHistory.where((e) => !e.synced).toList();
        if (toUpload.isNotEmpty) {
          await _remote.insertHistoryEntries(toUpload);
        }
        _state = _state.copyWith(
          synced: true,
          pendingHistory: _state.pendingHistory
              .map((e) => e.copyWith(synced: true))
              .toList(growable: false),
        );
        await _local.write(_userId!, _state);
        notifyListeners();
      }
    } catch (e, st) {
      debugPrint('DailyComboController._syncWithCloud: $e\n$st');
    } finally {
      _syncing = false;
      notifyListeners();
    }
  }

  DailyComboState _mergeInitial(DailyComboState local, DailyComboState remote) {
    return local.copyWith(
      pendingArchiveLength:
          local.pendingArchiveLength ?? remote.pendingArchiveLength,
      pendingArchiveStartedOn:
          local.pendingArchiveStartedOn ?? remote.pendingArchiveStartedOn,
      pendingArchiveBrokenOn:
          local.pendingArchiveBrokenOn ?? remote.pendingArchiveBrokenOn,
    );
  }

  DailyComboState _mergeRemote(DailyComboState remote, DailyComboState local) {
    if (local.synced) return remote;
    return local;
  }

  bool _statesEqual(DailyComboState a, DailyComboState b) {
    return a.currentStreak == b.currentStreak &&
        _sameDate(a.streakStartedOn, b.streakStartedOn) &&
        _sameDate(a.lastClearedOn, b.lastClearedOn) &&
        a.pendingArchiveLength == b.pendingArchiveLength &&
        _sameDate(a.pendingArchiveStartedOn, b.pendingArchiveStartedOn) &&
        _sameDate(a.pendingArchiveBrokenOn, b.pendingArchiveBrokenOn) &&
        a.pendingHistory.length == b.pendingHistory.length;
  }

  bool _sameDate(DateTime? a, DateTime? b) {
    if (a == null && b == null) return true;
    if (a == null || b == null) return false;
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}
