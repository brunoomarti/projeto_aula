import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/layout/tasker_breakpoints.dart';
import '../../../../app/theme/tasker_colors.dart';
import '../../../../core/services/geocode_service.dart';
import '../../../../core/services/location_service.dart';
import '../../domain/address_suggestion.dart';
import '../../domain/task.dart';
import 'complete_input.dart';

/// Mapa + busca de endereço para nova tarefa.
class TaskLocationPickerMap extends StatefulWidget {
  const TaskLocationPickerMap({
    super.key,
    this.embedded = false,
    this.initialLocation,
  });

  /// Sem título/descrição duplicados (usado dentro de um card na tela).
  final bool embedded;

  /// Centro inicial do mapa (ex.: edição de tarefa com local salvo).
  final TaskLocation? initialLocation;

  @override
  State<TaskLocationPickerMap> createState() => TaskLocationPickerMapState();
}

class TaskLocationPickerMapState extends State<TaskLocationPickerMap> {
  final _mapKey = GlobalKey<_LocationMapSurfaceState>();

  /// Lê o pin (centro do mapa) só quando necessário — ex.: ao salvar a tarefa.
  TaskLocation? get selectedLocation => _mapKey.currentState?.selectedLocation;

  Future<void> recenterOnDevice() =>
      _mapKey.currentState?.recenterOnDevice() ?? Future.value();

  /// Força o mapa a recarregar tiles após ganhar tamanho (ex.: animação de abertura).
  void refreshAfterLayout() => _mapKey.currentState?.refreshAfterLayout();

  void _onSearchSelected(AddressSuggestion suggestion) {
    _mapKey.currentState?.moveTo(suggestion.location);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!widget.embedded) ...[
          Text(
            'Localização',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: TaskerColors.primaryText,
                  fontWeight: FontWeight.w500,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            'Arraste o mapa, dê zoom ou busque um endereço.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: TaskerColors.secondaryText,
                ),
          ),
          const SizedBox(height: 8),
        ],
        _LocationMapSurface(
          key: _mapKey,
          initialLocation: widget.initialLocation,
        ),
        const SizedBox(height: 10),
        _AddressSearchField(
          locationForBias: () => _mapKey.currentState?.selectedLocation,
          onSelected: _onSearchSelected,
        ),
      ],
    );
  }
}

/// Mapa isolado — arrastar/zoom não disparam callbacks nem rebuilds extras.
class _LocationMapSurface extends StatefulWidget {
  const _LocationMapSurface({super.key, this.initialLocation});

  final TaskLocation? initialLocation;

  @override
  State<_LocationMapSurface> createState() => _LocationMapSurfaceState();
}

class _LocationMapSurfaceState extends State<_LocationMapSurface> {
  static const _defaultCenter = TaskLocation(lat: -23.5505, lng: -46.6333);
  static const _initialZoom = 16.0;
  static const _minZoom = 5.0;
  static const _maxZoom = 19.0;

  static final _interactionFlags = InteractiveFlag.all &
      ~InteractiveFlag.rotate;

  final _mapController = MapController();
  bool _mapReady = false;
  bool _gpsLoading = false;

  LatLng get _startCenter {
    final loc = widget.initialLocation ?? _defaultCenter;
    return LatLng(loc.lat, loc.lng);
  }

  @override
  void initState() {
    super.initState();
    if (widget.initialLocation == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _loadDeviceLocation();
      });
    }
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  /// Centro atual do mapa (onde está o pin fixo) — leitura pontual, sem cache.
  TaskLocation? get selectedLocation {
    if (!_mapReady) return null;
    final center = _mapController.camera.center;
    return TaskLocation(lat: center.latitude, lng: center.longitude);
  }

  Future<void> recenterOnDevice() => _loadDeviceLocation();

  void moveTo(TaskLocation loc) => _moveMapTo(loc, resetZoom: true);

  void refreshAfterLayout() {
    if (!_mapReady) return;
    final camera = _mapController.camera;
    _mapController.move(camera.center, camera.zoom);
  }

  void _onMapReady() {
    if (!mounted) return;
    setState(() => _mapReady = true);
    refreshAfterLayout();
  }

  Future<void> _loadDeviceLocation() async {
    if (!mounted) return;
    setState(() => _gpsLoading = true);

    final quick = await LocationService.getQuickLocationForMap();
    if (quick != null && mounted) {
      _moveMapTo(quick, resetZoom: true);
    }

    final refined = await LocationService.refineLocationForMap();
    if (!mounted) return;
    setState(() => _gpsLoading = false);

    if (refined != null) {
      _moveMapTo(refined, resetZoom: true);
    }
  }

  void _moveMapTo(TaskLocation loc, {required bool resetZoom}) {
    if (!_mapReady) return;
    final zoom = resetZoom ? _initialZoom : _mapController.camera.zoom;
    _mapController.move(LatLng(loc.lat, loc.lng), zoom);
  }

  void _zoomBy(double delta) {
    if (!_mapReady) return;
    final camera = _mapController.camera;
    final next = (camera.zoom + delta).clamp(_minZoom, _maxZoom);
    if (next == camera.zoom) return;
    _mapController.move(camera.center, next);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final mapHeight = TaskerBreakpoints.mapHeight(constraints.maxWidth);
        return SizedBox(
          height: mapHeight,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border.all(color: TaskerColors.mutedText),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(7),
                child: Stack(
                  children: [
                    RepaintBoundary(
                      child: FlutterMap(
                        mapController: _mapController,
                        options: MapOptions(
                          initialCenter: _startCenter,
                          initialZoom: _initialZoom,
                          minZoom: _minZoom,
                          maxZoom: _maxZoom,
                          interactionOptions: InteractionOptions(
                            flags: _mapReady
                                ? _interactionFlags
                                : InteractiveFlag.none,
                          ),
                          onMapReady: _onMapReady,
                        ),
                        children: [
                          TileLayer(
                            urlTemplate:
                                'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName: 'com.example.projeto_aula',
                            keepBuffer: 2,
                          ),
                        ],
                      ),
                    ),
                    if (!_mapReady)
                      const ColoredBox(
                        color: Color(0xFFE8EAF0),
                        child: Center(
                          child: SizedBox(
                            width: 28,
                            height: 28,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      ),
                    Positioned(
                      right: 8,
                      bottom: 8,
                      child: IgnorePointer(
                        ignoring: !_mapReady,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _MapZoomButton(
                              icon: Icons.add,
                              tooltip: 'Aumentar zoom',
                              onPressed: () => _zoomBy(1),
                            ),
                            const SizedBox(height: 4),
                            _MapZoomButton(
                              icon: Icons.remove,
                              tooltip: 'Diminuir zoom',
                              onPressed: () => _zoomBy(-1),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (_gpsLoading)
                      const Positioned(
                        top: 8,
                        right: 8,
                        child: SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    IgnorePointer(
                      child: Center(
                        child: Transform.translate(
                          offset: const Offset(0, -18),
                          child: Icon(
                            Icons.location_on,
                            size: 44,
                            color: TaskerColors.primary,
                            shadows: const [
                              Shadow(
                                blurRadius: 4,
                                color: Color(0x44000000),
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
          ),
        );
      },
    );
  }
}

/// Campo de busca isolado — digitar não rebuilda o mapa.
class _AddressSearchField extends StatefulWidget {
  const _AddressSearchField({
    required this.locationForBias,
    required this.onSelected,
  });

  final TaskLocation? Function()? locationForBias;
  final ValueChanged<AddressSuggestion> onSelected;

  @override
  State<_AddressSearchField> createState() => _AddressSearchFieldState();
}

class _AddressSearchFieldState extends State<_AddressSearchField> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  bool _loading = false;
  bool _suppressSearch = false;
  List<AddressSuggestion> _suggestions = [];
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _focusNode.removeListener(_onFocusChanged);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    if (!_focusNode.hasFocus && mounted) {
      setState(() => _suggestions = []);
    }
  }

  void _onChanged(String value) {
    if (_suppressSearch) {
      _suppressSearch = false;
      return;
    }

    _debounce?.cancel();
    if (value.trim().length < 3) {
      setState(() {
        _suggestions = [];
        _loading = false;
      });
      return;
    }

    setState(() => _loading = true);
    _debounce = Timer(const Duration(milliseconds: 450), () {
      _fetch(value);
    });
  }

  Future<void> _fetch(String query) async {
    final results = await GeocodeService.searchAddresses(
      query,
      near: widget.locationForBias?.call(),
    );
    if (!mounted) return;
    if (_controller.text.trim() != query.trim()) return;

    setState(() {
      _suggestions = results;
      _loading = false;
    });
  }

  void _select(AddressSuggestion item) {
    _suppressSearch = true;
    _controller.text = item.shortLabel;
    _focusNode.unfocus();
    setState(() => _suggestions = []);
    widget.onSelected(item);
  }

  @override
  Widget build(BuildContext context) {
    final showList = _focusNode.hasFocus && _suggestions.isNotEmpty;

    return CompleteInput(
      label: 'Buscar endereço',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _controller,
            focusNode: _focusNode,
            onChanged: _onChanged,
            textInputAction: TextInputAction.search,
            decoration: TaskerFieldDecoration.decoration(
              hintText: 'Rua, loja, restaurante, shopping...',
              suffixIcon: _loading
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : const Icon(
                      Icons.search,
                      color: TaskerColors.mutedText,
                    ),
            ),
            style: TaskerFieldDecoration.textStyle,
          ),
          if (showList) ...[
            const SizedBox(height: 4),
            Material(
              elevation: 4,
              shadowColor: TaskerColors.cardShadow,
              color: TaskerColors.cardBackground,
              borderRadius: BorderRadius.circular(8),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 220),
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  itemCount: _suggestions.length,
                  separatorBuilder: (_, index) => const Divider(
                    height: 1,
                    color: TaskerColors.mutedText,
                  ),
                  itemBuilder: (context, index) {
                    final item = _suggestions[index];
                    final isPlace = item.categoryLabel != null &&
                        item.categoryLabel != 'Endereço';
                    return ListTile(
                      dense: true,
                      leading: Icon(
                        isPlace
                            ? Icons.storefront_outlined
                            : Icons.place_outlined,
                        color: TaskerColors.primary,
                        size: 22,
                      ),
                      title: Text(
                        item.shortLabel,
                        style: TaskerFieldDecoration.textStyle.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (item.categoryLabel != null) ...[
                            Text(
                              item.categoryLabel!,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: TaskerColors.primary,
                              ),
                            ),
                            const SizedBox(height: 2),
                          ],
                          Text(
                            item.displayName,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              color: TaskerColors.secondaryText,
                            ),
                          ),
                        ],
                      ),
                      onTap: () => _select(item),
                    );
                  },
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MapZoomButton extends StatelessWidget {
  const _MapZoomButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 2,
      shadowColor: TaskerColors.cardShadow,
      shape: const CircleBorder(),
      child: IconButton(
        onPressed: onPressed,
        tooltip: tooltip,
        icon: Icon(icon, size: 20, color: TaskerColors.primary),
        padding: const EdgeInsets.all(6),
        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
        style: IconButton.styleFrom(
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ),
    );
  }
}
