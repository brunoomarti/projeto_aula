import 'package:flutter/foundation.dart';
import 'package:tasker_project/core/icons/tasker_icon.dart';
import 'package:tasker_project/core/icons/tasker_icon_glyph.dart';

import 'package:hugeicons/hugeicons.dart';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../app/theme/tasker_card_style.dart';
import '../../../../app/theme/tasker_colors.dart';
import '../../../../core/layout/tasker_breakpoints.dart';
import '../../../../core/widgets/tasker_floating_page_shell.dart';
import '../../../../core/widgets/tasker_map_pin.dart';
import 'package:tasker_nlp/tasker_nlp.dart';
import '../../../../core/services/geocode_service.dart';
import '../../domain/task.dart';
import '../state/task_store.dart';
import '../widgets/confirm_delete_dialog.dart';
import '../widgets/task_card.dart';
import '../widgets/task_page_header.dart';
import '../widgets/task_section_card.dart';
import 'new_task_page.dart';

/// Detalhes da tarefa — layout em cards alinhado ao restante do app.
class TaskDetailPage extends StatefulWidget {
  const TaskDetailPage({
    super.key,
    required this.task,
  });

  final Task task;

  @override
  State<TaskDetailPage> createState() => _TaskDetailPageState();
}

class _TaskDetailPageState extends State<TaskDetailPage> {
  String? _address;
  bool _loadingAddress = false;
  bool _togglingDone = false;
  bool _confirmDeleteOpen = false;
  String? _addressLocationKey;

  late TaskStore _store;

  @override
  void initState() {
    super.initState();
    _store = context.read<TaskStore>();
    _store.addListener(_onStoreChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _onStoreChanged();
    });
  }

  @override
  void dispose() {
    _store.removeListener(_onStoreChanged);
    super.dispose();
  }

  Task _currentTask() => _store.taskById(widget.task.id) ?? widget.task;

  void _onStoreChanged() {
    if (!mounted) return;

    final task = _store.taskById(widget.task.id);
    if (task == null || task.deleted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
      });
      return;
    }

    _syncAddress(task);
  }

  String _locationKey(TaskLocation? loc) {
    if (loc == null) return '';
    return '${loc.lat.toStringAsFixed(6)},${loc.lng.toStringAsFixed(6)}';
  }

  void _syncAddress(Task task) {
    final key = _locationKey(task.location);
    if (key == _addressLocationKey) return;
    _addressLocationKey = key;

    if (task.location == null) {
      setState(() {
        _address = null;
        _loadingAddress = false;
      });
      return;
    }

    _resolveAddress(task.location!);
  }

  Future<void> _resolveAddress(TaskLocation loc) async {
    final persisted = loc.formattedAddress?.trim();
    if (persisted != null && persisted.isNotEmpty) {
      setState(() {
        _address = persisted;
        _loadingAddress = false;
      });
      return;
    }

    setState(() => _loadingAddress = true);
    try {
      final address = await GeocodeService.getAddressCached(loc);
      if (!mounted) return;
      setState(() {
        _address = address;
        _loadingAddress = false;
      });
      if (address != null && address.trim().isNotEmpty) {
        await context
            .read<TaskStore>()
            .persistTaskLocationAddress(_currentTask().id, address);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _address = null;
        _loadingAddress = false;
      });
    }
  }

  Future<void> _refreshAddress() async {
    _addressLocationKey = null;
    _syncAddress(_currentTask());
  }

  Future<void> _toggleDone() async {
    if (_togglingDone) return;
    final task = _currentTask();
    setState(() => _togglingDone = true);
    try {
      await _store.updateTaskDone(task.id, !task.done);
    } finally {
      if (mounted) setState(() => _togglingDone = false);
    }
  }

  String _formatDateTime(DateTime? d) {
    if (d == null) return '—';
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    final yyyy = d.year.toString();
    final hh = d.hour.toString().padLeft(2, '0');
    final min = d.minute.toString().padLeft(2, '0');
    return '$dd/$mm/$yyyy · $hh:$min';
  }

  String _formatTaskDate(String yyyyMmDd) {
    final p = yyyyMmDd.split('-');
    if (p.length != 3) return yyyyMmDd.isEmpty ? '—' : yyyyMmDd;
    return '${p[2]}/${p[1]}/${p[0]}';
  }

  Future<void> _openEdit() async {
    await Navigator.of(context).push<Task>(
      MaterialPageRoute<Task>(
        builder: (context) => NewTaskPage(taskToEdit: _currentTask()),
      ),
    );
  }

  Future<void> _confirmDeleteTask() async {
    final task = _currentTask();
    await _store.markTaskDeleted(task.id);
    if (!mounted) return;
    setState(() => _confirmDeleteOpen = false);
  }

  Future<void> _openRouteInMaps(Task task) async {
    final loc = task.location;
    if (loc == null) return;

    final destination =
        '${loc.lat.toStringAsFixed(6)},${loc.lng.toStringAsFixed(6)}';
    final uri = switch (defaultTargetPlatform) {
      TargetPlatform.iOS => Uri.https('maps.apple.com', '/', {
        'daddr': destination,
        'dirflg': 'd',
      }),
      _ => Uri.https('www.google.com', '/maps/dir/', {
        'api': '1',
        'destination': destination,
        'travelmode': 'driving',
      }),
    };

    final launched = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );
    if (!mounted || launched) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Não foi possível abrir a rota no app de mapas.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    context.watch<TaskStore>();
    final task = _currentTask();
    return Scaffold(
      backgroundColor: TaskerColors.appBackground,
      body: Stack(
        children: [
          TaskerFloatingPageShell(
            headerReserve: TaskPageHeaderBar.reserveHeight(context),
            header: TaskPageHeaderBar(
              title: 'Detalhes',
              subtitle: 'Informações da tarefa',
              onBack: () => Navigator.of(context).pop(),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    onPressed: _openEdit,
                    icon: const AppHugeIcon(icon: HugeIcons.strokeRoundedEdit01),
                    color: TaskerColors.primaryText,
                    tooltip: 'Editar tarefa',
                  ),
                  IconButton(
                    onPressed: () => setState(() => _confirmDeleteOpen = true),
                    icon: const AppHugeIcon(icon: HugeIcons.strokeRoundedDelete01),
                    color: const Color(0xFFE15E5B),
                    tooltip: 'Excluir tarefa',
                  ),
                ],
              ),
            ),
            bodyBuilder: (context, insets) {
              return RefreshIndicator(
                color: TaskerColors.primary,
                onRefresh: _refreshAddress,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.maxWidth;
                    final pagePadding = TaskerBreakpoints.pagePadding(width);
                    return SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: EdgeInsets.fromLTRB(
                        pagePadding.left,
                        insets.top,
                        pagePadding.right,
                        insets.bottom,
                      ),
                      child: TaskerResponsiveContent(
                        width: width,
                        child: _buildBody(width, task),
                      ),
                    );
                  },
                ),
              );
            },
          ),
          Positioned.fill(
            child: ConfirmDeleteDialog(
              open: _confirmDeleteOpen,
              taskTitle: task.title,
              onCancel: () => setState(() => _confirmDeleteOpen = false),
              onConfirm: _confirmDeleteTask,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(double width, Task task) {
    final isWide = TaskerBreakpoints.isWide(width);
    final hasLocation = task.location != null;
    final splitLayout = isWide && hasLocation;
    final errandItems = parseErrandListFromDescription(task.descricao);
    final hasErrandList = errandItems.isNotEmpty;

    final mainColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TaskCardSurface(
          task: task,
          showTime: false,
          showDoneToggle: false,
          showTaskType: false,
          pinDescriptionToBottom: true,
          flexibleHeight: true,
          header: TaskStatusBadge(done: task.done),
          titleMaxLines: 2,
          descriptionMaxLines: 3,
          descriptionOverride:
              hasErrandList ? errandListSummaryLabel : null,
        ),
        if (hasErrandList) ...[
          const SizedBox(height: TaskerCardStyle.sectionSpacing),
          _buildErrandListCard(errandItems),
        ],
        const SizedBox(height: TaskerCardStyle.sectionSpacing),
        _buildDoneTile(task),
        const SizedBox(height: TaskerCardStyle.sectionSpacing),
        _buildScheduleSection(width, task),
        if (!splitLayout) ...[
          const SizedBox(height: TaskerCardStyle.sectionSpacing),
          _buildLocationCard(task),
        ],
        const SizedBox(height: TaskerCardStyle.sectionSpacing),
        _buildHistorySection(task),
      ],
    );

    if (splitLayout) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: mainColumn),
          const SizedBox(width: 24),
          Expanded(child: _buildLocationCard(task)),
        ],
      );
    }

    return mainColumn;
  }

  Widget _buildErrandListCard(List<String> items) {
    return TaskSectionCard(
      title: errandListSummaryLabel,
      icon: HugeIcons.strokeRoundedCheckList,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '•',
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.35,
                    fontWeight: FontWeight.w700,
                    color: TaskerColors.primary,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    items[i],
                    style: const TextStyle(
                      fontSize: 15,
                      height: 1.35,
                      color: TaskerColors.primaryText,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDoneTile(Task task) {
    return TaskSectionActionTile(
      icon: task.done
          ? HugeIcons.strokeRoundedCheckmarkCircle01
          : HugeIcons.strokeRoundedRecord,
      title: task.done ? 'Tarefa concluída' : 'Marcar como concluída',
      subtitle: task.done
          ? 'Toque para voltar ao status pendente'
          : 'Toque quando terminar esta tarefa',
      active: task.done,
      loading: _togglingDone,
      onTap: _toggleDone,
      trailing: AppHugeIcon(
        icon: task.done
            ? HugeIcons.strokeRoundedUndo
            : HugeIcons.strokeRoundedTick01,
        color: TaskerColors.primary,
        size: 24,
      ),
    );
  }

  Widget _buildScheduleSection(double width, Task task) {
    final stackFields = width < 400;
    final dateTile = _InfoTile(
      icon: HugeIcons.strokeRoundedCalendar01,
      label: 'Data',
      value: _formatTaskDate(task.data),
    );
    final timeTile = _InfoTile(
      icon: HugeIcons.strokeRoundedTimeSchedule,
      label: 'Hora',
      value: task.hora.isEmpty ? 'Sem horário' : task.hora,
      muted: task.hora.isEmpty,
    );

    return TaskSectionCard(
      title: 'Agendamento',
      icon: HugeIcons.strokeRoundedCalendarCheckIn01,
      child: stackFields
          ? Column(
              children: [
                dateTile,
                const SizedBox(height: 12),
                timeTile,
              ],
            )
          : Row(
              children: [
                Expanded(child: dateTile),
                const SizedBox(width: 12),
                Expanded(child: timeTile),
              ],
            ),
    );
  }

  Widget _buildLocationCard(Task task) {
    return TaskSectionCard(
      title: 'Localização',
      icon: HugeIcons.strokeRoundedMapsLocation01,
      child: _LocationSection(
        task: task,
        address: _address,
        loadingAddress: _loadingAddress,
        onOpenRoute: task.location == null ? null : () => _openRouteInMaps(task),
      ),
    );
  }

  Widget _buildHistorySection(Task task) {
    return TaskSectionCard(
      title: 'Histórico',
      icon: HugeIcons.strokeRoundedWorkHistory,
      child: Column(
        children: [
          _MetaLine(
            icon: HugeIcons.strokeRoundedAddCircle,
            label: 'Criada em',
            value: _formatDateTime(task.createdAt),
          ),
          const SizedBox(height: 10),
          _MetaLine(
            icon: HugeIcons.strokeRoundedRefresh,
            label: 'Atualizada em',
            value: _formatDateTime(task.lastUpdated),
          ),
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
    this.muted = false,
  });

  final TaskerIconGlyph icon;
  final String label;
  final String value;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: TaskCardTokens.timeChipBackground,
        borderRadius: BorderRadius.circular(TaskerCardStyle.innerTileRadius),
        border: Border.all(color: TaskCardTokens.timeChipBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                TaskerIcon(icon: icon, size: 17, color: TaskerColors.primary),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: TaskerColors.secondaryText.withValues(alpha: 0.9),
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                height: 1.15,
                color: muted
                    ? TaskerColors.mutedText
                    : TaskCardTokens.primaryText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetaLine extends StatelessWidget {
  const _MetaLine({
    required this.icon,
    required this.label,
    required this.value,
  });

  final TaskerIconGlyph icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: TaskerIcon(icon: icon, size: 20, color: TaskerColors.primary),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: TaskerColors.secondaryText.withValues(alpha: 0.9),
                  fontWeight: FontWeight.w500,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  color: TaskerColors.primaryText,
                  fontWeight: FontWeight.w500,
                  height: 1.25,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LocationSection extends StatelessWidget {
  const _LocationSection({
    required this.task,
    required this.address,
    required this.loadingAddress,
    this.onOpenRoute,
  });

  final Task task;
  final String? address;
  final bool loadingAddress;
  final VoidCallback? onOpenRoute;

  @override
  Widget build(BuildContext context) {
    final loc = task.location;
    if (loc == null) {
      return const _EmptyLocationState();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _LocationPreviewMap(
          key: ValueKey(
            '${loc.lat.toStringAsFixed(6)},${loc.lng.toStringAsFixed(6)}',
          ),
          location: loc,
        ),
        const SizedBox(height: 14),
        if (loadingAddress)
          const Row(
            children: [
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 10),
              Text(
                'Buscando endereço…',
                style: TextStyle(
                  color: TaskCardTokens.secondaryText,
                  fontSize: 13,
                ),
              ),
            ],
          )
        else if (address != null && address!.isNotEmpty)
          Text(
            TaskLocation.formatAddressLine(
              location: loc,
              streetAddress: address,
            ),
            style: TextStyle(
              color: TaskCardTokens.primaryText,
              fontSize: 13,
              height: 1.4,
              fontWeight: FontWeight.w500,
            ),
          )
        else if (loc.name != null && loc.name!.trim().isNotEmpty)
          Text(
            TaskLocation.formatAddressLine(location: loc),
            style: TextStyle(
              color: TaskCardTokens.primaryText,
              fontSize: 13,
              height: 1.4,
              fontWeight: FontWeight.w500,
            ),
          )
        else
          Text(
            'Endereço não disponível para estas coordenadas.',
            style: TextStyle(
              color: TaskCardTokens.secondaryText.withValues(alpha: 0.85),
              fontSize: 13,
              height: 1.35,
            ),
          ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: onOpenRoute,
            icon: const AppHugeIcon(icon: HugeIcons.strokeRoundedDirections01),
            label: const Text('Abrir rota no mapa'),
          ),
        ),
      ],
    );
  }
}

class _EmptyLocationState extends StatelessWidget {
  const _EmptyLocationState();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFF5F6FA),
        borderRadius: BorderRadius.circular(TaskerCardStyle.innerTileRadius),
        border: Border.all(color: const Color(0xFFE8EAEF)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppHugeIcon(icon: HugeIcons.strokeRoundedLocationOffline01,
              size: 24,
              color: TaskerColors.mutedText.withValues(alpha: 0.85),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Esta tarefa não tem localização salva.',
                style: TextStyle(
                  color: TaskerColors.secondaryText.withValues(alpha: 0.95),
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Mapa estático com pin na posição da tarefa.
class _LocationPreviewMap extends StatelessWidget {
  const _LocationPreviewMap({super.key, required this.location});

  final TaskLocation location;

  @override
  Widget build(BuildContext context) {
    final point = LatLng(location.lat, location.lng);

    return LayoutBuilder(
      builder: (context, constraints) {
        final mapHeight =
            TaskerBreakpoints.previewMapHeight(constraints.maxWidth);
        return ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: SizedBox(
            height: mapHeight,
            child: Stack(
              children: [
                FlutterMap(
                  options: MapOptions(
                    initialCenter: point,
                    initialZoom: 15,
                    minZoom: 5,
                    maxZoom: 18,
                    interactionOptions: const InteractionOptions(
                      flags: InteractiveFlag.none,
                    ),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.tasker.project',
                    ),
                  ],
                ),
                const IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color(0x00000000),
                          Color(0x18000000),
                        ],
                      ),
                    ),
                    child: SizedBox.expand(),
                  ),
                ),
                IgnorePointer(
                  child: Center(
                    child: Transform.translate(
                      offset: TaskerMapPin.centerAnchorOffset(28),
                      child: const TaskerMapPin(
                        fillColor: TaskerColors.primary,
                        size: 28,
                        showGroundShadow: true,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

