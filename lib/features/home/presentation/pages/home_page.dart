import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../app/app_route_observer.dart';
import '../../../../app/theme/tasker_colors.dart';
import '../../../../core/services/user_local_service.dart';
import '../../../tasks/tasks.dart';
import '../widgets/user_dock.dart';

/// Home do Tasker: [UserDock] + lista de tarefas de hoje (armazenamento local).
class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.onOpenProfile,
  });

  final VoidCallback onOpenProfile;

  @override
  State<HomePage> createState() => HomePageState();
}

class HomePageState extends State<HomePage> with RouteAware {
  List<Task> _tasks = [];
  String? _displayName;
  bool _loading = true;
  int _totalSaved = 0;

  final Map<String, bool> _completionFlash = {};
  final Map<String, Timer> _flashTimers = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is ModalRoute<void>) {
      appRouteObserver.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    appRouteObserver.unsubscribe(this);
    for (final t in _flashTimers.values) {
      t.cancel();
    }
    super.dispose();
  }

  @override
  void didPopNext() {
    _load();
  }

  /// Recarrega nome do usuário e tarefas de hoje.
  Future<void> reload() => _load();

  Future<void> _load() async {
    if (mounted) {
      setState(() => _loading = true);
    }

    try {
      final name = await UserLocalService.getDisplayName();
      final now = DateTime.now();
      final todayTasks =
          await TaskLocalRepository.instance.getTasksForToday(now);
      final allCount = (await TaskLocalRepository.instance.getAll()).length;

      todayTasks.sort((a, b) {
        if (a.done != b.done) return (a.done ? 1 : 0) - (b.done ? 1 : 0);
        return a.hora.compareTo(b.hora);
      });

      if (!mounted) return;
      setState(() {
        _displayName = name;
        _tasks = todayTasks;
        _totalSaved = allCount;
        _loading = false;
      });
    } catch (e, st) {
      debugPrint('HomePage._load: $e\n$st');
      if (!mounted) return;
      setState(() {
        _tasks = [];
        _loading = false;
      });
    }
  }

  void _scheduleFlashEnd(String id) {
    _flashTimers[id]?.cancel();
    _flashTimers[id] = Timer(const Duration(milliseconds: 600), () {
      if (!mounted) return;
      setState(() {
        _completionFlash[id] = false;
        _flashTimers.remove(id);
      });
    });
  }

  Future<String?> _resolveAddress(Task task) async {
    final loc = task.location;
    if (loc == null) return null;
    return '${loc.lat.toStringAsFixed(5)}, ${loc.lng.toStringAsFixed(5)}';
  }

  Future<void> _openNewTask() async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(builder: (context) => const NewTaskPage()),
    );
    await _load();
  }

  Widget _emptyState() {
    if (_totalSaved > 0) {
      return const Center(
        child: Text(
          'Nenhuma tarefa para hoje.\n'
          'Você tem tarefas salvas em outras datas — '
          'confira a data ao criar ou abra Concluídas.',
          textAlign: TextAlign.center,
          style: TextStyle(color: TaskerColors.secondaryText),
        ),
      );
    }

    return const Center(
      child: Text(
        'Nenhuma tarefa para hoje.',
        style: TextStyle(color: TaskerColors.secondaryText),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            UserDock(
              displayName: _displayName,
              onProfileTap: widget.onOpenProfile,
              onAddTaskTap: _openNewTask,
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _tasks.isEmpty
                      ? _emptyState()
                      : ListView.separated(
                          padding: const EdgeInsets.only(bottom: 24),
                          itemCount: _tasks.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final task = _tasks[index];
                            final id = task.id;
                            return TaskCard(
                              key: ValueKey(id),
                              task: task,
                              onOpenDetails: () async {
                                await Navigator.of(context).push<void>(
                                  MaterialPageRoute<void>(
                                    builder: (context) => TaskDetailPage(
                                      task: task,
                                      resolveAddress: _resolveAddress,
                                    ),
                                  ),
                                );
                                await _load();
                              },
                              onToggleDone: () async {
                                final i =
                                    _tasks.indexWhere((t) => t.id == id);
                                if (i < 0) return;
                                final next = !_tasks[i].done;

                                if (next) {
                                  _flashTimers[id]?.cancel();
                                } else {
                                  _flashTimers[id]?.cancel();
                                  _flashTimers.remove(id);
                                }

                                await TaskLocalRepository.instance
                                    .updateTaskDone(id, next);

                                if (!mounted) return;
                                setState(() {
                                  _tasks[i] = _tasks[i].copyWith(done: next);
                                  _completionFlash[id] = next;
                                });

                                if (next) {
                                  _scheduleFlashEnd(id);
                                }
                              },
                              showCompletionFlash:
                                  _completionFlash[id] ?? false,
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
