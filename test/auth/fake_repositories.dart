import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;

import 'package:tasker_project/core/services/local_data_migration.dart';
import 'package:tasker_project/features/profile/data/profile_repository.dart';
import 'package:tasker_project/features/tasks/data/task_repository.dart';
import 'package:tasker_project/features/tasks/domain/task.dart';

/// Evita chamar [currentFirebaseUserId] (Firebase real) nos testes de auth.
class NoOpLocalDataMigration extends LocalDataMigration {
  NoOpLocalDataMigration({
    required super.taskRepository,
    required super.profileRepository,
  });

  @override
  Future<void> runIfNeeded() async {}
}

/// Perfil em memória para testes de [AuthController].
class FakeProfileRepository implements ProfileRepository {
  UserProfile? current;
  int ensureProfileCalls = 0;

  @override
  Future<UserProfile?> fetchCurrent() async => current;

  @override
  Future<UserProfile> ensureProfile(firebase_auth.User firebaseUser) async {
    ensureProfileCalls++;
    current = UserProfile(
      id: firebaseUser.uid,
      email: firebaseUser.email,
      displayName: firebaseUser.displayName,
      avatarUrl: firebaseUser.photoURL,
    );
    return current!;
  }

  @override
  Future<void> updateDisplayName(String displayName) async {
    if (current != null) {
      current = current!.copyWith(displayName: displayName);
    }
  }

  @override
  Future<String> uploadAvatar(Uint8List bytes) async => 'https://example.com/a.jpg';

  @override
  Future<void> updateAvatarUrl(String avatarUrl) async {
    if (current != null) {
      current = current!.copyWith(avatarUrl: avatarUrl);
    }
  }
}

/// Tarefas em memória para [LocalDataMigration] nos testes.
class FakeTaskRepository implements TaskRepository {
  final List<Task> tasks = [];

  @override
  Future<List<Task>> fetchAll() async => List.unmodifiable(tasks);

  @override
  Future<void> upsertTask(Task task) async {
    final index = tasks.indexWhere((t) => t.id == task.id);
    if (index >= 0) {
      tasks[index] = task;
    } else {
      tasks.add(task);
    }
  }
}
