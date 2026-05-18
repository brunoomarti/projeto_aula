import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../../../app/theme/tasker_colors.dart';
import '../../../../core/services/location_service.dart';
import '../../data/task_local_repository.dart';
import '../../domain/task.dart';
import '../widgets/complete_input.dart';

enum _SubmitAction { stay, back }

/// Formulário de nova tarefa — equivalente a [tasker-main/src/view/tasks/novaTarefa.jsx].
class NewTaskPage extends StatefulWidget {
  const NewTaskPage({super.key});

  @override
  State<NewTaskPage> createState() => _NewTaskPageState();
}

class _NewTaskPageState extends State<NewTaskPage> {
  static final _uuid = Uuid();

  final _titleController = TextEditingController();
  final _descricaoController = TextEditingController();

  late String _dataYmd;
  TimeOfDay? _hora;
  bool _done = false;

  bool _isSubmitting = false;
  _SubmitAction? _submittingAction;
  bool _savedAny = false;

  @override
  void initState() {
    super.initState();
    _dataYmd = _todayYmd();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descricaoController.dispose();
    super.dispose();
  }

  String _todayYmd() {
    final d = DateTime.now();
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

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

  void _resetForm() {
    setState(() {
      _titleController.clear();
      _descricaoController.clear();
      _dataYmd = _todayYmd();
      _hora = null;
      _done = false;
    });
  }

  Future<Task> _buildTask() async {
    final now = DateTime.now();
    final location = await LocationService.getCurrentLocation();

    return Task(
      id: _uuid.v4(),
      title: _titleController.text.trim(),
      descricao: _descricaoController.text,
      data: _dataYmd,
      hora: _horaToString(_hora),
      done: _done,
      createdAt: now,
      lastUpdated: now,
      location: location,
    );
  }

  Future<bool> _addCommon() async {
    final titulo = _titleController.text.trim();
    final horaStr = _horaToString(_hora);

    if (titulo.isEmpty || _dataYmd.isEmpty || horaStr.isEmpty) {
      if (!mounted) return false;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Campos obrigatórios'),
          content: const Text(
            'Por favor, preencha todos os campos obrigatórios.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return false;
    }

    try {
      final task = await _buildTask();
      await TaskLocalRepository.instance.addTask(task);
      _savedAny = true;

      if (!mounted) return true;
      final body = horaStr.isEmpty ? titulo : '$titulo - $horaStr';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Tarefa criada com sucesso! $body')),
      );
      return true;
    } catch (e, st) {
      debugPrint('Erro ao registrar tarefa: $e\n$st');
      if (!mounted) return false;

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
      return false;
    }
  }

  Future<void> _handleAddAndStay() async {
    setState(() {
      _isSubmitting = true;
      _submittingAction = _SubmitAction.stay;
    });
    final ok = await _addCommon();
    if (!mounted) return;
    setState(() {
      _isSubmitting = false;
      _submittingAction = null;
    });
    if (ok) _resetForm();
  }

  Future<void> _handleAddAndBack() async {
    setState(() {
      _isSubmitting = true;
      _submittingAction = _SubmitAction.back;
    });
    final ok = await _addCommon();
    if (!mounted) return;
    setState(() {
      _isSubmitting = false;
      _submittingAction = null;
    });
    if (ok) Navigator.pop(context, true);
  }

  String get _dataDisplay {
    final parsed = _parseDataYmd(_dataYmd);
    if (parsed == null) return _dataYmd;
    return DateFormat('dd/MM/yyyy').format(parsed);
  }

  @override
  Widget build(BuildContext context) {
    final allDisabled = _isSubmitting;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        Navigator.pop(context, _savedAny);
      },
      child: Scaffold(
      backgroundColor: TaskerColors.appBackground,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
          child: Column(
            children: [
              Expanded(
                child: IgnorePointer(
                  ignoring: allDisabled,
                  child: Opacity(
                    opacity: allDisabled ? 0.65 : 1,
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              IconButton(
                                onPressed: allDisabled
                                    ? null
                                    : () =>
                                        Navigator.pop(context, _savedAny),
                                icon: const Icon(Icons.arrow_back),
                                color: TaskerColors.primary,
                                style: IconButton.styleFrom(
                                  backgroundColor: TaskerColors.primary,
                                  foregroundColor: Colors.white,
                                  minimumSize: const Size(40, 40),
                                ),
                              ),
                              const SizedBox(width: 10),
                              const Expanded(
                                child: Text(
                                  'Nova tarefa',
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w600,
                                    color: TaskerColors.primaryText,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 40),
                          CompleteInput(
                            label: 'Título',
                            child: TextField(
                              controller: _titleController,
                              decoration: TaskerFieldDecoration.decoration(
                                hintText: 'O que você precisa fazer?',
                              ),
                              style: TaskerFieldDecoration.textStyle,
                            ),
                          ),
                          const SizedBox(height: 15),
                          CompleteInput(
                            label: 'Descrição (opcional)',
                            child: TextField(
                              controller: _descricaoController,
                              maxLines: 3,
                              decoration: TaskerFieldDecoration.decoration(
                                hintText:
                                    'Precisa especificar mais detalhes?',
                              ),
                              style: TaskerFieldDecoration.textStyle,
                            ),
                          ),
                          const SizedBox(height: 15),
                          Row(
                            children: [
                              Expanded(
                                child: CompleteInput(
                                  label: 'Data',
                                  child: InkWell(
                                    onTap: _pickDate,
                                    borderRadius: BorderRadius.circular(8),
                                    child: InputDecorator(
                                      decoration:
                                          TaskerFieldDecoration.decoration(),
                                      child: Text(
                                        _dataDisplay,
                                        style: TaskerFieldDecoration.textStyle,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: CompleteInput(
                                  label: 'Hora',
                                  child: InkWell(
                                    onTap: _pickTime,
                                    borderRadius: BorderRadius.circular(8),
                                    child: InputDecorator(
                                      decoration:
                                          TaskerFieldDecoration.decoration(),
                                      child: Text(
                                        _horaToString(_hora).isEmpty
                                            ? 'Selecionar'
                                            : _horaToString(_hora),
                                        style: TaskerFieldDecoration.textStyle,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 15),
                          Row(
                            children: [
                              Checkbox(
                                value: _done,
                                onChanged: allDisabled
                                    ? null
                                    : (v) => setState(() => _done = v ?? false),
                                activeColor: TaskerColors.primary,
                              ),
                              const Text(
                                'Feita',
                                style: TextStyle(
                                  color: TaskerColors.primaryText,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _TaskerOutlineButton(
                      onPressed: allDisabled ? null : _handleAddAndStay,
                      loading: _submittingAction == _SubmitAction.stay,
                      label: 'Adicionar e criar outra',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _TaskerPrimaryButton(
                      onPressed: allDisabled ? null : _handleAddAndBack,
                      loading: _submittingAction == _SubmitAction.back,
                      label: 'Adicionar',
                    ),
                  ),
                ],
              ),
            ],
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
        minimumSize: const Size.fromHeight(44),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
          : Text(label),
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
        minimumSize: const Size.fromHeight(44),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
            ),
    );
  }
}
