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
import '../widgets/home_day_swipe_detector.dart';
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
  final GlobalKey<_HomeTaskListSectionState> _taskListSectionKey =
      GlobalKey<_HomeTaskListSectionState>();

  int _daySlideDirection = 0;
  bool _magicInputChromeActive = false;
  String? _confirmDeleteId;

  @override
  void initState() {
    super.initState();
    _selectedDay = TaskStore.dateOnly(DateTime.now());
    reloadDisplayName();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> reloadDisplayName() async {
    final name = await UserLocalService.getDisplayName();
    if (!mounted) return;
    setState(() => _displayName = name);
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

  bool get _isSelectedToday {
    final today = TaskStore.dateOnly(DateTime.now());
    return _selectedDay.year == today.year &&
        _selectedDay.month == today.month &&
        _selectedDay.day == today.day;
  }

  void _shiftSelectedDay(int delta) {
    if (delta == 0) return;
    setState(() {
      _daySlideDirection = delta > 0 ? 1 : -1;
      _selectedDay = TaskStore.dateOnly(
        _selectedDay.add(Duration(days: delta)),
      );
    });
  }

  void _goToPreviousDay() => _shiftSelectedDay(-1);

  void _goToNextDay() => _shiftSelectedDay(1);

  void _askDeleteTask(String id) {
    setState(() => _confirmDeleteId = id);
  }

  Future<void> _confirmDeleteTask() async {
    final id = _confirmDeleteId;
    if (id == null) return;

    try {
      await context.read<TaskStore>().markTaskDeleted(id);
    } catch (e, st) {
      debugPrint('HomePage._confirmDeleteTask: $e\n$st');
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
  }

  void _dismissMagicInputFocus() {
    _taskListSectionKey.currentState?.dismissMagicInputFocus();
  }

  Widget _wrapDismissMagicInputOnTap(Widget child) {
    return _DismissMagicInputOnTap(
      onDismiss: _dismissMagicInputFocus,
      child: child,
    );
  }

  Widget _wrapDaySwipe(Widget child, {bool enabled = true}) {
    return HomeDaySwipeDetector(
      enabled: enabled,
      onPreviousDay: _goToPreviousDay,
      onNextDay: _goToNextDay,
      child: child,
    );
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

  @override
  Widget build(BuildContext context) {
    final confirmTask = _confirmDeleteId == null
        ? null
        : context.read<TaskStore>().taskById(_confirmDeleteId!);

    return PopScope(
      canPop: !_magicInputChromeActive,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _dismissMagicInputFocus();
      },
      child: Stack(
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
                    child: _wrapDaySwipe(
                      _wrapDismissMagicInputOnTap(
                        TaskerResponsiveContent(
                          width: width,
                          child: UserDock(
                            displayName: _displayName,
                            selectedDate: _selectedDay,
                            onProfileTap: _openProfile,
                          ),
                        ),
                      ),
                    ),
                  ),
                  _wrapDaySwipe(
                    _wrapDismissMagicInputOnTap(
                      const SizedBox(
                        height: _kDaySelectorGap,
                        width: double.infinity,
                      ),
                    ),
                  ),
                  _wrapDaySwipe(
                    _wrapDismissMagicInputOnTap(
                      HomeDaySelector(
                        selectedDate: _selectedDay,
                        edgeFadeWidth: pagePadding.left * 1.75,
                        onDateSelected: (date) {
                          final next = TaskStore.dateOnly(date);
                          setState(() {
                            _daySlideDirection = next.isAfter(_selectedDay)
                                ? 1
                                : next.isBefore(_selectedDay)
                                    ? -1
                                    : 0;
                            _selectedDay = next;
                          });
                          _dismissMagicInputFocus();
                        },
                      ),
                    ),
                  ),
                  _wrapDaySwipe(
                    _wrapDismissMagicInputOnTap(
                      const SizedBox(
                        height: _kDaySelectorGap,
                        width: double.infinity,
                      ),
                    ),
                  ),
                  Padding(
                    padding: horizontalPad,
                    child: TaskerResponsiveContent(
                      width: width,
                      child: HomeNewTaskButton(onPressed: _openNewTask),
                    ),
                  ),
                  _wrapDaySwipe(
                    _wrapDismissMagicInputOnTap(
                      const SizedBox(
                        height: _kHomeSectionGap,
                        width: double.infinity,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: horizontalPad,
                      child: TaskerResponsiveContent(
                        width: width,
                        child: _HomeTaskListSection(
                          key: _taskListSectionKey,
                          selectedDay: _selectedDay,
                          onPreviousDay: _goToPreviousDay,
                          onNextDay: _goToNextDay,
                          onAskDeleteTask: _askDeleteTask,
                          onMagicInputChromeActiveChanged: (active) {
                            if (_magicInputChromeActive != active) {
                              setState(() => _magicInputChromeActive = active);
                            }
                          },
                          daySlideDirection: _daySlideDirection,
                          emptyStateBuilder: _emptyState,
                          wrapDaySwipe: _wrapDaySwipe,
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
              onConfirm: _confirmDeleteTask,
            ),
          ),
      ],
    ),
    );
  }
}

/// Snapshot da lista — [Selector] só reconstrói quando algo relevante muda.
class _HomeTaskListSnapshot {
  const _HomeTaskListSnapshot({
    required this.isLoading,
    required this.tasks,
    required this.totalActiveCount,
  });

  final bool isLoading;
  final List<Task> tasks;
  final int totalActiveCount;

  @override
  bool operator ==(Object other) {
    if (other is! _HomeTaskListSnapshot) return false;
    if (isLoading != other.isLoading ||
        totalActiveCount != other.totalActiveCount ||
        tasks.length != other.tasks.length) {
      return false;
    }
    for (var i = 0; i < tasks.length; i++) {
      final a = tasks[i];
      final b = other.tasks[i];
      if (a.id != b.id ||
          a.done != b.done ||
          a.title != b.title ||
          a.hora != b.hora) {
        return false;
      }
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(isLoading, totalActiveCount, tasks.length);
}

/// Lista de tarefas do dia — estado de swipe isolado do restante da home.
class _HomeDayTasksList extends StatefulWidget {
  const _HomeDayTasksList({
    required this.selectedDay,
    required this.daySlideDirection,
    required this.scrollBottomPadding,
    required this.emptyStateBuilder,
    required this.wrapDaySwipe,
    required this.onAskDeleteTask,
  });

  final DateTime selectedDay;
  final int daySlideDirection;
  final double scrollBottomPadding;
  final Widget Function(int totalActiveCount) emptyStateBuilder;
  final Widget Function(Widget child, {bool enabled}) wrapDaySwipe;
  final ValueChanged<String> onAskDeleteTask;

  @override
  State<_HomeDayTasksList> createState() => _HomeDayTasksListState();
}

class _HomeDayTasksListState extends State<_HomeDayTasksList> {
  final Map<String, bool> _completionFlash = {};
  final Map<String, Timer> _flashTimers = {};

  String? _openSwipeId;
  SwipeOpenDirection? _openSwipeDir;

  @override
  void dispose() {
    for (final t in _flashTimers.values) {
      t.cancel();
    }
    super.dispose();
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
        _closeSwipe();
        widget.onAskDeleteTask(id);
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
          debugPrint('_HomeDayTasksList.onToggleDone: $e\n$st');
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

  Widget _buildContent(_HomeTaskListSnapshot snapshot, TaskStore store) {
    final padding = EdgeInsets.only(bottom: widget.scrollBottomPadding);

    if (snapshot.isLoading) {
      return SizedBox.expand(
        child: Padding(
          padding: padding,
          child: widget.wrapDaySwipe(
            const Center(child: CircularProgressIndicator()),
          ),
        ),
      );
    }

    if (snapshot.tasks.isEmpty) {
      return SizedBox.expand(
        child: Padding(
          padding: padding,
          child: widget.wrapDaySwipe(
            widget.emptyStateBuilder(snapshot.totalActiveCount),
          ),
        ),
      );
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 240),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) {
        final offset = 0.1 * widget.daySlideDirection;
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: Offset(offset, 0),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        );
      },
      layoutBuilder: (currentChild, previousChildren) {
        return Stack(
          alignment: Alignment.topCenter,
          children: [
            ...previousChildren,
            if (currentChild != null) currentChild,
          ],
        );
      },
      child: KeyedSubtree(
        key: ValueKey(TaskStore.formatDateYmd(widget.selectedDay)),
        child: AnimatedTaskList<Task>(
          padding: padding,
          items: snapshot.tasks,
          itemId: (task) => task.id,
          itemBuilder: (context, task) => _buildSwipeableTaskCard(task, store),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = context.select<TaskStore, _HomeTaskListSnapshot>(
      (store) => _HomeTaskListSnapshot(
        isLoading: store.isLoading,
        tasks: store.tasksForDate(widget.selectedDay),
        totalActiveCount: store.totalActiveCount,
      ),
    );
    final store = context.read<TaskStore>();
    return _buildContent(snapshot, store);
  }
}

/// Lista scrollável com botão «Nova tarefa» e magic input fixos por cima.
class _HomeTaskListSection extends StatefulWidget {
  const _HomeTaskListSection({
    super.key,
    required this.selectedDay,
    required this.onPreviousDay,
    required this.onNextDay,
    required this.onAskDeleteTask,
    required this.onMagicInputChromeActiveChanged,
    required this.daySlideDirection,
    required this.emptyStateBuilder,
    required this.wrapDaySwipe,
  });

  final DateTime selectedDay;
  final VoidCallback onPreviousDay;
  final VoidCallback onNextDay;
  final ValueChanged<String> onAskDeleteTask;
  final ValueChanged<bool> onMagicInputChromeActiveChanged;
  final int daySlideDirection;
  final Widget Function(int totalActiveCount) emptyStateBuilder;
  final Widget Function(Widget child, {bool enabled}) wrapDaySwipe;

  @override
  State<_HomeTaskListSection> createState() => _HomeTaskListSectionState();
}

class _HomeTaskListSectionState extends State<_HomeTaskListSection> {
  final GlobalKey _footerKey = GlobalKey();
  final GlobalKey<MagicTaskInputState> _magicInputKey = GlobalKey();

  double _footerHeight = 0;
  final ValueNotifier<bool> _showBottomListFade = ValueNotifier(false);
  bool _magicInputActive = false;
  bool _footerPointerActive = false;

  @override
  void initState() {
    super.initState();
    _scheduleMeasureFooter();
  }

  @override
  void dispose() {
    _showBottomListFade.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _HomeTaskListSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedDay != widget.selectedDay) return;
  }

  void _scheduleMeasureFooter({int attempt = 0}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final measured = _measureFooter();
      if (!measured && attempt < 8) {
        _scheduleMeasureFooter(attempt: attempt + 1);
      }
    });
  }

  bool _measureFooter() {
    if (!mounted) return false;

    final footerBox =
        _footerKey.currentContext?.findRenderObject() as RenderBox?;

    final nextFooter =
        footerBox?.hasSize == true ? footerBox!.size.height.toDouble() : 0.0;

    if (nextFooter != _footerHeight) {
      setState(() {
        _footerHeight = nextFooter;
      });
    }

    return nextFooter > 0;
  }

  void dismissMagicInputFocus() {
    if (_footerPointerActive) return;
    final state = _magicInputKey.currentState;
    if (state?.isChromeActive ?? false) {
      state!.dismissChrome();
    }
  }

  bool _isPointerOverMagicInputFooter(Offset globalPosition) {
    final box =
        _footerKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return false;
    final local = box.globalToLocal(globalPosition);
    return local.dx >= 0 &&
        local.dy >= 0 &&
        local.dx <= box.size.width &&
        local.dy <= box.size.height;
  }

  @override
  Widget build(BuildContext context) {
    final scrollBottomPadding =
        _footerHeight + _kTaskListScrollEndInset;
    final magicInputSwipeEnabled = !_magicInputActive;
    final contentMediaQuery = MediaQuery.of(context).copyWith(
      viewInsets: EdgeInsets.zero,
    );

    return Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: MediaQuery(
              data: contentMediaQuery,
              child: Stack(
                fit: StackFit.expand,
                clipBehavior: Clip.none,
                children: [
                  _DismissMagicInputOnTap(
                    onDismiss: dismissMagicInputFocus,
                    shouldIgnorePointerAt: _isPointerOverMagicInputFooter,
                    child: _ScrollEdgeFades(
                      topFadeHeight: _kTaskListTopFadeHeight,
                      renderBottomFade: false,
                      onBottomFadeChanged: (visible) {
                        if (_showBottomListFade.value != visible) {
                          _showBottomListFade.value = visible;
                        }
                      },
                      child: _HomeDayTasksList(
                        selectedDay: widget.selectedDay,
                        daySlideDirection: widget.daySlideDirection,
                        scrollBottomPadding: scrollBottomPadding,
                        emptyStateBuilder: widget.emptyStateBuilder,
                        wrapDaySwipe: widget.wrapDaySwipe,
                        onAskDeleteTask: widget.onAskDeleteTask,
                      ),
                    ),
                  ),
                  ValueListenableBuilder<bool>(
                    valueListenable: _showBottomListFade,
                    builder: (context, showBottomListFade, _) {
                      if (!showBottomListFade) return const SizedBox.shrink();
                      return Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        height: _footerHeight + _kTaskListBottomFadeHeight,
                        child: const IgnorePointer(
                          child: _VerticalEdgeFade(top: false, softEdge: true),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Listener(
              onPointerDown: (_) => _footerPointerActive = true,
              onPointerUp: (_) => _footerPointerActive = false,
              onPointerCancel: (_) => _footerPointerActive = false,
              child: KeyedSubtree(
                key: _footerKey,
                child: _MagicInputKeyboardLift(
                  baseBottomInset: _kMagicInputBottomInset,
                  child: HomeDaySwipeDetector(
                    enabled: magicInputSwipeEnabled,
                    onPreviousDay: widget.onPreviousDay,
                    onNextDay: widget.onNextDay,
                    child: MagicTaskInput(
                      key: _magicInputKey,
                      selectedDate: widget.selectedDay,
                      placeholder: 'Digite ou fale o que você quer fazer…',
                      onCreated: () {},
                      onChromeActiveChanged: (active) {
                        if (_magicInputActive != active) {
                          setState(() => _magicInputActive = active);
                        }
                        widget.onMagicInputChromeActiveChanged(active);
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
    );
  }

}

/// Sobe só o magic input com o teclado — rebuild isolado do restante da home.
class _MagicInputKeyboardLift extends StatelessWidget {
  const _MagicInputKeyboardLift({
    required this.baseBottomInset,
    required this.child,
  });

  final double baseBottomInset;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return Padding(
      padding: EdgeInsets.only(
        bottom: mq.viewInsets.bottom + mq.padding.bottom + baseBottomInset,
      ),
      child: child,
    );
  }
}

/// Remove foco do magic input em toques curtos, sem atrapalhar arrastes.
class _DismissMagicInputOnTap extends StatefulWidget {
  const _DismissMagicInputOnTap({
    required this.onDismiss,
    required this.child,
    this.shouldIgnorePointerAt,
  });

  final VoidCallback onDismiss;
  final Widget child;
  final bool Function(Offset globalPosition)? shouldIgnorePointerAt;

  @override
  State<_DismissMagicInputOnTap> createState() =>
      _DismissMagicInputOnTapState();
}

class _DismissMagicInputOnTapState extends State<_DismissMagicInputOnTap> {
  Offset? _pointerDown;
  int? _pointerId;
  bool _skipDismiss = false;

  static const _maxTapDistance = 18;

  void _onPointerDown(PointerDownEvent event) {
    _skipDismiss =
        widget.shouldIgnorePointerAt?.call(event.position) ?? false;
    if (_skipDismiss) return;
    _pointerDown = event.position;
    _pointerId = event.pointer;
  }

  void _onPointerUp(PointerUpEvent event) {
    if (_skipDismiss) {
      _skipDismiss = false;
      return;
    }
    if (_pointerId != event.pointer || _pointerDown == null) return;
    final moved = (event.position - _pointerDown!).distance;
    _pointerDown = null;
    _pointerId = null;
    if (moved <= _maxTapDistance) {
      widget.onDismiss();
    }
  }

  void _onPointerCancel(PointerCancelEvent event) {
    _skipDismiss = false;
    if (_pointerId == event.pointer) {
      _pointerDown = null;
      _pointerId = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _onPointerDown,
      onPointerUp: _onPointerUp,
      onPointerCancel: _onPointerCancel,
      child: widget.child,
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
  final ValueNotifier<bool> _showTopFade = ValueNotifier(false);
  final ValueNotifier<bool> _showBottomFade = ValueNotifier(false);

  static const _scrollEpsilon = 0.5;

  @override
  void initState() {
    super.initState();
    _scheduleInitialSync();
  }

  @override
  void dispose() {
    _showTopFade.dispose();
    _showBottomFade.dispose();
    super.dispose();
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

    final topChanged = showTop != _showTopFade.value;
    final bottomChanged = showBottom != _showBottomFade.value;

    if (!topChanged && !bottomChanged) return;

    if (widget.renderBottomFade) {
      if (topChanged) _showTopFade.value = showTop;
      if (bottomChanged) _showBottomFade.value = showBottom;
    } else {
      if (topChanged) {
        _showTopFade.value = showTop;
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
        ValueListenableBuilder<bool>(
          valueListenable: _showTopFade,
          builder: (context, showTopFade, _) {
            if (!showTopFade) return const SizedBox.shrink();
            return Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: widget.topFadeHeight,
              child: const _VerticalEdgeFade(top: true, softEdge: true),
            );
          },
        ),
        if (widget.renderBottomFade)
          ValueListenableBuilder<bool>(
            valueListenable: _showBottomFade,
            builder: (context, showBottomFade, _) {
              if (!showBottomFade) return const SizedBox.shrink();
              return Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                height: widget.topFadeHeight,
                child: const _VerticalEdgeFade(top: false),
              );
            },
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
