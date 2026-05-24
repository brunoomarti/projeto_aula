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

/// Fade superior na lista quando há scroll (suave).
const _kTaskListTopFadeHeight = 20.0;

/// Fade inferior — ancorado na base da tela, atrás do magic input.
const _kTaskListBottomFadeHeight = 36.0;

/// Respiro no fim do scroll — acima do magic input (só dentro da lista).
const _kTaskListScrollEndInset = 12.0;

/// Recuo do magic input acima da borda inferior segura.
const _kMagicInputBottomInset = 12.0;

/// Respiro vertical do cabeçalho (UserDock).
const _kHomeHeaderTopPadding = 24.0;
const _kHomeHeaderBottomPadding = 12.0;

/// Espaço vertical ao redor do seletor de dias (menor — sombra já tem margem interna).
const _kDaySelectorGap = 14.0;

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
      MaterialPageRoute<String>(
        builder: (context) => NewTaskPage(initialDate: _selectedDay),
      ),
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

  Widget _buildTaskList(
    TaskStore store, {
    required double scrollBottomPadding,
  }) {
    if (store.isLoading) {
      return Padding(
        padding: EdgeInsets.only(bottom: scrollBottomPadding),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    final tasks = store.tasksForDate(_selectedDay);
    if (tasks.isEmpty) {
      return Padding(
        padding: EdgeInsets.only(bottom: scrollBottomPadding),
        child: _emptyState(store.totalActiveCount),
      );
    }

    return AnimatedTaskList<Task>(
      padding: EdgeInsets.only(bottom: scrollBottomPadding),
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
          bottom: false,
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

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      pagePadding.left,
                      _kHomeHeaderTopPadding,
                      pagePadding.right,
                      _kHomeHeaderBottomPadding,
                    ),
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
                        child: _HomeTaskListSection(
                          selectedDay: _selectedDay,
                          onNewTask: _openNewTask,
                          taskListBuilder: (scrollBottomPadding) =>
                              _buildTaskList(
                            store,
                            scrollBottomPadding: scrollBottomPadding,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
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

/// Lista scrollável com botão «Nova tarefa» e magic input fixos por cima.
class _HomeTaskListSection extends StatefulWidget {
  const _HomeTaskListSection({
    required this.selectedDay,
    required this.onNewTask,
    required this.taskListBuilder,
  });

  final DateTime selectedDay;
  final VoidCallback onNewTask;
  final Widget Function(double scrollBottomPadding) taskListBuilder;

  @override
  State<_HomeTaskListSection> createState() => _HomeTaskListSectionState();
}

class _HomeTaskListSectionState extends State<_HomeTaskListSection> {
  final GlobalKey _headerKey = GlobalKey();
  final GlobalKey _footerKey = GlobalKey();
  final GlobalKey<MagicTaskInputState> _magicInputKey = GlobalKey();

  double _headerHeight = 0;
  double _footerHeight = 0;
  bool _showBottomListFade = false;
  bool _magicInputActive = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _measureChrome());
  }

  @override
  void didUpdateWidget(covariant _HomeTaskListSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    WidgetsBinding.instance.addPostFrameCallback((_) => _measureChrome());
  }

  void _measureChrome() {
    if (!mounted) return;

    final headerBox =
        _headerKey.currentContext?.findRenderObject() as RenderBox?;
    final footerBox =
        _footerKey.currentContext?.findRenderObject() as RenderBox?;

    final nextHeader =
        headerBox?.hasSize == true ? headerBox!.size.height.toDouble() : 0.0;
    final nextFooter =
        footerBox?.hasSize == true ? footerBox!.size.height.toDouble() : 0.0;

    if (nextHeader != _headerHeight || nextFooter != _footerHeight) {
      setState(() {
        _headerHeight = nextHeader;
        _footerHeight = nextFooter;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scrollBottomPadding =
        _footerHeight + _kTaskListScrollEndInset;

    return PopScope(
      canPop: !_magicInputActive,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _magicInputKey.currentState?.dismissChrome();
      },
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: Padding(
              padding: EdgeInsets.only(top: _headerHeight),
              child: ClipRect(
                child: _ScrollEdgeFades(
                  topFadeHeight: _kTaskListTopFadeHeight,
                  renderBottomFade: false,
                  onBottomFadeChanged: (visible) {
                    if (_showBottomListFade != visible) {
                      setState(() => _showBottomListFade = visible);
                    }
                  },
                  child: widget.taskListBuilder(scrollBottomPadding),
                ),
              ),
            ),
          ),
          if (_showBottomListFade)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: _footerHeight + _kTaskListBottomFadeHeight,
              child: const IgnorePointer(
                child: _VerticalEdgeFade(top: false, softEdge: true),
              ),
            ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: KeyedSubtree(
              key: _headerKey,
              child: ColoredBox(
                color: TaskerColors.appBackground,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    HomeNewTaskButton(onPressed: widget.onNewTask),
                    const SizedBox(height: _kHomeSectionGap),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: KeyedSubtree(
              key: _footerKey,
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.paddingOf(context).bottom +
                      _kMagicInputBottomInset,
                ),
                child: MagicTaskInput(
                  key: _magicInputKey,
                  selectedDate: widget.selectedDay,
                  placeholder: 'Digite ou fale o que você quer fazer…',
                  onCreated: () {},
                  onChromeActiveChanged: (active) {
                    if (_magicInputActive != active) {
                      setState(() => _magicInputActive = active);
                    }
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Fade superior/inferior conforme scroll disponível na lista.
class _ScrollEdgeFades extends StatefulWidget {
  const _ScrollEdgeFades({
    required this.topFadeHeight,
    required this.child,
    this.renderBottomFade = true,
    this.onBottomFadeChanged,
  });

  final double topFadeHeight;
  final Widget child;
  final bool renderBottomFade;
  final ValueChanged<bool>? onBottomFadeChanged;

  @override
  State<_ScrollEdgeFades> createState() => _ScrollEdgeFadesState();
}

class _ScrollEdgeFadesState extends State<_ScrollEdgeFades> {
  bool _showTopFade = false;
  bool _showBottomFade = false;

  static const _scrollEpsilon = 0.5;

  @override
  void initState() {
    super.initState();
    _scheduleInitialSync();
  }

  @override
  void didUpdateWidget(covariant _ScrollEdgeFades oldWidget) {
    super.didUpdateWidget(oldWidget);
    _scheduleInitialSync();
  }

  void _scheduleInitialSync({int attempt = 0}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final metrics = _scrollMetricsFromDescendants();
      if (metrics != null &&
          (metrics.maxScrollExtent > _scrollEpsilon || attempt >= 12)) {
        _syncFades(metrics);
        return;
      }
      if (attempt < 12) _scheduleInitialSync(attempt: attempt + 1);
    });
  }

  ScrollMetrics? _scrollMetricsFromDescendants() {
    ScrollMetrics? found;

    void visit(Element element) {
      if (found != null) return;
      if (element is StatefulElement && element.state is ScrollableState) {
        found = (element.state as ScrollableState).position;
        return;
      }
      element.visitChildren(visit);
    }

    (context as Element).visitChildren(visit);
    return found;
  }

  void _syncFades(ScrollMetrics metrics) {
    if (metrics.axis != Axis.vertical) return;

    final canScroll =
        metrics.maxScrollExtent > metrics.minScrollExtent + _scrollEpsilon;
    final showTop =
        canScroll && metrics.pixels > metrics.minScrollExtent + _scrollEpsilon;
    final showBottom = canScroll &&
        metrics.pixels < metrics.maxScrollExtent - _scrollEpsilon;

    final topChanged = showTop != _showTopFade;
    final bottomChanged = showBottom != _showBottomFade;

    if (!topChanged && !bottomChanged) return;

    if (widget.renderBottomFade) {
      setState(() {
        _showTopFade = showTop;
        _showBottomFade = showBottom;
      });
    } else {
      if (topChanged) {
        setState(() => _showTopFade = showTop);
      }
      if (bottomChanged) {
        widget.onBottomFadeChanged?.call(showBottom);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        NotificationListener<ScrollNotification>(
          onNotification: (notification) {
            _syncFades(notification.metrics);
            return false;
          },
          child: widget.child,
        ),
        if (_showTopFade)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: widget.topFadeHeight,
            child: const _VerticalEdgeFade(top: true, softEdge: true),
          ),
        if (widget.renderBottomFade && _showBottomFade)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: widget.topFadeHeight,
            child: const _VerticalEdgeFade(top: false),
          ),
      ],
    );
  }
}

class _VerticalEdgeFade extends StatelessWidget {
  const _VerticalEdgeFade({
    required this.top,
    this.softEdge = false,
  });

  final bool top;
  /// Fade da lista acima do input — sem faixa 100% opaca no rodapé.
  final bool softEdge;

  @override
  Widget build(BuildContext context) {
    final bg = TaskerColors.appBackground;

    if (softEdge) {
      if (top) {
        return IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  bg.withValues(alpha: 0.48),
                  bg.withValues(alpha: 0),
                ],
                stops: const [0, 0.88],
              ),
            ),
          ),
        );
      }

      // Inferior: base mais opaca perto do magic input.
      return IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [
                bg.withValues(alpha: 0.92),
                bg.withValues(alpha: 0.35),
                bg.withValues(alpha: 0),
              ],
              stops: const [0, 0.45, 0.9],
            ),
          ),
        ),
      );
    }

    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: top ? Alignment.topCenter : Alignment.bottomCenter,
            end: top ? Alignment.bottomCenter : Alignment.topCenter,
            colors: [
              bg,
              bg.withValues(alpha: 0),
            ],
          ),
        ),
      ),
    );
  }
}
