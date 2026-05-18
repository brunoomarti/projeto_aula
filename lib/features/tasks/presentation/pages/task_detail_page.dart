import 'package:flutter/material.dart';

import '../../domain/task.dart';
import '../widgets/task_card.dart';

/// Tela com todos os campos da tarefa (equivalente ao conteúdo expandido do card + metadados).
class TaskDetailPage extends StatefulWidget {
  const TaskDetailPage({
    super.key,
    required this.task,
    this.resolveAddress,
  });

  final Task task;
  final Future<String?> Function(Task task)? resolveAddress;

  @override
  State<TaskDetailPage> createState() => _TaskDetailPageState();
}

class _TaskDetailPageState extends State<TaskDetailPage> {
  String? _address;
  bool _loadingAddress = true;

  Task get _task => widget.task;

  @override
  void initState() {
    super.initState();
    _resolveIfNeeded();
  }

  @override
  void didUpdateWidget(covariant TaskDetailPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.task.id != widget.task.id ||
        oldWidget.task.location != widget.task.location) {
      _address = null;
      _loadingAddress = true;
      _resolveIfNeeded();
    }
  }

  Future<void> _resolveIfNeeded() async {
    final fn = widget.resolveAddress;
    if (fn == null || _task.location == null) {
      if (mounted) setState(() => _loadingAddress = false);
      return;
    }
    if (mounted) setState(() => _loadingAddress = true);
    try {
      final a = await fn(_task);
      if (!mounted) return;
      setState(() {
        _address = a;
        _loadingAddress = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _address = null;
        _loadingAddress = false;
      });
    }
  }

  String _formatDateTime(DateTime? d) {
    if (d == null) return '—';
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    final yyyy = d.year.toString();
    final hh = d.hour.toString().padLeft(2, '0');
    final min = d.minute.toString().padLeft(2, '0');
    return '$dd/$mm/$yyyy, $hh:$min';
  }

  String _formatTaskDate(String yyyyMmDd) {
    final p = yyyyMmDd.split('-');
    if (p.length != 3) return yyyyMmDd.isEmpty ? '—' : yyyyMmDd;
    return '${p[2]}/${p[1]}/${p[0]}';
  }

  Widget _locationBlock() {
    final loc = _task.location;
    if (loc == null) {
      return _DetailMetaRow(
        icon: Icons.location_off_outlined,
        child: Text(
          'Sem localização',
          style: _bodyStyle(context),
        ),
      );
    }

    final fn = widget.resolveAddress;
    if (fn == null) {
      return _DetailMetaRow(
        icon: Icons.location_on_outlined,
        child: Text(
          '${loc.lat.toStringAsFixed(6)}, ${loc.lng.toStringAsFixed(6)}',
          style: _bodyStyle(context),
        ),
      );
    }

    if (_loadingAddress) {
      return _DetailMetaRow(
        icon: Icons.location_on_outlined,
        child: Text('Buscando endereço...', style: _bodyStyle(context)),
      );
    }
    if (_address != null && _address!.isNotEmpty) {
      return _DetailMetaRow(
        icon: Icons.location_on_outlined,
        child: Text(_address!, style: _bodyStyle(context)),
      );
    }
    return _DetailMetaRow(
      icon: Icons.location_on_outlined,
      child: Text(
        'Endereço não encontrado (${loc.lat.toStringAsFixed(4)}, ${loc.lng.toStringAsFixed(4)})',
        style: _bodyStyle(context),
      ),
    );
  }

  TextStyle? _bodyStyle(BuildContext context) {
    return Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: TaskCardTokens.secondaryText,
          height: 1.35,
        );
  }

  TextStyle? _titleStyle(BuildContext context) {
    return Theme.of(context).textTheme.headlineSmall?.copyWith(
          color: TaskCardTokens.primaryText,
          fontWeight: FontWeight.w600,
        );
  }

  @override
  Widget build(BuildContext context) {
    final description = _task.displayDescription;
    final descEmpty = description.isEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalhes da tarefa'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(_task.title, style: _titleStyle(context)),
          const SizedBox(height: 12),
          Text(
            descEmpty ? 'Autodescritiva' : description,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: descEmpty
                      ? TaskCardTokens.secondaryText
                      : TaskCardTokens.secondaryText,
                  fontStyle: descEmpty ? FontStyle.italic : FontStyle.normal,
                  height: 1.4,
                ),
          ),
          const SizedBox(height: 24),
          _sectionTitle(context, 'Agendamento'),
          const SizedBox(height: 8),
          _DetailMetaRow(
            icon: Icons.calendar_today_outlined,
            child: Text(
              'Data: ${_formatTaskDate(_task.data)}',
              style: _bodyStyle(context),
            ),
          ),
          const SizedBox(height: 6),
          _DetailMetaRow(
            icon: Icons.schedule,
            child: Text(
              'Hora: ${_task.hora.isEmpty ? '—' : _task.hora}',
              style: _bodyStyle(context),
            ),
          ),
          const SizedBox(height: 24),
          _sectionTitle(context, 'Estado'),
          const SizedBox(height: 8),
          _DetailMetaRow(
            icon: _task.done ? Icons.check_circle_outline : Icons.radio_button_unchecked,
            child: Text(
              _task.done ? 'Concluída' : 'Pendente',
              style: _bodyStyle(context),
            ),
          ),
          const SizedBox(height: 6),
          _DetailMetaRow(
            icon: Icons.phone_android_outlined,
            child: Text(
              'Armazenada neste dispositivo',
              style: _bodyStyle(context),
            ),
          ),
          const SizedBox(height: 24),
          _sectionTitle(context, 'Registro'),
          const SizedBox(height: 8),
          _DetailMetaRow(
            icon: Icons.event_outlined,
            child: Text(
              'Criada em: ${_formatDateTime(_task.createdAt)}',
              style: _bodyStyle(context),
            ),
          ),
          const SizedBox(height: 6),
          _DetailMetaRow(
            icon: Icons.update_outlined,
            child: Text(
              'Última atualização: ${_formatDateTime(_task.lastUpdated)}',
              style: _bodyStyle(context),
            ),
          ),
          const SizedBox(height: 24),
          _sectionTitle(context, 'Localização'),
          const SizedBox(height: 8),
          _locationBlock(),
          const SizedBox(height: 24),
          Text(
            'ID: ${_task.id}',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: TaskCardTokens.mutedText,
                ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String text) {
    return Text(
      text,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: TaskCardTokens.primaryText,
            fontWeight: FontWeight.w600,
          ),
    );
  }
}

class _DetailMetaRow extends StatelessWidget {
  const _DetailMetaRow({required this.icon, required this.child});

  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(icon, size: 20, color: TaskCardTokens.secondaryText),
        ),
        const SizedBox(width: 10),
        Expanded(child: child),
      ],
    );
  }
}
