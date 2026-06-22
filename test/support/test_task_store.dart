import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tasker_project/features/tasks/data/task_repository.dart';
import 'package:tasker_project/features/tasks/presentation/state/task_store.dart';

import '../auth/fake_repositories.dart';
import 'fake_connectivity_service.dart';

/// [TaskStore] pronto para testes — sem Firebase/Supabase/rede reais.
Future<TaskStore> readyTaskStoreForTest({TaskRepository? repository}) async {
  TestWidgetsFlutterBinding.ensureInitialized();

  final store = TaskStore(
    repository: repository ?? FakeTaskRepository(),
    connectivity: FakeConnectivityService(),
    firebaseAuth: MockFirebaseAuth(signedIn: false),
  );
  store.setCloudSyncEnabled(false);
  await store.reload();
  return store;
}
