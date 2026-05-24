import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../../../app/theme/tasker_card_style.dart';
import '../../../../app/theme/tasker_colors.dart';
import '../../../../core/layout/tasker_breakpoints.dart';
import '../../../../core/nlp/extract_errand_list_pt_br.dart';
import '../../domain/task.dart';
import '../../domain/task_icon_catalog.dart';
import '../state/task_store.dart';
import '../widgets/complete_input.dart';
import '../widgets/task_errand_list_fields.dart';
import '../widgets/task_icon_picker_section.dart';
import '../widgets/task_location_picker_map.dart';
import '../widgets/task_page_header.dart';
import '../widgets/task_section_card.dart';

enum _SubmitAction { stay, back }

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

  final _titleController = TextEditingController();
  final _descricaoController = TextEditingController();
  final List<TextEditingController> _errandItemControllers = [];

  late String _dataYmd;
  late _TaskBodyMode _bodyMode;
  TimeOfDay? _hora;
  bool _done = false;
  bool _includeLocation = false;
  String _iconKey = TaskIconCatalog.defaultIconKey;
  int _iconBackgroundArgb = TaskIconCatalog.defaultColor.backgroundArgb;

  bool _isSubmitting = false;
  _SubmitAction? _submittingAction;

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
      _titleController.text = existing.title;
      _dataYmd = existing.data.isNotEmpty ? existing.data : _defaultDateYmd();
      _hora = _parseHora(existing.hora);
      _done = existing.done;
      _includeLocation = existing.location != null;
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
  }

  void _setErrandControllers(List<String> items) {
    for (final c in _errandItemControllers) {
      c.dispose();
    }
    _errandItemControllers
      ..clear()
      ..addAll(
        (items.isEmpty ? const [''] : items)
            .map((s) => TextEditingController(text: s))
            .toList(),
      );
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
      _errandItemControllers.add(TextEditingController());
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
    _titleController.dispose();
    _descricaoController.dispose();
    for (final c in _errandItemControllers) {
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
    setState(() => _includeLocation = value);
    if (value) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _mapPickerKey.currentState?.recenterOnDevice();
        Future<void>.delayed(const Duration(milliseconds: 280), () {
          _mapPickerKey.currentState?.refreshAfterLayout();
        });
      });
    }
  }

  void _resetForm() {
    setState(() {
      _titleController.clear();
      _descricaoController.clear();
      _bodyMode = _TaskBodyMode.description;
      _setErrandControllers(const ['']);
      _dataYmd = _defaultDateYmd();
      _hora = null;
      _done = false;
      _includeLocation = false;
      _iconKey = TaskIconCatalog.defaultIconKey;
      _iconBackgroundArgb = TaskIconCatalog.defaultColor.backgroundArgb;
    });
  }

  Task _buildTask({TaskLocation? location, required bool includeLocation}) {
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
    );
  }

  Future<Task?> _saveCommon() async {
    final titulo = _titleController.text.trim();
    final horaStr = _horaToString(_hora);

    if (titulo.isEmpty || _dataYmd.isEmpty || horaStr.isEmpty) {
      if (!mounted) return null;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Campos obrigatórios'),
          content: const Text(
            'Preencha título, data e hora para continuar.',
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
      final location = _includeLocation
          ? _mapPickerKey.currentState?.selectedLocation
          : null;
      final task = _buildTask(
        location: location,
        includeLocation: _includeLocation,
      );

      final store = context.read<TaskStore>();
      if (_isEditing) {
        await store.updateTask(task);
      } else {
        await store.addTask(task);
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

  Future<void> _handleAddAndStay() async {
    if (_isEditing) return;
    setState(() {
      _isSubmitting = true;
      _submittingAction = _SubmitAction.stay;
    });
    final saved = await _saveCommon();
    if (!mounted) return;
    setState(() {
      _isSubmitting = false;
      _submittingAction = null;
    });
    if (saved != null) _resetForm();
  }

  Future<void> _handleAddAndBack() async {
    setState(() {
      _isSubmitting = true;
      _submittingAction = _SubmitAction.back;
    });
    final saved = await _saveCommon();
    if (!mounted) return;
    setState(() {
      _isSubmitting = false;
      _submittingAction = null;
    });
    if (saved != null) {
      if (_isEditing) {
        Navigator.of(context).pop(saved);
        return;
      }
      final titulo = _titleController.text.trim();
      final hora = _horaToString(_hora);
      final body = hora.isEmpty ? titulo : '$titulo - $hora';
      _leavePage(result: body);
    }
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

  @override
  Widget build(BuildContext context) {
    final allDisabled = _isSubmitting;

    return Scaffold(
      backgroundColor: TaskerColors.appBackground,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TaskPageHeaderBar(
            title: _isEditing ? 'Editar tarefa' : 'Nova tarefa',
            subtitle: _isEditing
                ? 'Altere os dados abaixo'
                : 'Preencha os dados abaixo',
            onBack: allDisabled ? null : () => _leavePage(),
          ),
          Expanded(
            child: IgnorePointer(
              ignoring: allDisabled,
              child: Opacity(
                opacity: allDisabled ? 0.65 : 1,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.maxWidth;
                    return SingleChildScrollView(
                      padding: TaskerBreakpoints.pagePadding(width),
                      child: TaskerResponsiveContent(
                        width: width,
                        child: _buildFormBody(width, allDisabled),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
          ColoredBox(
            color: Colors.white,
            child: SafeArea(
              top: false,
              child: Material(
                elevation: 8,
                shadowColor: TaskerColors.cardShadow,
                color: Colors.white,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.maxWidth;
                    return TaskerResponsiveContent(
                      width: width,
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                      child: _buildActionButtons(allDisabled, width),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormBody(double width, bool allDisabled) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildWhatSection(allDisabled),
        const SizedBox(height: TaskerCardStyle.sectionSpacing),
        _buildWhenSection(width),
        const SizedBox(height: TaskerCardStyle.sectionSpacing),
        _buildAppearanceSection(allDisabled),
        const SizedBox(height: TaskerCardStyle.sectionSpacing),
        _buildLocationSection(allDisabled),
        const SizedBox(height: TaskerCardStyle.sectionSpacing),
        _buildDoneTile(allDisabled),
      ],
    );
  }

  Widget _buildWhatSection(bool allDisabled) {
    return TaskSectionCard(
      title: 'Nome e detalhes',
      icon: Icons.edit_note_outlined,
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
          SegmentedButton<_TaskBodyMode>(
            segments: const [
              ButtonSegment(
                value: _TaskBodyMode.description,
                label: Text('Descrição'),
                icon: Icon(Icons.notes_outlined, size: 18),
              ),
              ButtonSegment(
                value: _TaskBodyMode.errandList,
                label: Text('Lista'),
                icon: Icon(Icons.checklist_outlined, size: 18),
              ),
            ],
            selected: {_bodyMode},
            onSelectionChanged: allDisabled
                ? null
                : (selection) => _setBodyMode(selection.first),
            style: ButtonStyle(
              visualDensity: VisualDensity.compact,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
          const SizedBox(height: 14),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: _bodyMode == _TaskBodyMode.description
                ? CompleteInput(
                    key: const ValueKey('description'),
                    label: 'Descrição (opcional)',
                    child: TextField(
                      controller: _descricaoController,
                      maxLines: 3,
                      decoration: TaskerFieldDecoration.decoration(
                        hintText: 'Detalhes, links, observações…',
                      ),
                      style: TaskerFieldDecoration.textStyle,
                    ),
                  )
                : CompleteInput(
                    key: const ValueKey('errand-list'),
                    label: errandListSummaryLabel,
                    child: TaskErrandListFields(
                      controllers: _errandItemControllers,
                      enabled: !allDisabled,
                      onAdd: _addErrandItem,
                      onRemove: _removeErrandItem,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppearanceSection(bool allDisabled) {
    return TaskSectionCard(
      title: 'Ícone e cor',
      icon: Icons.palette_outlined,
      child: TaskIconPickerSection(
        iconKey: _iconKey,
        backgroundArgb: _iconBackgroundArgb,
        enabled: !allDisabled,
        onIconChanged: (key) => setState(() => _iconKey = key),
        onColorChanged: (argb) => setState(() => _iconBackgroundArgb = argb),
      ),
    );
  }

  Widget _buildWhenSection(double width) {
    final stackFields = width < 400;

    final dateField = _PickerField(
      label: 'Data',
      value: _dataDisplay,
      icon: Icons.calendar_today_outlined,
      onTap: _pickDate,
    );
    final timeField = _PickerField(
      label: 'Hora',
      value: _horaToString(_hora).isEmpty
          ? 'Selecionar'
          : _horaToString(_hora),
      icon: Icons.access_time_outlined,
      muted: _hora == null,
      onTap: _pickTime,
    );

    return TaskSectionCard(
      title: 'Quando',
      icon: Icons.schedule_outlined,
      child: stackFields
          ? Column(
              children: [
                dateField,
                const SizedBox(height: 12),
                timeField,
              ],
            )
          : Row(
              children: [
                Expanded(child: dateField),
                const SizedBox(width: 12),
                Expanded(child: timeField),
              ],
            ),
    );
  }

  Widget _buildDoneTile(bool allDisabled) {
    return TaskSectionActionTile(
      icon: Icons.check_circle_outline,
      title: 'Marcar como feita',
      subtitle: 'A tarefa já foi concluída',
      active: _done,
      onTap: allDisabled ? null : () => setState(() => _done = !_done),
      trailing: Switch.adaptive(
        value: _done,
        onChanged: allDisabled ? null : (v) => setState(() => _done = v),
        activeThumbColor: Colors.white,
        activeTrackColor: TaskerColors.primary,
      ),
    );
  }

  Widget _buildLocationSection(bool allDisabled) {
    return TaskSectionCard(
      title: 'Localização',
      icon: Icons.location_on_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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
                initialLocation: _includeLocation ? _initialLocation : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(bool allDisabled, double width) {
    final isWide = TaskerBreakpoints.isWide(width);

    if (isWide && !_isEditing) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          SizedBox(
            width: 220,
            child: _TaskerOutlineButton(
              onPressed: allDisabled ? null : _handleAddAndStay,
              loading: _submittingAction == _SubmitAction.stay,
              label: 'Salvar e criar outra',
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 160,
            child: _TaskerPrimaryButton(
              onPressed: allDisabled ? null : _handleAddAndBack,
              loading: _submittingAction == _SubmitAction.back,
              label: 'Adicionar',
            ),
          ),
        ],
      );
    }

    return Row(
      children: [
        if (!_isEditing) ...[
          Expanded(
            flex: 3,
            child: _TaskerOutlineButton(
              onPressed: allDisabled ? null : _handleAddAndStay,
              loading: _submittingAction == _SubmitAction.stay,
              label: 'Salvar e criar outra',
            ),
          ),
          const SizedBox(width: 12),
        ],
        Expanded(
          flex: _isEditing ? 1 : 2,
          child: _TaskerPrimaryButton(
            onPressed: allDisabled ? null : _handleAddAndBack,
            loading: _submittingAction == _SubmitAction.back,
            label: _isEditing ? 'Salvar' : 'Adicionar',
          ),
        ),
      ],
    );
  }
}

class _PickerField extends StatelessWidget {
  const _PickerField({
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
    this.muted = false,
  });

  final String label;
  final String value;
  final IconData icon;
  final VoidCallback onTap;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    return CompleteInput(
      label: label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: InputDecorator(
            decoration: TaskerFieldDecoration.decoration(
              suffixIcon: Icon(icon, size: 20, color: TaskerColors.primary),
            ),
            child: Text(
              value,
              style: TaskerFieldDecoration.textStyle.copyWith(
                color: muted ? TaskerColors.mutedText : TaskerColors.primaryText,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TaskerPrimaryButton extends StatelessWidget {
  const _TaskerPrimaryButton({
    required this.onPressed,
    required this.loading,
    required this.label,
  });

  final VoidCallback? onPressed;
  final bool loading;
  final String label;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: TaskerColors.primary,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: loading
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
    );
  }
}

class _TaskerOutlineButton extends StatelessWidget {
  const _TaskerOutlineButton({
    required this.onPressed,
    required this.loading,
    required this.label,
  });

  final VoidCallback? onPressed;
  final bool loading;
  final String label;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: TaskerColors.primary,
        side: const BorderSide(color: TaskerColors.primary),
        minimumSize: const Size.fromHeight(48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: loading
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: TaskerColors.primary,
              ),
            )
          : Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
    );
  }
}
