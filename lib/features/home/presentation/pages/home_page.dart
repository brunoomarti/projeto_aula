import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../app/theme/tasker_colors.dart';
import '../../../../core/layout/tasker_breakpoints.dart';
import '../../../../core/services/user_local_service.dart';
import '../../../profile/presentation/pages/profile_page.dart';
import '../../../tasks/tasks.dart';
import '../widgets/animated_task_list.dart';
import '../widgets/home_day_selector.dart';
import '../widgets/home_new_task_button.dart';
import '../widgets/magic_task_input.dart';
import '../widgets/user_dock.dart';

/// Espaço entre header, lista e magic input.
const _kHomeSectionGap = 16.0;

/// Espaço vertical ao redor do seletor de dias (menor — sombra já tem margem interna).
const _kDaySelectorGap = 10.0;

/// Home do Tasker: [UserDock] + lista de tarefas de hoje ([TaskStore] em memória).
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => HomePageState();
}

class HomePageState extends State<HomePage> {
  String? _displayName;
  late DateTime _selectedDay;

  final Map<String, bool> _completionFlash = {};
  final Map<String, Timer> _flashTimers = {};

  String? _openSwipeId;
  SwipeOpenDirection? _openSwipeDir;
  String? _confirmDeleteId;

  @override
  void initState() {
    super.initState();
    _selectedDay = TaskStore.dateOnly(DateTime.now());
    reloadDisplayName();
  }

  @override
  void dispose() {
    for (final t in _flashTimers.values) {
      t.cancel();
    }
    super.dispose();
  }

  Future<void> reloadDisplayName() async {
    final name = await UserLocalService.getDisplayName();
    if (!mounted) return;
    setState(() => _displayName = name);
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

  Future<void> _openProfile() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (context) => ProfilePage(
          onNameSaved: reloadDisplayName,
        ),
      ),
    );
    if (!mounted) return;
    await reloadDisplayName();
  }

  Future<void> _openNewTask() async {
    final message = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(builder: (context) => const NewTaskPage()),
    );
    if (!mounted) return;
    if (message != null && message.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Tarefa criada com sucesso! $message')),
      );
    }
  }

  void _openSwipe(String? id, SwipeOpenDirection? dir) {
    setState(() {
      if (id == null) {
        _openSwipeId = null;
        _openSwipeDir = null;
      } else {
        _openSwipeId = id;
        _openSwipeDir = dir ?? SwipeOpenDirection.right;
      }
    });
  }

  void _closeSwipe() {
    setState(() {
      _openSwipeId = null;
      _openSwipeDir = null;
    });
  }

  Future<void> _confirmDelete() async {
    final id = _confirmDeleteId;
    if (id == null) return;

    try {
      await context.read<TaskStore>().markTaskDeleted(id);
    } catch (e, st) {
      debugPrint('HomePage._confirmDelete: $e\n$st');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Não foi possível excluir a tarefa.'),
          ),
        );
      }
    }

    if (!mounted) return;
    setState(() => _confirmDeleteId = null);
    _closeSwipe();
  }

  bool get _isSelectedToday {
    final today = TaskStore.dateOnly(DateTime.now());
    return _selectedDay.year == today.year &&
        _selectedDay.month == today.month &&
        _selectedDay.day == today.day;
  }

  Widget _emptyState(int totalSaved) {
    final dayLabel = _isSelectedToday ? 'hoje' : 'este dia';

    if (totalSaved > 0 && _isSelectedToday) {
      return Center(
        child: Text(
          'Nenhuma tarefa para $dayLabel.\n'
          'Você tem tarefas salvas em outras datas — '
          'confira a data ao criar uma nova tarefa.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: TaskerColors.secondaryText),
        ),
      );
    }

    return Center(
      child: Text(
        'Nenhuma tarefa para $dayLabel.',
        style: const TextStyle(color: TaskerColors.secondaryText),
      ),
    );
  }

  Widget _buildSwipeableTaskCard(Task task, TaskStore store) {
    final id = task.id;
    return SwipeableTaskCard(
      key: ValueKey(id),
      task: task,
      isOpen: _openSwipeId == id,
      openDir: _openSwipeId == id ? _openSwipeDir : null,
      onOpenSwipe: _openSwipe,
      onCloseSwipe: _closeSwipe,
      onAskDelete: () {
        setState(() => _confirmDeleteId = id);
      },
      onOpenDetails: () async {
        if (_openSwipeId != null) {
          _closeSwipe();
          return;
        }
        final current = store.taskById(id) ?? task;
        if (!mounted) return;
        await Navigator.of(context).push<void>(
          MaterialPageRoute<void>(
            builder: (context) => TaskDetailPage(task: current),
          ),
        );
      },
      onToggleDone: () async {
        final current = store.taskById(id);
        if (current == null) return;
        final next = !current.done;

        if (next) {
          _flashTimers[id]?.cancel();
        } else {
          _flashTimers[id]?.cancel();
          _flashTimers.remove(id);
        }

        try {
          await store.updateTaskDone(id, next);
        } catch (e, st) {
          debugPrint('HomePage.onToggleDone: $e\n$st');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Não foi possível atualizar a tarefa.'),
              ),
            );
          }
          return;
        }

        if (!mounted) return;
        setState(() {
          _completionFlash[id] = next;
          if (next) {
            _openSwipeId = null;
            _openSwipeDir = null;
          }
        });

        if (next) {
          _scheduleFlashEnd(id);
        }
      },
      showCompletionFlash: _completionFlash[id] ?? false,
    );
  }

  Widget _buildTaskList(TaskStore store) {
    if (store.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final tasks = store.tasksForDate(_selectedDay);
    if (tasks.isEmpty) {
      return _emptyState(store.totalActiveCount);
    }

    return AnimatedTaskList<Task>(
      padding: const EdgeInsets.only(bottom: 8),
      items: tasks,
      itemId: (task) => task.id,
      itemBuilder: (context, task) => _buildSwipeableTaskCard(task, store),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<TaskStore>();
    final tasks = store.tasksForDate(_selectedDay);
    final confirmTask = _confirmDeleteId == null
        ? null
        : tasks.cast<Task?>().firstWhere(
              (t) => t?.id == _confirmDeleteId,
              orElse: () => store.taskById(_confirmDeleteId!),
            );

    return Stack(
      children: [
        SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final pagePadding = TaskerBreakpoints.pagePadding(width);
              final horizontalPad = EdgeInsets.fromLTRB(
                pagePadding.left,
                0,
                pagePadding.right,
                0,
              );

              return Padding(
                padding: const EdgeInsets.only(top: 16, bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: horizontalPad,
                      child: TaskerResponsiveContent(
                        width: width,
                        child: UserDock(
                          displayName: _displayName,
                          selectedDate: _selectedDay,
                          onProfileTap: _openProfile,
                        ),
                      ),
                    ),
                    const SizedBox(height: _kDaySelectorGap),
                    HomeDaySelector(
                      selectedDate: _selectedDay,
                      edgeFadeWidth: pagePadding.left * 1.75,
                      onDateSelected: (date) {
                        setState(
                          () => _selectedDay = TaskStore.dateOnly(date),
                        );
                      },
                    ),
                    const SizedBox(height: _kDaySelectorGap),
                    Expanded(
                      child: Padding(
                        padding: horizontalPad,
                        child: TaskerResponsiveContent(
                          width: width,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              HomeNewTaskButton(onPressed: _openNewTask),
                              const SizedBox(height: _kHomeSectionGap),
                              Expanded(child: _buildTaskList(store)),
                              const SizedBox(height: _kHomeSectionGap),
                              MagicTaskInput(
                                placeholder:
                                    'Digite ou fale o que você quer fazer…',
                                onCreated: () {},
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        Positioned.fill(
          child: ConfirmDeleteDialog(
            open: _confirmDeleteId != null,
            taskTitle: confirmTask?.title,
            onCancel: () => setState(() => _confirmDeleteId = null),
            onConfirm: _confirmDelete,
          ),
        ),
      ],
    );
  }
}
