import 'package:tasker_project/core/services/connectivity_service.dart';

/// Conectividade fixa para testes — sem plugins nativos.
class FakeConnectivityService extends ConnectivityService {
  FakeConnectivityService();

  @override
  Future<bool> isOnline() async => true;

  @override
  Stream<bool> get onStatusChange => const Stream<bool>.empty();
}
