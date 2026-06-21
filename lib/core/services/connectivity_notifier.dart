import 'dart:async';

import 'package:flutter/foundation.dart';

import 'connectivity_service.dart';

/// Estado de conectividade do dispositivo (Wi‑Fi/dados) para a UI.
///
/// Diferente do flag interno do [TaskStore]: este reflete só a rede do aparelho,
/// não falhas pontuais do Supabase.
class ConnectivityNotifier extends ChangeNotifier {
  ConnectivityNotifier({ConnectivityService? connectivity})
      : _connectivity = connectivity ?? ConnectivityService() {
    _sub = _connectivity.onStatusChange.listen(_setOnline);
    unawaited(_refresh());
  }

  final ConnectivityService _connectivity;
  StreamSubscription<bool>? _sub;

  bool _isOnline = true;

  bool get isOnline => _isOnline;

  Future<void> _refresh() async {
    final online = await _connectivity.isOnline();
    _setOnline(online);
  }

  void _setOnline(bool online) {
    if (_isOnline == online) return;
    _isOnline = online;
    notifyListeners();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
