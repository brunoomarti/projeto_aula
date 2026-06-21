import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/foundation.dart';

import '../../../../core/auth/firebase_user_id.dart';
import '../../../../core/services/connectivity_service.dart';
import '../../data/pilha_local_repository.dart';
import '../../data/task_local_repository.dart';
import '../../data/task_repository.dart';
import '../../data/task_supabase_repository.dart';
import '../../domain/home_list_entry.dart';
import '../../domain/pilha.dart';
import '../../domain/task.dart';
import '../../domain/task_postponement.dart';

/// Estado global das tarefas — **offline-first**.
///
/// Fonte da verdade local: [TaskLocalRepository] (sempre disponível).
/// A nuvem ([TaskRepository]/Supabase) é sincronizada quando há conexão.
///
/// Fluxo:
/// - [reload] carrega o cache local imediatamente e dispara o sync com a nuvem
///   em background (não bloqueia a UI).
/// - Mutações aplicam em memória + gravam local na hora (marcando `synced=false`)
///   e tentam enviar à nuvem; se offline/erro de rede, ficam pendentes.
/// - Ao voltar a conexão, as pendências são enviadas automaticamente.
class TaskStore extends ChangeNotifier {
  TaskStore({
    TaskRepository? repository,
    TaskLocalRepository? localRepository,
    PilhaLocalRepository? pilhaRepository,
    ConnectivityService? connectivity,
  })  : _repository = repository ?? TaskSupabaseRepository(),
        _local = localRepository ?? TaskLocalRepository.instance,
        _pilhasLocal = pilhaRepository ?? PilhaLocalRepository.instance,
        _connectivity = connectivity ?? ConnectivityService() {
    _connectivitySub =
        _connectivity.onStatusChange.listen(_handleConnectivityChange);
    _authSub = firebase_auth.FirebaseAuth.instance.idTokenChanges().listen(
      _handleAuthTokenChange,
    );
  }

  final TaskRepository _repository;
  final TaskLocalRepository _local;
  final PilhaLocalRepository _pilhasLocal;
  final ConnectivityService _connectivity;
  StreamSubscription<bool>? _connectivitySub;
  StreamSubscription<firebase_auth.User?>? _authSub;

  List<Task> _tasks = [];
  List<Pilha> _pilhas = [];
  bool _initialized = false;
  bool _loading = false;
  bool _online = true;
  bool _syncing = false;
  int _statsVersion = 0;
  bool _cloudSyncEnabled = true;

  bool get isLoading => _loading;
  bool get isInitialized => _initialized;
  bool get isOnline => _online;
  bool get cloudSyncEnabled => _cloudSyncEnabled;

  /// `true` enquanto há uma sincronização com a nuvem em andamento.
  bool get isSyncing => _syncing;

  /// `true` se há alterações locais ainda não enviadas à nuvem.
  bool get hasPendingSync => _tasks.any((t) => !t.synced);
  int get pendingCount => _tasks.where((t) => !t.synced).length;

  /// Incrementa quando contagens por dia mudam — útil para [Selector].
  int get statsVersion => _statsVersion;

  void setCloudSyncEnabled(bool enabled) {
    if (_cloudSyncEnabled == enabled) return;
    _cloudSyncEnabled = enabled;
    notifyListeners();
  }

  /// Lista imutável de todas as tarefas (inclui soft-deleted).
  List<Task> get tasks => List.unmodifiable(_tasks);

  /// Pilhas cadastradas pelo usuário.
  List<Pilha> get pilhas => List.unmodifiable(_pilhas);

  List<Task> get activeTasks =>
      _tasks.where((t) => !t.deleted).toList(growable: false);

  int get totalActiveCount => activeTasks.length;

  @override
  void dispose() {
    _connectivitySub?.cancel();
    _authSub?.cancel();
    super.dispose();
  }

  /// Carrega o cache local (instantâneo) e sincroniza com a nuvem em background.
  Future<void> reload() async {
    _loading = true;
    notifyListeners();

    try {
      _tasks = await _local.getAll();
      _pilhas = await _pilhasLocal.getAll();
    } catch (e, st) {
      debugPrint('TaskStore.reload (local): $e\n$st');
      _tasks = [];
      _pilhas = [];
    } finally {
      _initialized = true;
      _loading = false;
      _invalidateStatsCache();
      notifyListeners();
    }

    // Sincroniza com a nuvem sem bloquear a UI.
    if (_cloudSyncEnabled) {
      unawaited(_syncWithCloud());
    }
  }

  /// Recarrega as tarefas do disco (forçando releitura do [SharedPreferences])
  /// e mescla — útil quando o app volta ao primeiro plano e o widget criou
  /// tarefas em outro isolate. Não exibe spinner (atualização silenciosa).
  Future<void> refreshFromDisk() async {
    try {
      await _local.reloadFromDisk();
      final disk = await _local.getAll();
      _tasks = _merge(remote: disk, local: _tasks);
      _pilhas = await _pilhasLocal.getAll();
      _invalidateStatsCache();
      notifyListeners();
    } catch (e, st) {
      debugPrint('TaskStore.refreshFromDisk: $e\n$st');
      return;
    }
    if (_cloudSyncEnabled) {
      unawaited(_syncWithCloud());
    }
  }

  /// Limpa estado local em memória e no dispositivo (logout).
  Future<void> clear() async {
    _tasks = [];
    _pilhas = [];
    _initialized = false;
    _loading = false;
    _invalidateStatsCache();
    notifyListeners();
    try {
      await _local.saveAll(const []);
      await _pilhasLocal.saveAll(const []);
    } catch (e, st) {
      debugPrint('TaskStore.clear (local): $e\n$st');
    }
  }

  // ---------------------------------------------------------------------------
  // Sincronização com a nuvem
  // ---------------------------------------------------------------------------

  Future<void> _syncWithCloud() async {
    if (!_cloudSyncEnabled) return;
    if (_syncing) return;
    _syncing = true;
    notifyListeners();
    try {
      _online = await _connectivity.isOnline();
      if (!_online) {
        notifyListeners();
        return;
      }

      // 1) Baixa o estado remoto e mescla com pendências locais.
      try {
        final remote = await _repository.fetchAll();
        _tasks = _merge(remote: remote, local: _tasks);
        await _saveLocal();
        _invalidateStatsCache();
        notifyListeners();
      } catch (e, st) {
        debugPrint('TaskStore._syncWithCloud (fetch): $e\n$st');
        if (_isOfflineError(e)) {
          // Falha de rede na API — não altera isOnline (banner usa só conectividade).
          return;
        }
      }

      // 2) Envia as pendências locais.
      await _pushPending();
    } finally {
      _syncing = false;
      notifyListeners();
    }
  }

  /// Mescla o estado remoto com o local, priorizando pendências locais.
  static List<Task> _merge({
    required List<Task> remote,
    required List<Task> local,
  }) {
    final localById = {for (final t in local) t.id: t};
    final byId = <String, Task>{};
    for (final t in remote) {
      final loc = localById[t.id];
      if (loc?.pilhaId != null && t.pilhaId == null) {
        byId[t.id] = t.copyWith(pilhaId: loc!.pilhaId);
      } else {
        byId[t.id] = t;
      }
    }
    // Pendências locais sobrescrevem a versão remota; tarefas só locais nunca somem.
    for (final t in local) {
      final remoteTask = byId[t.id];
      if (remoteTask == null || !t.synced) {
        byId[t.id] = t;
      }
    }
    return byId.values.toList(growable: true);
  }

  /// Tenta enviar todas as tarefas pendentes (`synced == false`).
  Future<void> _pushPending() async {
    if (!_online) return;
    final pending = _tasks.where((t) => !t.synced).toList(growable: false);
    for (final task in pending) {
      await _pushTask(task);
    }
  }

  /// Envia uma tarefa à nuvem. Retorna `true` se sincronizou.
  Future<bool> _pushTask(Task task) async {
    if (!_cloudSyncEnabled) return false;

    _online = await _connectivity.isOnline();
    if (!_online) return false;

    if (currentFirebaseUserId() == null) {
      debugPrint('TaskStore._pushTask: usuário não autenticado — sync adiado.');
      return false;
    }

    try {
      await _repository.upsertTask(task);
      await _markSynced(task);
      return true;
    } catch (e, st) {
      debugPrint('TaskStore._pushTask(${task.id}): $e\n$st');
      if (_isOfflineError(e)) {
        return false;
      }
      return false;
    }
  }

  /// Marca a tarefa como sincronizada, se ela não mudou desde o envio.
  Future<void> _markSynced(Task pushed) async {
    final index = _tasks.indexWhere((t) => t.id == pushed.id);
    if (index < 0) return;
    final current = _tasks[index];
    if (current.synced) return;

    final pushedAt = pushed.lastUpdated;
    final currentAt = current.lastUpdated;
    if (pushedAt != null &&
        currentAt != null &&
        currentAt.isAfter(pushedAt)) {
      return;
    }

    _tasks = [..._tasks]..[index] = current.copyWith(synced: true);
    await _saveLocal();
    notifyListeners();
  }

  void _handleConnectivityChange(bool online) {
    final wasOnline = _online;
    _online = online;
    notifyListeners();
    if (online && !wasOnline && _initialized && _cloudSyncEnabled) {
      unawaited(_syncWithCloud());
    }
  }

  /// Re-sincroniza quando o JWT do Firebase fica disponível (login/conta nova).
  void _handleAuthTokenChange(firebase_auth.User? user) {
    if (user == null || !_cloudSyncEnabled || !_initialized) return;
    unawaited(_syncWithCloud());
  }

  /// Reenvia manualmente as pendências (ex.: botão "tentar novamente").
  Future<void> retrySync() async {
    if (!_cloudSyncEnabled) return;
    await _syncWithCloud();
  }

  static bool _isOfflineError(Object e) {
    final s = e.toString().toLowerCase();
    return s.contains('socketexception') ||
        s.contains('clientexception') ||
        s.contains('failed host lookup') ||
        s.contains('connection') ||
        s.contains('network') ||
        s.contains('timeout') ||
        s.contains('timed out') ||
        s.contains('unreachable');
  }

  // ---------------------------------------------------------------------------
  // Consultas / ordenação
  // ---------------------------------------------------------------------------

  Pilha? pilhaById(String? id) {
    if (id == null || id.isEmpty) return null;
    for (final pilha in _pilhas) {
      if (pilha.id == id) return pilha;
    }
    return null;
  }

  /// Cria uma pilha e persiste localmente.
  Future<Pilha> addPilha(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('Nome da pilha não pode ser vazio.');
    }
    final pilha = Pilha(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: trimmed,
      createdAt: DateTime.now(),
    );
    _pilhas = [..._pilhas, pilha];
    await _pilhasLocal.saveAll(_pilhas);
    notifyListeners();
    return pilha;
  }

  /// Adiciona uma tarefa a uma pilha existente.
  Future<void> assignTaskToPilha(String taskId, String pilhaId) async {
    final task = taskById(taskId);
    if (task == null || pilhaById(pilhaId) == null) return;
    if (task.pilhaId == pilhaId) return;

    final oldPilhaId = task.pilhaId;
    await updateTask(task.copyWith(pilhaId: pilhaId));
    await _cleanupPilhaIfOrphaned(oldPilhaId);
  }

  /// Cria uma pilha e agrupa as tarefas informadas.
  Future<Pilha> createPilhaWithTasks({
    required String name,
    required List<String> taskIds,
  }) async {
    final uniqueIds = taskIds.toSet().toList();
    if (uniqueIds.length < 2) {
      throw ArgumentError('Uma pilha precisa de pelo menos duas tarefas.');
    }

    final pilha = await addPilha(name);
    final oldPilhaIds = <String>{};

    for (final id in uniqueIds) {
      final task = taskById(id);
      if (task == null) continue;
      if (task.pilhaId != null && task.pilhaId!.isNotEmpty) {
        oldPilhaIds.add(task.pilhaId!);
      }
      await updateTask(task.copyWith(pilhaId: pilha.id));
    }

    for (final oldId in oldPilhaIds) {
      if (oldId != pilha.id) {
        await _cleanupPilhaIfOrphaned(oldId);
      }
    }

    return pilha;
  }

  /// Remove uma tarefa da pilha — ela volta a ser avulsa na lista do dia.
  Future<void> removeTaskFromPilha(String taskId) async {
    final task = taskById(taskId);
    if (task == null) return;

    final oldPilhaId = task.pilhaId;
    if (oldPilhaId == null || oldPilhaId.isEmpty) return;

    await updateTask(task.copyWith(clearPilhaId: true));
    await _cleanupPilhaIfOrphaned(oldPilhaId);
  }

  /// Dissolve pilhas com menos de duas tarefas.
  Future<void> _cleanupPilhaIfOrphaned(String? pilhaId) async {
    if (pilhaId == null || pilhaId.isEmpty || pilhaById(pilhaId) == null) {
      return;
    }

    final members =
        activeTasks.where((t) => t.pilhaId == pilhaId).toList(growable: false);
    if (members.length >= 2) return;

    for (final task in members) {
      await updateTask(task.copyWith(clearPilhaId: true));
    }

    _pilhas = _pilhas.where((p) => p.id != pilhaId).toList(growable: false);
    await _pilhasLocal.saveAll(_pilhas);
    notifyListeners();
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

  /// Entradas da home para um dia — tarefas avulsas ou pilhas agrupadas.
  List<HomeListEntry> entriesForDate(DateTime date, {DateTime? now}) {
    final dayTasks = tasksForDate(date, now: now);
    final pilhaIds = <String>{};
    final grouped = <String, List<Task>>{};

    for (final task in dayTasks) {
      final pilhaId = task.pilhaId;
      if (pilhaId == null || pilhaId.isEmpty || pilhaById(pilhaId) == null) {
        continue;
      }
      pilhaIds.add(pilhaId);
      grouped.putIfAbsent(pilhaId, () => []).add(task);
    }

    for (final tasks in grouped.values) {
      _sortTasksByDay(tasks);
    }

    final entries = <HomeListEntry>[];
    final consumedPilhaIds = <String>{};

    for (final task in dayTasks) {
      final pilhaId = task.pilhaId;
      if (pilhaId != null &&
          pilhaId.isNotEmpty &&
          pilhaIds.contains(pilhaId) &&
          !consumedPilhaIds.contains(pilhaId)) {
        consumedPilhaIds.add(pilhaId);
        final pilha = pilhaById(pilhaId)!;
        entries.add(
          HomePilhaEntry(pilha: pilha, tasks: grouped[pilhaId]!),
        );
        continue;
      }
      if (pilhaId != null &&
          pilhaId.isNotEmpty &&
          pilhaIds.contains(pilhaId)) {
        continue;
      }
      entries.add(HomeSingleTaskEntry(task));
    }

    entries.sort((a, b) {
      final aDone = switch (a) {
        HomeSingleTaskEntry(:final task) => task.done,
        HomePilhaEntry(:final tasks) =>
          tasks.isNotEmpty && tasks.every((t) => t.done),
      };
      final bDone = switch (b) {
        HomeSingleTaskEntry(:final task) => task.done,
        HomePilhaEntry(:final tasks) =>
          tasks.isNotEmpty && tasks.every((t) => t.done),
      };
      if (aDone != bDone) return (aDone ? 1 : 0) - (bDone ? 1 : 0);

      final aKey = switch (a) {
        HomeSingleTaskEntry(:final task) => horaSortKey(task.hora),
        HomePilhaEntry(:final tasks) => tasks.isEmpty
            ? 0
            : horaSortKey(tasks.first.hora),
      };
      final bKey = switch (b) {
        HomeSingleTaskEntry(:final task) => horaSortKey(task.hora),
        HomePilhaEntry(:final tasks) => tasks.isEmpty
            ? 0
            : horaSortKey(tasks.first.hora),
      };
      if (aKey != bKey) return aKey.compareTo(bKey);

      final aId = switch (a) {
        HomeSingleTaskEntry(:final task) => task.id,
        HomePilhaEntry(:final pilha) => pilha.id,
      };
      final bId = switch (b) {
        HomeSingleTaskEntry(:final task) => task.id,
        HomePilhaEntry(:final pilha) => pilha.id,
      };
      return aId.compareTo(bId);
    });

    return entries;
  }

  /// Resumo de conclusão das tarefas agendadas para [date] (todas contam, sem regras do combo).
  ({int total, int completed}) taskStatsForDate(DateTime date, {DateTime? now}) {
    final dayTasks = tasksForDate(date, now: now);
    var completed = 0;
    for (final task in dayTasks) {
      if (task.done) completed++;
    }
    return (total: dayTasks.length, completed: completed);
  }

  void _invalidateStatsCache() {
    _statsVersion++;
  }

  /// Tarefas de hoje, ordenadas (pendentes antes, depois por hora).
  List<Task> todayTasks([DateTime? now]) =>
      tasksForDate(now ?? DateTime.now(), now: now);

  /// Tarefas concluídas, mais recentes por hora primeiro.
  List<Task> get completedTasks {
    final list = activeTasks.where((t) => t.done).toList();
    list.sort((a, b) {
      final byHora = horaSortKey(b.hora).compareTo(horaSortKey(a.hora));
      if (byHora != 0) return byHora;
      return b.id.compareTo(a.id);
    });
    return list;
  }

  // ---------------------------------------------------------------------------
  // Mutações (offline-first)
  // ---------------------------------------------------------------------------

  Future<void> addTask(Task task) async {
    final now = DateTime.now();
    final pending = task.copyWith(
      synced: false,
      createdAt: task.createdAt ?? now,
      lastUpdated: now,
    );
    _tasks = [..._tasks, pending];
    await _commitLocalThenPush(pending);
  }

  Future<void> updateTask(Task task) async {
    final index = _tasks.indexWhere((t) => t.id == task.id);
    final previous = index >= 0 ? _tasks[index] : null;
    final now = DateTime.now();
    var pending = task.copyWith(synced: false, lastUpdated: now);
    if (previous != null) {
      pending = TaskPostponementRules.applyDateChange(
        previous: previous,
        updated: pending,
        now: now,
      );
    }
    if (index < 0) {
      _tasks = [..._tasks, pending];
    } else {
      _tasks = [..._tasks]..[index] = pending;
    }
    await _commitLocalThenPush(pending);
  }

  /// Grava endereço Places/Geocoding na tarefa após a primeira resolução.
  Future<void> persistTaskLocationAddress(
    String taskId,
    String formattedAddress,
  ) async {
    final task = taskById(taskId);
    final loc = task?.location;
    if (task == null || loc == null) return;

    final trimmed = formattedAddress.trim();
    if (trimmed.isEmpty || loc.formattedAddress == trimmed) return;

    await updateTask(
      task.copyWith(location: loc.copyWith(formattedAddress: trimmed)),
    );
  }

  Future<void> updateTaskDone(String taskId, bool done) async {
    final index = _tasks.indexWhere((t) => t.id == taskId);
    if (index < 0) return;
    final previous = _tasks[index];
    final pending = previous.copyWith(
      done: done,
      synced: false,
      lastUpdated: DateTime.now(),
      completedAt: done ? DateTime.now() : null,
      clearCompletedAt: !done,
    );
    _tasks = [..._tasks]..[index] = pending;
    await _commitLocalThenPush(pending);
  }

  Future<void> markTaskDeleted(String taskId) async {
    final index = _tasks.indexWhere((t) => t.id == taskId);
    if (index < 0) return;
    final pending = _tasks[index].copyWith(
      deleted: true,
      synced: false,
      lastUpdated: DateTime.now(),
    );
    _tasks = [..._tasks]..[index] = pending;
    await _commitLocalThenPush(pending);
  }

  /// Persiste a lista no dispositivo e tenta enviar a tarefa à nuvem.
  ///
  /// Falhas de rede deixam a tarefa pendente (não lança exceção). Falhas ao
  /// gravar localmente são propagadas (ex.: plugin não carregado).
  Future<void> _commitLocalThenPush(Task task) async {
    _invalidateStatsCache();
    notifyListeners();

    await _saveLocal();

    if (!_cloudSyncEnabled) return;

    var pushed = await _pushTask(task);
    if (!pushed) {
      await Future<void>.delayed(const Duration(milliseconds: 450));
      pushed = await _pushTask(task);
    }
    if (!pushed) {
      unawaited(_syncWithCloud());
    }
  }

  Future<void> _saveLocal() async {
    await _local.saveAll(_tasks);
  }
}
