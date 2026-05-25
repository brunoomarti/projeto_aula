import 'package:flutter/foundation.dart';

import '../../data/task_local_repository.dart';
import '../../domain/task.dart';

/// Estado global das tarefas — fonte da verdade em memória.
///
/// Carrega do disco uma vez na inicialização; mutações atualizam a lista
/// local e persistem em segundo plano, notificando os ouvintes (Provider).
class TaskStore extends ChangeNotifier {
  TaskStore({TaskLocalRepository? repository})
      : _repository = repository ?? TaskLocalRepository.instance;

  final TaskLocalRepository _repository;

  List<Task> _tasks = [];
  bool _initialized = false;
  bool _loading = false;
  Map<String, ({int total, int completed})>? _statsByDate;
  int _statsVersion = 0;

  bool get isLoading => _loading;
  bool get isInitialized => _initialized;

  /// Incrementa quando contagens por dia mudam — útil para [Selector].
  int get statsVersion => _statsVersion;

  /// Lista imutável de todas as tarefas (inclui soft-deleted).
  List<Task> get tasks => List.unmodifiable(_tasks);

  List<Task> get activeTasks =>
      _tasks.where((t) => !t.deleted).toList(growable: false);

  int get totalActiveCount => activeTasks.length;

  /// Carrega tarefas do disco (única leitura completa na abertura do app).
  Future<void> initialize() async {
    if (_initialized) return;

    _loading = true;
    notifyListeners();

    try {
      _tasks = await _repository.getAll();
      _initialized = true;
    } catch (e, st) {
      debugPrint('TaskStore.initialize: $e\n$st');
      _tasks = [];
      _initialized = true;
    } finally {
      _loading = false;
      _invalidateStatsCache();
      notifyListeners();
    }
  }

  Task? taskById(String id) {
    for (final task in _tasks) {
      if (task.id == id) return task;
    }
    return null;
  }

  static String formatDateYmd(DateTime date) {
    return '${date.year}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  /// Converte `HH:mm` em minutos desde meia-noite para ordenação estável.
  static int horaSortKey(String hora) {
    final parts = hora.split(':');
    if (parts.length < 2) return 0;
    final hours = int.tryParse(parts[0]) ?? 0;
    final minutes = int.tryParse(parts[1]) ?? 0;
    return hours * 60 + minutes;
  }

  static DateTime dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  static void _sortTasksByDay(List<Task> list) {
    list.sort((a, b) {
      if (a.done != b.done) return (a.done ? 1 : 0) - (b.done ? 1 : 0);
      final byHora = horaSortKey(a.hora).compareTo(horaSortKey(b.hora));
      if (byHora != 0) return byHora;
      return a.id.compareTo(b.id);
    });
  }

  /// Tarefas de um dia (`yyyy-MM-dd`), ordenadas (pendentes antes, depois por hora).
  ///
  /// Para o dia atual, tarefas sem data também entram na lista (legado).
  List<Task> tasksForDate(DateTime date, {DateTime? now}) {
    final ymd = formatDateYmd(date);
    final hoje = formatDateYmd(now ?? DateTime.now());
    var list = activeTasks.where((t) => t.data == ymd).toList();
    if (list.isEmpty && ymd == hoje) {
      list = activeTasks.where((t) => t.data.isEmpty).toList();
    }
    _sortTasksByDay(list);
    return list;
  }

  /// Resumo de conclusão das tarefas de um dia.
  ({int total, int completed}) taskStatsForDate(DateTime date, {DateTime? now}) {
    _ensureStatsCache(now: now);
    final ymd = formatDateYmd(date);
    return _statsByDate![ymd] ?? (total: 0, completed: 0);
  }

  void _invalidateStatsCache() {
    _statsByDate = null;
    _statsVersion++;
  }

  void _ensureStatsCache({DateTime? now}) {
    if (_statsByDate != null) return;

    final hoje = formatDateYmd(now ?? DateTime.now());
    final counts = <String, ({int total, int completed})>{};

    for (final task in activeTasks) {
      final ymd = task.data.isEmpty ? hoje : task.data;
      final current = counts[ymd] ?? (total: 0, completed: 0);
      counts[ymd] = (
        total: current.total + 1,
        completed: current.completed + (task.done ? 1 : 0),
      );
    }

    _statsByDate = counts;
  }

  /// Tarefas de hoje, ordenadas (pendentes antes, depois por hora).
  List<Task> todayTasks([DateTime? now]) =>
      tasksForDate(now ?? DateTime.now(), now: now);

  /// Tarefas concluídas, mais recentes por hora primeiro.
  List<Task> get completedTasks {
    final list = activeTasks.where((t) => t.done).toList();
    list.sort((a, b) {
      final byHora =
          horaSortKey(b.hora).compareTo(horaSortKey(a.hora));
      if (byHora != 0) return byHora;
      return b.id.compareTo(a.id);
    });
    return list;
  }

  Future<void> addTask(Task task) async {
    await _applyMutation(
      () {
        _tasks = [..._tasks, task];
      },
      persist: () => _repository.saveAll(_tasks),
    );
  }

  Future<void> updateTask(Task task) async {
    await _applyMutation(
      () {
        final index = _tasks.indexWhere((t) => t.id == task.id);
        if (index < 0) return;
        _tasks = [..._tasks]..[index] = task;
      },
      persist: () => _repository.saveAll(_tasks),
    );
  }

  Future<void> updateTaskDone(String taskId, bool done) async {
    await _applyMutation(
      () {
        final index = _tasks.indexWhere((t) => t.id == taskId);
        if (index < 0) return;
        _tasks = [..._tasks]
          ..[index] = _tasks[index].copyWith(
            done: done,
            lastUpdated: DateTime.now(),
          );
      },
      persist: () => _repository.saveAll(_tasks),
    );
  }

  Future<void> markTaskDeleted(String taskId) async {
    await _applyMutation(
      () {
        final index = _tasks.indexWhere((t) => t.id == taskId);
        if (index < 0) return;
        _tasks = [..._tasks]
          ..[index] = _tasks[index].copyWith(
            deleted: true,
            lastUpdated: DateTime.now(),
          );
      },
      persist: () => _repository.saveAll(_tasks),
    );
  }

  Future<void> _applyMutation(
    VoidCallback mutate, {
    required Future<void> Function() persist,
  }) async {
    final snapshot = _tasks;
    mutate();
    _invalidateStatsCache();
    notifyListeners();

    try {
      await persist();
    } catch (e, st) {
      debugPrint('TaskStore._applyMutation: $e\n$st');
      _tasks = snapshot;
      _invalidateStatsCache();
      notifyListeners();
      rethrow;
    }
  }
}
