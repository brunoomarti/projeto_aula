import 'dart:async';

import 'package:tasker_project/core/icons/tasker_icon.dart';
import 'package:tasker_project/core/icons/tasker_icon_glyph.dart';

import 'package:hugeicons/hugeicons.dart';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../../../app/theme/tasker_card_style.dart';
import '../../../../app/theme/tasker_colors.dart';
import '../../../../core/layout/tasker_breakpoints.dart';
import '../../../../core/services/geocode_service.dart';
import '../../../../core/widgets/tasker_sliding_segmented_control.dart';
import '../../../../core/widgets/tasker_floating_page_shell.dart';
import '../../../../core/widgets/tasker_glass_footer_bar.dart';
import 'package:tasker_nlp/tasker_nlp.dart';
import '../../domain/task.dart';
import '../../domain/task_icon_catalog.dart';
import '../state/task_store.dart';
import '../widgets/complete_input.dart';
import '../widgets/task_errand_list_fields.dart';
import '../widgets/task_icon_picker_section.dart';
import '../widgets/task_location_picker_map.dart';
import '../widgets/task_form_footer.dart';
import '../widgets/task_form_preview_card.dart';
import '../widgets/task_form_stepper.dart';
import '../widgets/task_form_step_transition.dart';
import '../widgets/task_page_header.dart';
import '../widgets/task_section_card.dart';

enum _TaskBodyMode { description, errandList }

/// Formulário de nova tarefa — equivalente a [tasker-main/src/view/tasks/novaTarefa.jsx].
class NewTaskPage extends StatefulWidget {
  const NewTaskPage({super.key, this.taskToEdit, this.initialDate});

  /// Quando informada, o formulário abre em modo edição.
  final Task? taskToEdit;

  /// Data inicial ao criar (ex.: dia selecionado na home).
  final DateTime? initialDate;

  @override
  State<NewTaskPage> createState() => _NewTaskPageState();
}

class _NewTaskPageState extends State<NewTaskPage> {
  static final _uuid = Uuid();

  static const _stepLabels = [
    'Detalhes',
    'Quando e local',
    'Aparência',
    'Revisar',
  ];

  static final _stepCount = _stepLabels.length;

  final _titleController = TextEditingController();
  final _descricaoController = TextEditingController();
  final List<TextEditingController> _errandItemControllers = [];

  late String _dataYmd;
  late _TaskBodyMode _bodyMode;
  TimeOfDay? _hora;
  bool _done = false;
  bool _includeLocation = false;
  TaskLocation? _savedLocation;
  String _iconKey = TaskIconCatalog.defaultIconKey;
  int _iconBackgroundArgb = TaskIconCatalog.defaultColor.backgroundArgb;

  bool _isSubmitting = false;
  int _currentStep = 0;
  int _stepDirection = 1;
  bool _appearanceCustomized = false;
  bool _iconSuggestedFromTitle = false;
  Timer? _titleIconSuggestionTimer;

  final _mapPickerKey = GlobalKey<TaskLocationPickerMapState>();

  bool get _isEditing => widget.taskToEdit != null;

  TaskLocation? get _initialLocation => widget.taskToEdit?.location;

  DateTime get _defaultDate =>
      TaskStore.dateOnly(widget.initialDate ?? DateTime.now());

  @override
  void initState() {
    super.initState();
    final existing = widget.taskToEdit;
    if (existing != null) {
      _appearanceCustomized = true;
      _titleController.text = existing.title;
      _dataYmd = existing.data.isNotEmpty ? existing.data : _defaultDateYmd();
      _hora = _parseHora(existing.hora);
      _done = existing.done;
      _includeLocation = existing.location != null;
      _savedLocation = existing.location;
      _iconKey = existing.iconKey ?? TaskIconCatalog.defaultIconKey;
      _iconBackgroundArgb = existing.iconBackgroundArgb ??
          TaskIconCatalog.defaultColor.backgroundArgb;

      final errandItems = parseErrandListFromDescription(existing.descricao);
      if (errandItems.isNotEmpty) {
        _bodyMode = _TaskBodyMode.errandList;
        _setErrandControllers(errandItems);
      } else {
        _bodyMode = _TaskBodyMode.description;
        _descricaoController.text = existing.descricao;
        _setErrandControllers(const ['']);
      }

      if (existing.location != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Future<void>.delayed(const Duration(milliseconds: 100), () {
            _mapPickerKey.currentState?.refreshAfterLayout();
          });
        });
      }
    } else {
      _dataYmd = _defaultDateYmd();
      _bodyMode = _TaskBodyMode.description;
      _setErrandControllers(const ['']);
    }
    _titleController.addListener(_onTitleChanged);
    _descricaoController.addListener(_refreshPreview);
  }

  void _onTitleChanged() {
    _refreshPreview();
    _scheduleTitleIconSuggestion();
  }

  void _scheduleTitleIconSuggestion() {
    if (_appearanceCustomized) return;
    _titleIconSuggestionTimer?.cancel();
    _titleIconSuggestionTimer = Timer(
      const Duration(milliseconds: 320),
      _applyTitleIconSuggestion,
    );
  }

  void _applyTitleIconSuggestion() {
    if (!mounted || _appearanceCustomized) return;

    final title = _titleController.text.trim();
    if (title.isEmpty) {
      if (_iconSuggestedFromTitle) {
        setState(() {
          _iconKey = TaskIconCatalog.defaultIconKey;
          _iconBackgroundArgb = TaskIconCatalog.defaultColor.backgroundArgb;
          _iconSuggestedFromTitle = false;
        });
      }
      return;
    }

    final inferred = inferTaskIconPTBR(title);
    final iconKey = TaskIconCatalog.optionForKey(inferred.iconKey).key;
    final backgroundArgb =
        TaskIconCatalog.presetForArgb(inferred.backgroundArgb).backgroundArgb;

    if (iconKey == _iconKey &&
        backgroundArgb == _iconBackgroundArgb &&
        _iconSuggestedFromTitle) {
      return;
    }

    setState(() {
      _iconKey = iconKey;
      _iconBackgroundArgb = backgroundArgb;
      _iconSuggestedFromTitle = true;
    });
  }

  void _refreshPreview() {
    if (mounted) setState(() {});
  }

  bool get _isLastStep => _currentStep >= _stepCount - 1;

  String get _stepSubtitle =>
      'Passo ${_currentStep + 1} de $_stepCount · ${_stepLabels[_currentStep]}';

  void _setErrandControllers(List<String> items) {
    for (final c in _errandItemControllers) {
      c.removeListener(_refreshPreview);
      c.dispose();
    }
    _errandItemControllers
      ..clear()
      ..addAll(
        (items.isEmpty ? const [''] : items)
            .map((s) => TextEditingController(text: s))
            .toList(),
      );
    for (final c in _errandItemControllers) {
      c.addListener(_refreshPreview);
    }
  }

  List<String> _errandItemTexts() =>
      _errandItemControllers.map((c) => c.text).toList();

  String _descricaoForSave() {
    if (_bodyMode == _TaskBodyMode.errandList) {
      final items = _errandItemTexts()
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
      return items.isEmpty ? '' : formatErrandDescription(items);
    }
    return _descricaoController.text;
  }

  void _addErrandItem() {
    setState(() {
      final controller = TextEditingController();
      controller.addListener(_refreshPreview);
      _errandItemControllers.add(controller);
    });
  }

  void _removeErrandItem(int index) {
    if (_errandItemControllers.length <= 1) return;
    setState(() {
      _errandItemControllers.removeAt(index).dispose();
    });
  }

  void _setBodyMode(_TaskBodyMode mode) {
    if (mode == _bodyMode) return;

    if (mode == _TaskBodyMode.errandList) {
      final parsed = parseErrandListFromDescription(_descricaoController.text);
      if (parsed.isNotEmpty) {
        _setErrandControllers(parsed);
      } else if (_descricaoController.text.trim().isNotEmpty) {
        _setErrandControllers([_descricaoController.text.trim()]);
      } else {
        _setErrandControllers(const ['']);
      }
    } else {
      final items = _errandItemTexts()
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
      if (items.isNotEmpty) {
        _descricaoController.text = formatErrandDescription(items);
      }
    }

    setState(() => _bodyMode = mode);
  }

  @override
  void dispose() {
    _titleIconSuggestionTimer?.cancel();
    _titleController.removeListener(_onTitleChanged);
    _descricaoController.removeListener(_refreshPreview);
    _titleController.dispose();
    _descricaoController.dispose();
    for (final c in _errandItemControllers) {
      c.removeListener(_refreshPreview);
      c.dispose();
    }
    super.dispose();
  }

  TimeOfDay? _parseHora(String hora) {
    final parts = hora.split(':');
    if (parts.length < 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    return TimeOfDay(hour: h, minute: m);
  }

  String _defaultDateYmd() => TaskStore.formatDateYmd(_defaultDate);

  DateTime? _parseDataYmd(String ymd) {
    final parts = ymd.split('-');
    if (parts.length != 3) return null;
    final y = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    final d = int.tryParse(parts[2]);
    if (y == null || m == null || d == null) return null;
    return DateTime(y, m, d);
  }

  String _horaToString(TimeOfDay? time) {
    if (time == null) return '';
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _pickDate() async {
    if (_isSubmitting) return;
    final initial = _parseDataYmd(_dataYmd) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      locale: const Locale('pt', 'BR'),
    );
    if (picked == null) return;
    setState(() {
      _dataYmd =
          '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
    });
  }

  Future<void> _pickTime() async {
    if (_isSubmitting) return;
    final picked = await showTimePicker(
      context: context,
      initialTime: _hora ?? TimeOfDay.now(),
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
    if (picked == null) return;
    setState(() => _hora = picked);
  }

  void _onIncludeLocationChanged(bool value) {
    setState(() {
      _includeLocation = value;
      if (!value) _savedLocation = null;
    });
    if (value) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _mapPickerKey.currentState?.recenterOnDevice();
        Future<void>.delayed(const Duration(milliseconds: 280), () {
          _mapPickerKey.currentState?.refreshAfterLayout();
        });
      });
    }
  }

  /// Localização escolhida no passo «Quando e local» (o mapa é desmontado nos passos seguintes).
  TaskLocation? get _effectiveLocation {
    if (!_includeLocation) return null;
    return _mapPickerKey.currentState?.selectedLocation ?? _savedLocation;
  }

  void _syncLocationFromPicker() {
    if (!_includeLocation) {
      _savedLocation = null;
      return;
    }
    final picked = _mapPickerKey.currentState?.selectedLocation;
    if (picked != null) {
      _savedLocation = picked;
    }
  }

  void _onPickerLocationChanged(TaskLocation? location) {
    if (!_includeLocation || location == null) return;
    setState(() => _savedLocation = location);
  }

  Task _buildTask({
    TaskLocation? location,
    required bool includeLocation,
  }) {
    final now = DateTime.now();
    final existing = widget.taskToEdit;

    return Task(
      id: existing?.id ?? _uuid.v4(),
      title: _titleController.text.trim(),
      descricao: _descricaoForSave(),
      data: _dataYmd,
      hora: _horaToString(_hora),
      done: _done,
      createdAt: existing?.createdAt ?? now,
      lastUpdated: now,
      location: includeLocation ? location : null,
      deleted: existing?.deleted ?? false,
      iconKey: _iconKey,
      iconBackgroundArgb: _iconBackgroundArgb,
      pilhaId: existing?.pilhaId,
    );
  }

  Future<Task?> _saveCommon() async {
    final titulo = _titleController.text.trim();

    if (titulo.isEmpty || _dataYmd.isEmpty) {
      if (!mounted) return null;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Campos obrigatórios'),
          content: const Text(
            'Preencha título e data para continuar.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return null;
    }

    try {
      if (_currentStep == 1) _syncLocationFromPicker();
      var location = _includeLocation ? _effectiveLocation : null;
      if (location != null) {
        location = await GeocodeService.enrichLocationIfNeeded(location);
      }
      final task = _buildTask(
        location: location,
        includeLocation: _includeLocation,
      );

      if (_isEditing) {
        await context.read<TaskStore>().updateTask(task);
      } else {
        await context.read<TaskStore>().addTask(task);
      }

      if (!mounted) return null;
      return task;
    } catch (e, st) {
      debugPrint('Erro ao registrar tarefa: $e\n$st');
      if (!mounted) return null;

      final message = e is MissingPluginException
          ? 'O armazenamento local não foi carregado.\n\n'
              'Pare o app (Ctrl+C no terminal) e rode de novo:\n'
              'flutter run\n\n'
              '(Hot reload não registra plugins novos.)'
          : 'Não foi possível registrar a tarefa. Tente novamente.';

      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Erro'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return null;
    }
  }

  Future<void> _handleSubmit() async {
    setState(() => _isSubmitting = true);
    final saved = await _saveCommon();
    if (!mounted) return;
    setState(() => _isSubmitting = false);
    if (saved == null) return;

    if (_isEditing) {
      Navigator.of(context).pop(saved);
      return;
    }
    final titulo = _titleController.text.trim();
    final hora = _horaToString(_hora);
    final body = hora.isEmpty ? titulo : '$titulo - $hora';
    _leavePage(result: body);
  }

  void _leavePage({String? result}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final navigator = Navigator.of(context);
      if (!navigator.canPop()) return;
      navigator.pop(result);
    });
  }

  String get _dataDisplay {
    final parsed = _parseDataYmd(_dataYmd);
    if (parsed == null) return _dataYmd;
    return DateFormat('dd/MM/yyyy').format(parsed);
  }

  Task _buildPreviewTask() {
    final title = _titleController.text.trim();
    final location = _includeLocation ? _effectiveLocation : null;

    return Task(
      id: 'preview',
      title: title.isEmpty ? 'Título da tarefa' : title,
      descricao: _descricaoForSave(),
      data: _dataYmd,
      hora: _horaToString(_hora),
      done: _done,
      createdAt: DateTime.now(),
      lastUpdated: DateTime.now(),
      location: location,
      iconKey: _iconKey,
      iconBackgroundArgb: _iconBackgroundArgb,
      synced: true,
    );
  }

  Future<void> _goToPreviousStep() async {
    if (_isSubmitting) return;
    if (_currentStep > 0) {
      setState(() {
        _stepDirection = -1;
        _currentStep -= 1;
      });
      return;
    }
    _leavePage();
  }

  Future<void> _goToNextStep() async {
    if (_isSubmitting) return;

    if (_currentStep == 0) {
      final titulo = _titleController.text.trim();
      if (titulo.isEmpty) {
        if (!mounted) return;
        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Título obrigatório'),
            content: const Text('Informe um título antes de continuar.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
        return;
      }
    }

    if (_currentStep < _stepCount - 1) {
      if (_currentStep == 1) _syncLocationFromPicker();
      setState(() {
        _stepDirection = 1;
        _currentStep += 1;
      });
    }
  }

  Widget _buildFooter(bool allDisabled) {
    return TaskFormStepNavFooter(
      onBack: allDisabled ? null : _goToPreviousStep,
      onNext: allDisabled
          ? null
          : (_isLastStep ? () => unawaited(_handleSubmit()) : _goToNextStep),
      showBack: _currentStep > 0,
      backEnabled: !allDisabled,
      nextEnabled: !allDisabled,
      nextLabel: _isLastStep
          ? (_isEditing ? 'Salvar' : 'Criar tarefa')
          : 'Próximo',
      nextEmphasis: _isLastStep
          ? TaskFormFooterNextEmphasis.primary
          : TaskFormFooterNextEmphasis.standard,
    );
  }

  Widget _buildStepContent(double width, bool allDisabled) {
    switch (_currentStep) {
      case 0:
        return _buildWhatSection(allDisabled);
      case 1:
        return _buildScheduleAndLocationSection(width, allDisabled);
      case 2:
        return _buildAppearanceSection(allDisabled);
      case 3:
        return _buildReviewSection();
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    final allDisabled = _isSubmitting;

    return Scaffold(
      backgroundColor: TaskerColors.appBackground,
      resizeToAvoidBottomInset: false,
      body: TaskerFloatingPageShell(
        headerReserve: TaskPageHeaderBar.reserveHeight(context),
        header: TaskPageHeaderBar(
          title: _isEditing ? 'Editar tarefa' : 'Nova tarefa',
          subtitle: _stepSubtitle,
          onBack: allDisabled ? null : () => _leavePage(),
        ),
        footer: TaskerGlassFooterBar(
          child: _buildFooter(allDisabled),
        ),
        topFadeExtension: 64,
        bottomFadeExtension: 80,
        bodyBuilder: (context, insets) {
          return IgnorePointer(
            ignoring: allDisabled,
            child: Opacity(
              opacity: allDisabled ? 0.65 : 1,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth;
                  final pagePadding = TaskerBreakpoints.pagePadding(width);
                  final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
                  return SingleChildScrollView(
                    clipBehavior: Clip.none,
                    padding: EdgeInsets.only(
                      top: insets.top,
                      bottom: insets.bottom + keyboardInset,
                    ),
                    child: _buildFormBody(
                      width,
                      allDisabled,
                      pageHorizontalPadding: pagePadding.left,
                    ),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFormBody(
    double width,
    bool allDisabled, {
    required double pageHorizontalPadding,
  }) {
    final paddedHeader = Padding(
      padding: EdgeInsets.symmetric(horizontal: pageHorizontalPadding),
      child: TaskerResponsiveContent(
        width: width,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TaskFormStepper(
              currentStep: _currentStep,
              labels: _stepLabels,
            ),
            const SizedBox(height: 16),
            TaskFormPreviewCard(task: _buildPreviewTask()),
          ],
        ),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        paddedHeader,
        const SizedBox(height: 20),
        TaskFormStepTransition(
          step: _currentStep,
          direction: _stepDirection,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: pageHorizontalPadding),
            child: TaskerResponsiveContent(
              width: width,
              child: _buildStepContent(width, allDisabled),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWhatSection(bool allDisabled) {
    return TaskSectionCard(
      title: 'Nome e detalhes',
      icon: HugeIcons.strokeRoundedNoteEdit,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CompleteInput(
            label: 'Título',
            child: TextField(
              controller: _titleController,
              textInputAction: TextInputAction.next,
              decoration: TaskerFieldDecoration.decoration(
                hintText: 'Ex.: Reunião com o time',
              ),
              style: TaskerFieldDecoration.textStyle,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Tipo de detalhe',
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: TaskerColors.secondaryText.withValues(alpha: 0.95),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          TaskerSlidingSegmentedControl<_TaskBodyMode>(
            selected: _bodyMode,
            onChanged: allDisabled
                ? null
                : (value) => _setBodyMode(value),
            segments: const [
              TaskerSegment(
                value: _TaskBodyMode.description,
                label: 'Descrição',
                icon: AppHugeIcon(icon: HugeIcons.strokeRoundedNote01, size: 17),
              ),
              TaskerSegment(
                value: _TaskBodyMode.errandList,
                label: 'Lista',
                icon: AppHugeIcon(icon: HugeIcons.strokeRoundedCheckList, size: 17),
              ),
            ],
          ),
          const SizedBox(height: 14),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: _bodyMode == _TaskBodyMode.description
                ? TextField(
                    key: const ValueKey('description'),
                    controller: _descricaoController,
                    maxLines: 3,
                    decoration: TaskerFieldDecoration.decoration(
                      hintText: 'Detalhes, links, observações…',
                    ),
                    style: TaskerFieldDecoration.textStyle,
                  )
                : TaskErrandListFields(
                    key: const ValueKey('errand-list'),
                    controllers: _errandItemControllers,
                    enabled: !allDisabled,
                    onAdd: _addErrandItem,
                    onRemove: _removeErrandItem,
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppearanceSection(bool allDisabled) {
    return TaskSectionCard(
      title: 'Ícone e cor',
      icon: HugeIcons.strokeRoundedColors,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_iconSuggestedFromTitle && !_appearanceCustomized)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                'Sugerido automaticamente a partir do título.',
                style: TextStyle(
                  fontSize: 13,
                  height: 1.35,
                  color: TaskerColors.primary.withValues(alpha: 0.88),
                ),
              ),
            ),
          TaskIconPickerSection(
            iconKey: _iconKey,
            backgroundArgb: _iconBackgroundArgb,
            enabled: !allDisabled,
            onIconChanged: (key) => setState(() {
              _iconKey = key;
              _appearanceCustomized = true;
              _iconSuggestedFromTitle = false;
            }),
            onColorChanged: (argb) => setState(() {
              _iconBackgroundArgb = argb;
              _appearanceCustomized = true;
              _iconSuggestedFromTitle = false;
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleAndLocationSection(double width, bool allDisabled) {
    final stackFields = width < 400;

    final dateField = _PickerField(
      value: _dataDisplay,
      icon: HugeIcons.strokeRoundedCalendar01,
      onTap: _pickDate,
    );
    final timeField = _PickerField(
      value: _horaToString(_hora).isEmpty
          ? 'Sem horário'
          : _horaToString(_hora),
      icon: HugeIcons.strokeRoundedClock01,
      muted: _hora == null,
      onTap: _pickTime,
      onClear: _hora != null ? () => setState(() => _hora = null) : null,
    );

    return TaskSectionCard(
      title: 'Quando e local',
      icon: HugeIcons.strokeRoundedTimeSchedule,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          stackFields
              ? Column(
                  children: [
                    dateField,
                    const SizedBox(height: 10),
                    timeField,
                  ],
                )
              : Row(
                  children: [
                    Expanded(child: dateField),
                    const SizedBox(width: 10),
                    Expanded(child: timeField),
                  ],
                ),
          const SizedBox(height: TaskerCardStyle.sectionHeaderGap),
          const Divider(height: 1, color: Color(0xFFE8EBF2)),
          const SizedBox(height: TaskerCardStyle.sectionHeaderGap),
          InkWell(
            onTap: allDisabled
                ? null
                : () => _onIncludeLocationChanged(!_includeLocation),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Adicionar localização',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: TaskerColors.primaryText,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Mapa e endereço na tarefa (opcional)',
                          style: TextStyle(
                            fontSize: 13,
                            color: TaskerColors.secondaryText.withValues(
                              alpha: 0.9,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch.adaptive(
                    value: _includeLocation,
                    onChanged: allDisabled ? null : _onIncludeLocationChanged,
                    activeThumbColor: Colors.white,
                    activeTrackColor: TaskerColors.primary,
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstCurve: Curves.easeOut,
            secondCurve: Curves.easeIn,
            sizeCurve: Curves.easeInOut,
            crossFadeState: _includeLocation
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: (_isEditing && _includeLocation)
                ? Duration.zero
                : const Duration(milliseconds: 220),
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.only(top: 16),
              child: TaskLocationPickerMap(
                key: _mapPickerKey,
                embedded: true,
                initialLocation:
                    _includeLocation ? (_savedLocation ?? _initialLocation) : null,
                onLocationChanged: _onPickerLocationChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _reviewDetailText() {
    if (_bodyMode == _TaskBodyMode.errandList) {
      final items = _errandItemTexts()
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
      if (items.isEmpty) return 'Nenhum item na lista';
      if (items.length == 1) return items.first;
      return '${items.length} itens · ${items.first}';
    }
    final text = _descricaoController.text.trim();
    return text.isEmpty ? 'Sem descrição' : text;
  }

  String _reviewLocationText() {
    if (!_includeLocation) return 'Sem localização';
    final location = _effectiveLocation;
    if (location?.name?.trim().isNotEmpty == true) {
      return location!.name!.trim();
    }
    if (location != null) {
      return 'Local definido no mapa';
    }
    return 'Localização pendente no mapa';
  }

  Widget _buildReviewSection() {
    final iconLabel = TaskIconCatalog.icons
        .firstWhere(
          (option) => option.key == _iconKey,
          orElse: () => TaskIconCatalog.icons.first,
        )
        .label;

    return TaskSectionCard(
      title: 'Detalhes da tarefa',
      icon: HugeIcons.strokeRoundedView,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ReviewDetailRow(
            label: 'Título',
            value: _titleController.text.trim().isEmpty
                ? '—'
                : _titleController.text.trim(),
          ),
          _ReviewDetailRow(label: 'Detalhes', value: _reviewDetailText()),
          _ReviewDetailRow(label: 'Data', value: _dataDisplay),
          _ReviewDetailRow(
            label: 'Hora',
            value: _horaToString(_hora).isEmpty
                ? 'Sem horário'
                : _horaToString(_hora),
          ),
          _ReviewDetailRow(label: 'Ícone', value: iconLabel),
          _ReviewDetailRow(label: 'Local', value: _reviewLocationText()),
          const SizedBox(height: 12),
          Text(
            _isEditing
                ? 'Confira os dados acima e deslize para salvar.'
                : 'Confira os dados acima e deslize para criar.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              height: 1.35,
              color: TaskerColors.secondaryText.withValues(alpha: 0.88),
            ),
          ),
        ],
      ),
    );
  }
}

class _PickerField extends StatelessWidget {
  const _PickerField({
    required this.value,
    required this.icon,
    required this.onTap,
    this.muted = false,
    this.onClear,
  });

  final String value;
  final TaskerIconGlyph icon;
  final VoidCallback onTap;
  final bool muted;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: InputDecorator(
          decoration: TaskerFieldDecoration.decoration(
            suffixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (onClear != null)
                  IconButton(
                    onPressed: onClear,
                    icon: const AppHugeIcon(
                      icon: HugeIcons.strokeRoundedCancel01,
                      size: 18,
                    ),
                    color: TaskerColors.mutedText,
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                    tooltip: 'Remover horário',
                  ),
                TaskerIcon(icon: icon, size: 20, color: TaskerColors.primary),
                const SizedBox(width: 4),
              ],
            ),
          ),
          child: Text(
            value,
            style: TaskerFieldDecoration.textStyle.copyWith(
              color: muted ? TaskerColors.mutedText : TaskerColors.primaryText,
            ),
          ),
        ),
      ),
    );
  }
}

class _ReviewDetailRow extends StatelessWidget {
  const _ReviewDetailRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 72,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: TaskerColors.secondaryText.withValues(alpha: 0.82),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                height: 1.35,
                color: TaskerColors.primaryText,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
