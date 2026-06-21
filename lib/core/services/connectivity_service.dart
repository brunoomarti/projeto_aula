import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// Observa o estado da conexão (online/offline) do dispositivo.
///
/// `connectivity_plus` indica apenas se há uma interface de rede ativa — não
/// garante acesso real à internet. Por isso o [TaskStore] também trata falhas
/// de rede nas chamadas ao Supabase como "offline".
class ConnectivityService {
  ConnectivityService({Connectivity? connectivity})
      : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;

  static bool _isOnline(List<ConnectivityResult> results) {
    // Alguns aparelhos retornam lista vazia no boot — não tratar como offline.
    if (results.isEmpty) return true;
    return results.any((r) => r != ConnectivityResult.none);
  }

  /// Verifica o estado atual da conexão.
  Future<bool> isOnline() async {
    try {
      final results = await _connectivity.checkConnectivity();
      return _isOnline(results);
    } catch (e) {
      debugPrint('ConnectivityService.isOnline: $e');
      // Em caso de dúvida, assume online para tentar a nuvem.
      return true;
    }
  }

  /// Emite `true`/`false` a cada mudança de conectividade.
  Stream<bool> get onStatusChange =>
      _connectivity.onConnectivityChanged.map(_isOnline);
}
