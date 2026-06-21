import 'dart:async';

import 'package:tasker_project/core/icons/tasker_icon.dart';

import 'package:hugeicons/hugeicons.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../../app/theme/tasker_colors.dart';
import '../../../../core/time/calendar_day_watcher.dart';
import '../../../../core/layout/tasker_breakpoints.dart';
import '../../../../core/layout/vertical_scroll_clip.dart';
import '../../../../core/performance/app_animation_warmup.dart';
import '../../../../core/widgets/tasker_vertical_edge_fade.dart';
import '../../../../core/services/connectivity_notifier.dart';
import '../../../../core/services/magic_task_builder.dart';
import '../../../auth/presentation/auth_controller.dart';
import '../../../auth/presentation/widgets/guest_mode_dialog.dart';
import '../../../gamification/presentation/state/daily_combo_controller.dart';
import '../../../profile/presentation/pages/profile_page.dart';
import '../../../tasks/tasks.dart';
import '../widgets/animated_task_list.dart';
import '../widgets/home_create_task_menu.dart';
import '../widgets/home_app_dock.dart';
import '../widgets/home_day_selector.dart';
import '../widgets/home_day_selector_drag_scope.dart';
import '../widgets/home_day_swipe_detector.dart';
import '../widgets/magic_task_ghost_card.dart';
import '../widgets/magic_task_input.dart';
import '../widgets/user_dock.dart';
import '../../../tasks/presentation/widgets/pilha_name_dialog.dart';
import '../../../tasks/presentation/widgets/task_drag_scroll_scope.dart';
import '../../../tasks/presentation/widgets/task_stack_drag.dart';

/// Fade superior na lista quando há scroll (suave).
const _kTaskListTopFadeHeight = 20.0;

/// Fade inferior — zona de transição entre tarefas e dock (altura extra acima do dock).
const _kTaskListBottomFadeHeight = 52.0;

/// Respiro no fim do scroll — acima do magic input (só dentro da lista).
const _kTaskListScrollEndInset = 12.0;

/// Recuo entre magic input e dock inferior.
const _kMagicInputDockGap = 16.0;

/// Recuo entre magic input e teclado quando aberto.
const _kMagicInputKeyboardGap = 16.0;

double _magicInputBottomFromInsets(double keyboardInset, double dockReserve) {
  return keyboardInset > 0
      ? keyboardInset + _kMagicInputKeyboardGap
      : dockReserve + _kMagicInputDockGap;
}

double _homeTaskListScrollBottomExtra({
  required bool showMagicInput,
  required double footerHeight,
  required double keyboardInset,
  required double dockReserve,
}) {
  if (showMagicInput) {
    return footerHeight +
        _magicInputBottomFromInsets(keyboardInset, dockReserve) +
        _kTaskListScrollEndInset;
  }
  return dockReserve + _kTaskListScrollEndInset;
}

/// Respiro vertical do cabeçalho (UserDock).
const _kHomeHeaderTopPadding = 24.0;
const _kHomeHeaderBottomPadding = 12.0;

/// Espaço vertical ao redor do seletor de dias (menor — sombra já tem margem interna).
const _kDaySelectorGap = 14.0;

/// Estado do card fantasma enquanto o magic input cria a tarefa.
class _PendingMagicTaskCreation {
  const _PendingMagicTaskCreation({
    required this.targetDay,
    required this.previewText,
  });

  final DateTime targetDay;
  final String previewText;
}

/// Home do Tasker: [UserDock] + lista de tarefas de hoje ([TaskStore] em memória).
class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    this.onShellChromeChanged,
  });

  /// Notifica o [HomeShellPage] quando menu/magic input mudam (dock reage).
  final VoidCallback? onShellChromeChanged;

  @override
  State<HomePage> createState() => HomePageState();
}

class HomePageState extends State<HomePage> with WidgetsBindingObserver {
  late DateTime _selectedDay;
  final GlobalKey<_HomeTaskListSectionState> _taskListSectionKey =
      GlobalKey<_HomeTaskListSectionState>();
  final GlobalKey _magicInputFooterKey = GlobalKey();
  final GlobalKey<MagicTaskInputState> _magicInputKey = GlobalKey();

  int _daySlideDirection = 0;
  bool _magicInputChromeActive = false;
  bool _createMenuOpen = false;
  bool _showMagicInput = false;
  double _magicInputFooterHeight = 0;
  bool _magicInputFooterPointerActive = false;
  bool _footerMeasurePending = false;
  String? _confirmDeleteId;
  final HomeDaySelectorDragController _daySelectorDragController =
      HomeDaySelectorDragController();
  CalendarDayWatcher? _calendarDayWatcher;
  _PendingMagicTaskCreation? _pendingMagicCreation;
  bool _magicTaskCreating = false;

  static bool _isSameCalendarDay(DateTime a, DateTime b) {
    final da = TaskStore.dateOnly(a);
    final db = TaskStore.dateOnly(b);
    return da.year == db.year && da.month == db.month && da.day == db.day;
  }

  void _onCalendarDayChanged(DateTime previousDay, DateTime newDay) {
    if (!mounted) return;

    final wasViewingToday = _isSameCalendarDay(_selectedDay, previousDay);
    unawaited(context.read<TaskStore>().refreshFromDisk());
    unawaited(context.read<DailyComboController>().evaluateNow());

    setState(() {
      if (wasViewingToday) {
        _daySlideDirection = newDay.isAfter(previousDay) ? 1 : -1;
        _selectedDay = TaskStore.dateOnly(newDay);
      }
    });
  }

  @override
  void dispose() {
    _calendarDayWatcher?.stop();
    _daySelectorDragController.detach();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _handleTaskDropOnDay(Task task, DateTime day) async {
    final store = context.read<TaskStore>();
    final targetDay = TaskStore.dateOnly(day);
    final targetYmd = TaskStore.formatDateYmd(targetDay);

    try {
      if (task.pilhaId != null && task.pilhaId!.isNotEmpty) {
        await store.removeTaskFromPilha(task.id);
      }
      final current = store.taskById(task.id) ?? task;
      await store.updateTask(current.copyWith(data: targetYmd));
      if (!mounted) return;

      setState(() {
        _daySlideDirection = targetDay.isAfter(_selectedDay)
            ? 1
            : targetDay.isBefore(_selectedDay)
                ? -1
                : 0;
        _selectedDay = targetDay;
      });
      HapticFeedback.mediumImpact();
    } catch (e, st) {
      debugPrint('_handleTaskDropOnDay: $e\n$st');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Não foi possível mover a tarefa para este dia.'),
        ),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _selectedDay = TaskStore.dateOnly(DateTime.now());
    WidgetsBinding.instance.addObserver(this);
    _calendarDayWatcher = CalendarDayWatcher(
      onDayChanged: _onCalendarDayChanged,
    )..start();
    _scheduleMeasureMagicInputFooter();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // Ao voltar ao primeiro plano, relê do disco — captura tarefas criadas
    // pelo widget da home em background (isolate separado).
    if (state == AppLifecycleState.resumed && mounted) {
      context.read<TaskStore>().refreshFromDisk();
      _calendarDayWatcher?.checkNow();
    }
  }

  Future<void> _openProfile() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (context) => const ProfilePage(),
      ),
    );
    if (!mounted) return;
    await context.read<AuthController>().reloadProfile();
  }

  Future<void> _openNewTask() async {
    _closeCreateMenu();
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

  void _toggleCreateMenu() {
    if (_showMagicInput) return;
    setState(() => _createMenuOpen = !_createMenuOpen);
    widget.onShellChromeChanged?.call();
  }

  void _closeCreateMenu() {
    if (!_createMenuOpen) return;
    setState(() => _createMenuOpen = false);
    widget.onShellChromeChanged?.call();
  }

  void _notifyShellChrome() => widget.onShellChromeChanged?.call();

  bool get isCreateMenuOpen => _createMenuOpen;

  bool get canPopShell =>
      !_magicInputChromeActive && !_createMenuOpen && !_showMagicInput;

  void closeShellOverlays() {
    var changed = false;
    if (_createMenuOpen) {
      _createMenuOpen = false;
      changed = true;
    }
    if (_showMagicInput || _magicInputChromeActive) {
      _closeMagicInput();
      changed = true;
    }
    if (changed) setState(() {});
    _notifyShellChrome();
  }

  void toggleCreateMenuFromShell() => _toggleCreateMenu();

  void openCreateMenuFromShell() {
    if (_showMagicInput || _createMenuOpen) return;
    setState(() => _createMenuOpen = true);
    widget.onShellChromeChanged?.call();
  }

  bool handleSystemBack() {
    if (_magicInputChromeActive || _showMagicInput) {
      _closeMagicInput();
      _notifyShellChrome();
      return true;
    }
    if (_createMenuOpen) {
      _closeCreateMenu();
      return true;
    }
    return false;
  }

  void _openMagicInput() {
    final auth = context.read<AuthController>();
    if (!auth.isAuthenticated) {
      _closeCreateMenu();
      unawaited(showGuestFeatureBlockedDialog(context));
      return;
    }
    _closeCreateMenu();
    setState(() => _showMagicInput = true);
    _notifyShellChrome();
    _scheduleMeasureMagicInputFooter();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _magicInputKey.currentState?.requestInputFocus();
      _scheduleMeasureMagicInputFooter();
    });
  }

  void _closeMagicInput() {
    if (_magicTaskCreating) return;

    final state = _magicInputKey.currentState;
    if (state?.isChromeActive ?? false) {
      state!.dismissChrome();
    }
    if (_showMagicInput || _magicInputChromeActive) {
      setState(() {
        _showMagicInput = false;
        _magicInputChromeActive = false;
      });
      _notifyShellChrome();
    }
    _scheduleMeasureMagicInputFooter();
  }

  void _onMagicInputChromeActiveChanged(bool active) {
    if (_magicInputChromeActive != active) {
      setState(() => _magicInputChromeActive = active);
      _notifyShellChrome();
    }
    // Não fecha o overlay só porque o teclado perdeu foco — evita desmontar
    // o MagicTaskInput no meio da criação (Android fecha IME antes do submit).
  }

  static DateTime _parseYmd(String ymd) {
    final parts = ymd.split('-');
    return DateTime(
      int.parse(parts[0]),
      int.parse(parts[1]),
      int.parse(parts[2]),
    );
  }

  void _onMagicTaskSubmit(String text, {bool viaVoice = false}) {
    if (_magicTaskCreating) return;

    debugPrint('MagicTask: submit iniciado — "$text" (voz=$viaVoice)');

    final targetDay = TaskStore.dateOnly(_selectedDay);
    SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
    setState(() {
      _magicTaskCreating = true;
      _showMagicInput = false;
      _magicInputChromeActive = false;
      _pendingMagicCreation = _PendingMagicTaskCreation(
        targetDay: targetDay,
        previewText: text,
      );
    });
    _scheduleMeasureMagicInputFooter();
    unawaited(_executeMagicTaskCreate(text, targetDay, viaVoice: viaVoice));
  }

  Future<void> _executeMagicTaskCreate(
    String text,
    DateTime targetDay, {
    bool viaVoice = false,
  }) async {
    var success = false;
    try {
      debugPrint('MagicTask: interpretando texto…');
      final task = await MagicTaskBuilder.buildFromText(
        text: text,
        referenceDate: targetDay,
      );
      if (!mounted) return;

      debugPrint(
        'MagicTask: salvando "${task.title}" em ${task.data.isEmpty ? "hoje" : task.data}',
      );
      await context.read<TaskStore>().addTask(
        task.copyWith(
          createdViaMagic: true,
          createdViaVoice: viaVoice,
        ),
      );
      if (!mounted) return;

      success = true;
      debugPrint('MagicTask: tarefa criada id=${task.id}');

      final taskDayYmd = task.data.isEmpty
          ? TaskStore.formatDateYmd(DateTime.now())
          : task.data;
      final taskDay = TaskStore.dateOnly(_parseYmd(taskDayYmd));

      if (!_isSameCalendarDay(taskDay, _selectedDay)) {
        setState(() {
          _daySlideDirection = taskDay.isAfter(_selectedDay)
              ? 1
              : taskDay.isBefore(_selectedDay)
                  ? -1
                  : 0;
          _selectedDay = taskDay;
        });
      }
    } catch (e, st) {
      debugPrint('HomePage._executeMagicTaskCreate: $e\n$st');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Não foi possível criar a tarefa: $e')),
        );
      }
    } finally {
      if (mounted) {
        _magicInputKey.currentState?.onExternalCreationFinished(
          success: success,
        );
        setState(() {
          _magicTaskCreating = false;
          _pendingMagicCreation = null;
        });
        _scheduleMeasureMagicInputFooter();
      }
    }
  }

  void _scheduleMeasureMagicInputFooter({int attempt = 0}) {
    if (attempt == 0) {
      if (_footerMeasurePending) return;
      _footerMeasurePending = true;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (attempt == 0) _footerMeasurePending = false;
      if (!mounted) return;
      final box =
          _magicInputFooterKey.currentContext?.findRenderObject() as RenderBox?;
      final next =
          box?.hasSize == true ? box!.size.height.toDouble() : 0.0;
      if ((next - _magicInputFooterHeight).abs() > 0.5) {
        setState(() => _magicInputFooterHeight = next);
      }
      if (_showMagicInput && next <= 0 && attempt < 8) {
        _scheduleMeasureMagicInputFooter(attempt: attempt + 1);
      }
    });
  }

  bool _isPointerOverMagicInputFooter(Offset globalPosition) {
    final box =
        _magicInputFooterKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return false;
    final local = box.globalToLocal(globalPosition);
    return local.dx >= 0 &&
        local.dy >= 0 &&
        local.dx <= box.size.width &&
        local.dy <= box.size.height;
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
    if (_createMenuOpen) {
      _closeCreateMenu();
      return;
    }
    if (_magicInputFooterPointerActive) return;
    _closeMagicInput();
  }

  Widget _wrapDismissMagicInputOnTap(Widget child) {
    return _DismissMagicInputOnTap(
      onDismiss: _dismissMagicInputFocus,
      shouldIgnorePointerAt: _isPointerOverMagicInputFooter,
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

    return LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final pagePadding = TaskerBreakpoints.pagePadding(width);
          final dockReserve = HomeAppDock.reservedHeight(context);

          return Stack(
            clipBehavior: Clip.none,
            children: [
              SafeArea(
                bottom: false,
                child: HomeDaySelectorDragScope(
                  controller: _daySelectorDragController,
                  child: Column(
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
                              displayName:
                                  context.watch<AuthController>().displayName,
                              avatarUrl:
                                  context.watch<AuthController>().avatarUrl,
                              selectedDate: _selectedDay,
                              onProfileTap: _openProfile,
                              dailyComboStreak: context
                                  .watch<DailyComboController>()
                                  .currentStreak,
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
                          dragController: _daySelectorDragController,
                          onTaskDroppedOnDay: _handleTaskDropOnDay,
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
                    Expanded(
                      child: _HomeListKeyboardInset(
                        showMagicInput: _showMagicInput,
                        footerHeight: _magicInputFooterHeight,
                        dockReserve: dockReserve,
                        builder: (scrollBottomExtra) => VerticalScrollClip(
                          child: Stack(
                            fit: StackFit.expand,
                            clipBehavior: Clip.none,
                            children: [
                              Padding(
                                padding: EdgeInsets.fromLTRB(
                                  pagePadding.left,
                                  0,
                                  pagePadding.right,
                                  0,
                                ),
                                child: TaskerResponsiveContent(
                                  width: width,
                                  child: _HomeTaskListSection(
                                    key: _taskListSectionKey,
                                    selectedDay: _selectedDay,
                                    pendingMagicCreation: _pendingMagicCreation,
                                    onAskDeleteTask: _askDeleteTask,
                                    daySlideDirection: _daySlideDirection,
                                    emptyStateBuilder: _emptyState,
                                    wrapDaySwipe: _wrapDaySwipe,
                                    scrollBottomExtra: scrollBottomExtra,
                                    onDismissMagicInput: _dismissMagicInputFocus,
                                    isPointerOverMagicInputFooter:
                                        _isPointerOverMagicInputFooter,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                ),
              ),
              Positioned.fill(
                child: CreateMenuScrim(
                  visible: _showMagicInput,
                  onTap: _closeMagicInput,
                ),
              ),
              if (_showMagicInput)
                _MagicInputFooterLayer(
                  footerKey: _magicInputFooterKey,
                  dockReserve: dockReserve,
                  pagePadding: pagePadding,
                  width: width,
                  magicInputChromeActive: _magicInputChromeActive,
                  selectedDay: _selectedDay,
                  magicInputKey: _magicInputKey,
                  isCreating: _magicTaskCreating,
                  onCreateTask: _onMagicTaskSubmit,
                  onChromeActiveChanged: _onMagicInputChromeActiveChanged,
                  onPreviousDay: _goToPreviousDay,
                  onNextDay: _goToNextDay,
                  onMeasureFooter: _scheduleMeasureMagicInputFooter,
                  onPointerDown: () => _magicInputFooterPointerActive = true,
                  onPointerUp: () => _magicInputFooterPointerActive = false,
                  onPointerCancel: () =>
                      _magicInputFooterPointerActive = false,
                ),
              Positioned.fill(
                child: CreateMenuScrim(
                  visible: _createMenuOpen,
                  onTap: _closeCreateMenu,
                ),
              ),
              Positioned(
                left: pagePadding.left,
                right: pagePadding.right,
                bottom: dockReserve + HomeCreateTaskMenu.dockGap,
                child: TaskerResponsiveContent(
                  width: width,
                  child: HomeCreateTaskMenu(
                    visible: _createMenuOpen,
                    magicInputEnabled:
                        context.watch<AuthController>().isAuthenticated,
                    onMagicTap: _openMagicInput,
                    onManualTap: _openNewTask,
                  ),
                ),
              ),
              _MagicInputBottomFadeLayer(
                showMagicInput: _showMagicInput,
                footerHeight: _magicInputFooterHeight,
                dockReserve: dockReserve,
              ),
              Positioned.fill(
                child: ConfirmDeleteDialog(
                  open: _confirmDeleteId != null,
                  taskTitle: confirmTask?.title,
                  onCancel: () => setState(() => _confirmDeleteId = null),
                  onConfirm: _confirmDeleteTask,
                ),
              ),
              const Positioned(
                left: 0,
                top: 0,
                child: HomeRuntimeWarmup(),
              ),
            ],
          );
        },
      );
  }
}

/// Snapshot da lista — [Selector] só reconstrói quando algo relevante muda.
class _HomeTaskListSnapshot {
  const _HomeTaskListSnapshot({
    required this.isLoading,
    required this.isSyncing,
    required this.entries,
    required this.totalActiveCount,
  });

  final bool isLoading;
  final bool isSyncing;
  final List<HomeListEntry> entries;
  final int totalActiveCount;

  /// Mostra loading enquanto carrega o cache ou na 1ª sincronização sem dados.
  bool get showLoading => isLoading || (isSyncing && entries.isEmpty);

  @override
  bool operator ==(Object other) {
    if (other is! _HomeTaskListSnapshot) return false;
    if (isLoading != other.isLoading ||
        isSyncing != other.isSyncing ||
        totalActiveCount != other.totalActiveCount ||
        entries.length != other.entries.length) {
      return false;
    }
    for (var i = 0; i < entries.length; i++) {
      if (!_entryEquals(entries[i], other.entries[i])) return false;
    }
    return true;
  }

  static bool _entryEquals(HomeListEntry a, HomeListEntry b) {
    if (a is HomeSingleTaskEntry && b is HomeSingleTaskEntry) {
      return a.task.id == b.task.id &&
          a.task.done == b.task.done &&
          a.task.title == b.task.title &&
          a.task.hora == b.task.hora &&
          a.task.pilhaId == b.task.pilhaId;
    }
    if (a is HomePilhaEntry && b is HomePilhaEntry) {
      return a.pilha.id == b.pilha.id &&
          a.tasks.length == b.tasks.length &&
          _tasksSignature(a.tasks) == _tasksSignature(b.tasks);
    }
    return false;
  }

  static String _tasksSignature(List<Task> tasks) {
    return tasks
        .map((t) => '${t.id}:${t.done}:${t.title}:${t.hora}')
        .join('|');
  }

  @override
  int get hashCode =>
      Object.hash(isLoading, isSyncing, totalActiveCount, entries.length);
}

/// Lista de tarefas do dia — estado de swipe isolado do restante da home.
class _HomeDayTasksList extends StatefulWidget {
  const _HomeDayTasksList({
    required this.selectedDay,
    required this.pendingMagicCreation,
    required this.daySlideDirection,
    required this.scrollBottomPadding,
    required this.emptyStateBuilder,
    required this.wrapDaySwipe,
    required this.onAskDeleteTask,
  });

  final DateTime selectedDay;
  final _PendingMagicTaskCreation? pendingMagicCreation;
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
  final Set<String> _expandedPilhaIds = {};
  final ScrollController _listScrollController = ScrollController();
  final GlobalKey _listViewportKey = GlobalKey();

  String? _openSwipeId;
  SwipeOpenDirection? _openSwipeDir;
  String? _draggingTaskId;
  Task? _draggingTask;

  @override
  void dispose() {
    for (final t in _flashTimers.values) {
      t.cancel();
    }
    _listScrollController.dispose();
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

  void _togglePilhaExpanded(String pilhaId) {
    setState(() {
      if (_expandedPilhaIds.contains(pilhaId)) {
        _expandedPilhaIds.remove(pilhaId);
      } else {
        _expandedPilhaIds.add(pilhaId);
        _closeSwipe();
      }
    });
  }

  bool _taskHasValidPilha(Task task, TaskStore store) {
    final pilhaId = task.pilhaId;
    return pilhaId != null && pilhaId.isNotEmpty && store.pilhaById(pilhaId) != null;
  }

  bool _canAcceptStackDrop({
    required Task dragged,
    Task? targetTask,
    String? targetPilhaId,
    List<Task>? pilhaTasks,
  }) {
    if (targetTask != null) {
      if (dragged.id == targetTask.id) return false;
      if (_taskHasValidPilha(targetTask, context.read<TaskStore>())) {
        return false;
      }
      return true;
    }

    if (targetPilhaId != null && pilhaTasks != null) {
      if (pilhaTasks.any((t) => t.id == dragged.id)) return false;
      if (dragged.pilhaId == targetPilhaId) return false;
      return true;
    }

    return false;
  }

  Future<void> _handleDropOnTask(Task dragged, Task target) async {
    if (dragged.id == target.id) return;
    _closeSwipe();

    final name = await showPilhaNameDialog(context);
    if (!mounted || name == null) return;

    try {
      final store = context.read<TaskStore>();
      final pilha = await store.createPilhaWithTasks(
        name: name,
        taskIds: [dragged.id, target.id],
      );
      if (!mounted) return;
      setState(() => _expandedPilhaIds.add(pilha.id));
      HapticFeedback.lightImpact();
    } catch (e, st) {
      debugPrint('_handleDropOnTask: $e\n$st');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Não foi possível criar a pilha.'),
        ),
      );
    }
  }

  Future<void> _handleDropOnPilha(Task dragged, Pilha pilha) async {
    _closeSwipe();

    try {
      await context.read<TaskStore>().assignTaskToPilha(dragged.id, pilha.id);
      if (!mounted) return;
      setState(() => _expandedPilhaIds.add(pilha.id));
      HapticFeedback.lightImpact();
    } catch (e, st) {
      debugPrint('_handleDropOnPilha: $e\n$st');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Não foi possível adicionar à pilha.'),
        ),
      );
    }
  }

  Future<void> _handleExtractFromPilha(Task dragged) async {
    _closeSwipe();
    _onTaskDragEnded();

    try {
      final store = context.read<TaskStore>();
      final pilhaId = dragged.pilhaId;
      await store.removeTaskFromPilha(dragged.id);
      if (!mounted) return;
      if (pilhaId != null) {
        setState(() => _expandedPilhaIds.remove(pilhaId));
      }
      HapticFeedback.lightImpact();
    } catch (e, st) {
      debugPrint('_handleExtractFromPilha: $e\n$st');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Não foi possível remover da pilha.'),
        ),
      );
    }
  }

  bool _canExtractFromPilha(TaskDragData data) {
    return _taskHasValidPilha(data.task, context.read<TaskStore>());
  }

  void _onTaskDragStarted(String taskId) {
    _closeSwipe();
    final task = context.read<TaskStore>().taskById(taskId);
    _draggingTaskId = taskId;
    _draggingTask = task;
    // Adia rebuild (faixas de extração da pilha) para não cancelar o arrasto.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _draggingTaskId != taskId) return;
      setState(() {});
    });
  }

  void _onTaskDragEnded() {
    if (_draggingTaskId == null && _draggingTask == null) return;
    setState(() {
      _draggingTaskId = null;
      _draggingTask = null;
    });
  }

  String _entryKey(HomeListEntry entry) => switch (entry) {
        HomeSingleTaskEntry(:final task) => task.id,
        HomePilhaEntry(:final pilha) => 'pilha_${pilha.id}',
      };

  Widget _buildListEntry(HomeListEntry entry, TaskStore store) {
    return switch (entry) {
      HomeSingleTaskEntry(:final task) => _buildStackableTaskCard(
          task,
          store,
          enableDropTarget: true,
        ),
      HomePilhaEntry(:final pilha, :final tasks) => PilhaStackCard(
          pilha: pilha,
          tasks: tasks,
          expanded: _expandedPilhaIds.contains(pilha.id),
          onToggleExpanded: () => _togglePilhaExpanded(pilha.id),
          canAcceptTask: (dragged) => _canAcceptStackDrop(
            dragged: dragged,
            targetPilhaId: pilha.id,
            pilhaTasks: tasks,
          ),
          onTaskDropped: (dragged) => _handleDropOnPilha(dragged, pilha),
          taskCardBuilder: (task) => _buildStackableTaskCard(
            task,
            store,
            enableDropTarget: false,
          ),
        ),
    };
  }

  Widget _buildStackableTaskCard(
    Task task,
    TaskStore store, {
    required bool enableDropTarget,
  }) {
    final card = _buildSwipeableTaskCard(task, store);

    final draggable = TaskDragWrapper(
      task: task,
      onDragStarted: () => _onTaskDragStarted(task.id),
      onDragEnded: _onTaskDragEnded,
      child: card,
    );

    if (!enableDropTarget) return draggable;

    return TaskStackDropTarget(
      canAccept: (data) => _canAcceptStackDrop(
        dragged: data.task,
        targetTask: task,
      ),
      onAccept: (data) => _handleDropOnTask(data.task, task),
      child: draggable,
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

  Widget? _buildGhostCardHeader() {
    final pending = widget.pendingMagicCreation;
    if (pending == null) return null;
    if (!HomePageState._isSameCalendarDay(
      pending.targetDay,
      widget.selectedDay,
    )) {
      return null;
    }
    return MagicTaskGhostCard(
      targetDay: pending.targetDay,
      previewText: pending.previewText,
    );
  }

  Widget _buildContent(_HomeTaskListSnapshot snapshot, TaskStore store) {
    final padding = EdgeInsets.only(bottom: widget.scrollBottomPadding);
    final ghost = _buildGhostCardHeader();

    if (snapshot.showLoading) {
      return SizedBox.expand(
        child: Padding(
          padding: padding,
          child: widget.wrapDaySwipe(
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (ghost != null) ...[ghost, const SizedBox(height: 12)],
                const Expanded(child: _HomeTasksLoading()),
              ],
            ),
          ),
        ),
      );
    }

    if (snapshot.entries.isEmpty) {
      return SizedBox.expand(
        child: Padding(
          padding: padding,
          child: widget.wrapDaySwipe(
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (ghost != null) ...[ghost, const SizedBox(height: 12)],
                Expanded(
                  child: ghost == null
                      ? widget.emptyStateBuilder(snapshot.totalActiveCount)
                      : Align(
                          alignment: Alignment.topCenter,
                          child: Text(
                            'Interpretando sua tarefa…',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: TaskerColors.secondaryText
                                  .withValues(alpha: 0.85),
                            ),
                          ),
                        ),
                ),
              ],
            ),
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
        child: TaskDragScrollScope(
          scrollController: _listScrollController,
          viewportKey: _listViewportKey,
          child: SizedBox.expand(
            key: _listViewportKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (ghost != null) ...[ghost, const SizedBox(height: 12)],
                Expanded(
                  child: AnimatedTaskList<HomeListEntry>(
                    scrollController: _listScrollController,
                    padding: padding,
                    animationDuration: const Duration(milliseconds: 420),
                    showExtractSlots: _draggingTask != null &&
                        _taskHasValidPilha(_draggingTask!, store),
                    canAcceptExtract: _canExtractFromPilha,
                    onExtractDrop: (data) => _handleExtractFromPilha(data.task),
                    items: snapshot.entries,
                    itemId: _entryKey,
                    itemBuilder: (context, entry) =>
                        _buildListEntry(entry, store),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = context.select<TaskStore, _HomeTaskListSnapshot>(
      (store) => _HomeTaskListSnapshot(
        isLoading: store.isLoading,
        isSyncing: store.isSyncing,
        entries: store.entriesForDate(widget.selectedDay),
        totalActiveCount: store.totalActiveCount,
      ),
    );
    final store = context.read<TaskStore>();
    return _buildContent(snapshot, store);
  }
}

/// Tag vermelha fixa acima do magic input — só aparece quando offline.
class _OfflineBanner extends StatefulWidget {
  const _OfflineBanner({this.onVisibilityChanged});

  /// Chamado quando a visibilidade muda (para remedir a altura do rodapé).
  final VoidCallback? onVisibilityChanged;

  @override
  State<_OfflineBanner> createState() => _OfflineBannerState();
}

class _OfflineBannerState extends State<_OfflineBanner> {
  bool? _wasOffline;

  @override
  Widget build(BuildContext context) {
    final online =
        context.select<ConnectivityNotifier, bool>((n) => n.isOnline);
    final offline = !online;

    if (_wasOffline != offline) {
      _wasOffline = offline;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.onVisibilityChanged?.call();
      });
    }

    return AnimatedSize(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      alignment: Alignment.bottomCenter,
      child: offline ? const _OfflineBannerBar() : const SizedBox(width: double.infinity),
    );
  }
}

class _OfflineBannerBar extends StatelessWidget {
  const _OfflineBannerBar();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: TaskerColors.warning,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.max,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AppHugeIcon(icon: HugeIcons.strokeRoundedCloudLoading, color: Colors.white, size: 18),
          SizedBox(width: 8),
          Flexible(
            child: Text(
              'Você está offline. As alterações serão sincronizadas depois.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                height: 1.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Indicador de carregamento das tarefas na home.
class _HomeTasksLoading extends StatelessWidget {
  const _HomeTasksLoading();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(
            'Carregando suas tarefas…',
            style: TextStyle(
              color: TaskerColors.secondaryText.withValues(alpha: 0.9),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

/// Lista scrollável de tarefas do dia selecionado.
class _HomeListKeyboardInset extends StatelessWidget {
  const _HomeListKeyboardInset({
    required this.showMagicInput,
    required this.footerHeight,
    required this.dockReserve,
    required this.builder,
  });

  final bool showMagicInput;
  final double footerHeight;
  final double dockReserve;
  final Widget Function(double scrollBottomExtra) builder;

  @override
  Widget build(BuildContext context) {
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    final scrollBottomExtra = _homeTaskListScrollBottomExtra(
      showMagicInput: showMagicInput,
      footerHeight: footerHeight,
      keyboardInset: keyboardInset,
      dockReserve: dockReserve,
    );
    return builder(scrollBottomExtra);
  }
}

/// Footer do magic input — posição isolada do `viewInsets` do teclado.
class _MagicInputFooterLayer extends StatelessWidget {
  const _MagicInputFooterLayer({
    required this.footerKey,
    required this.dockReserve,
    required this.pagePadding,
    required this.width,
    required this.magicInputChromeActive,
    required this.selectedDay,
    required this.magicInputKey,
    required this.isCreating,
    required this.onCreateTask,
    required this.onChromeActiveChanged,
    required this.onPreviousDay,
    required this.onNextDay,
    required this.onMeasureFooter,
    required this.onPointerDown,
    required this.onPointerUp,
    required this.onPointerCancel,
  });

  final Key footerKey;
  final double dockReserve;
  final EdgeInsets pagePadding;
  final double width;
  final bool magicInputChromeActive;
  final DateTime selectedDay;
  final GlobalKey<MagicTaskInputState> magicInputKey;
  final bool isCreating;
  final void Function(String text, {bool viaVoice}) onCreateTask;
  final ValueChanged<bool> onChromeActiveChanged;
  final VoidCallback onPreviousDay;
  final VoidCallback onNextDay;
  final VoidCallback onMeasureFooter;
  final VoidCallback onPointerDown;
  final VoidCallback onPointerUp;
  final VoidCallback onPointerCancel;

  @override
  Widget build(BuildContext context) {
    final bottom = _magicInputBottomFromInsets(
      MediaQuery.viewInsetsOf(context).bottom,
      dockReserve,
    );

    return Positioned(
      left: 0,
      right: 0,
      bottom: bottom,
      child: Listener(
        onPointerDown: (_) => onPointerDown(),
        onPointerUp: (_) => onPointerUp(),
        onPointerCancel: (_) => onPointerCancel(),
        child: KeyedSubtree(
          key: footerKey,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              pagePadding.left,
              0,
              pagePadding.right,
              0,
            ),
            child: TaskerResponsiveContent(
              width: width,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _OfflineBanner(onVisibilityChanged: onMeasureFooter),
                  HomeDaySwipeDetector(
                    enabled: !magicInputChromeActive,
                    onPreviousDay: onPreviousDay,
                    onNextDay: onNextDay,
                    child: MagicTaskInput(
                      key: magicInputKey,
                      selectedDate: selectedDay,
                      isCreating: isCreating,
                      placeholder: 'Nova tarefa — digite ou fale…',
                      onCreateTask: onCreateTask,
                      onCreated: () {},
                      onChromeActiveChanged: onChromeActiveChanged,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Fade inferior acompanha magic input + teclado sem rebuildar a home inteira.
class _MagicInputBottomFadeLayer extends StatelessWidget {
  const _MagicInputBottomFadeLayer({
    required this.showMagicInput,
    required this.footerHeight,
    required this.dockReserve,
  });

  final bool showMagicInput;
  final double footerHeight;
  final double dockReserve;

  @override
  Widget build(BuildContext context) {
    final magicInputBottom = _magicInputBottomFromInsets(
      MediaQuery.viewInsetsOf(context).bottom,
      dockReserve,
    );
    final height = showMagicInput
        ? magicInputBottom + footerHeight + _kTaskListBottomFadeHeight
        : dockReserve + _kTaskListBottomFadeHeight;

    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      height: height,
      child: const IgnorePointer(
        child: TaskerVerticalEdgeFade(top: false, softEdge: true),
      ),
    );
  }
}

class _HomeTaskListSection extends StatefulWidget {
  const _HomeTaskListSection({
    super.key,
    required this.selectedDay,
    required this.pendingMagicCreation,
    required this.onAskDeleteTask,
    required this.daySlideDirection,
    required this.emptyStateBuilder,
    required this.wrapDaySwipe,
    required this.scrollBottomExtra,
    required this.onDismissMagicInput,
    required this.isPointerOverMagicInputFooter,
  });

  final DateTime selectedDay;
  final _PendingMagicTaskCreation? pendingMagicCreation;
  final ValueChanged<String> onAskDeleteTask;
  final int daySlideDirection;
  final Widget Function(int totalActiveCount) emptyStateBuilder;
  final Widget Function(Widget child, {bool enabled}) wrapDaySwipe;
  final double scrollBottomExtra;
  final VoidCallback onDismissMagicInput;
  final bool Function(Offset globalPosition) isPointerOverMagicInputFooter;

  @override
  State<_HomeTaskListSection> createState() => _HomeTaskListSectionState();
}

class _HomeTaskListSectionState extends State<_HomeTaskListSection> {
  @override
  Widget build(BuildContext context) {
    final contentMediaQuery = MediaQuery.of(context).copyWith(
      viewInsets: EdgeInsets.zero,
    );

    return MediaQuery(
      data: contentMediaQuery,
      child: Stack(
        fit: StackFit.expand,
        clipBehavior: Clip.none,
        children: [
            _DismissMagicInputOnTap(
              onDismiss: widget.onDismissMagicInput,
              shouldIgnorePointerAt: widget.isPointerOverMagicInputFooter,
              child: _ScrollEdgeFades(
                topFadeHeight: _kTaskListTopFadeHeight,
                renderBottomFade: false,
                child: _HomeDayTasksList(
                  selectedDay: widget.selectedDay,
                  pendingMagicCreation: widget.pendingMagicCreation,
                  daySlideDirection: widget.daySlideDirection,
                  scrollBottomPadding: widget.scrollBottomExtra,
                  emptyStateBuilder: widget.emptyStateBuilder,
                  wrapDaySwipe: widget.wrapDaySwipe,
                  onAskDeleteTask: widget.onAskDeleteTask,
                ),
              ),
            ),
        ],
      ),
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
  });

  final double topFadeHeight;
  final Widget child;
  final bool renderBottomFade;

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
    } else if (topChanged) {
      _showTopFade.value = showTop;
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
              child: const TaskerVerticalEdgeFade(top: true, softEdge: true),
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
                child: const TaskerVerticalEdgeFade(top: false),
              );
            },
          ),
      ],
    );
  }
}
