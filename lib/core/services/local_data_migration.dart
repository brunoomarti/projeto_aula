import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/auth/firebase_user_id.dart';
import '../../features/profile/data/profile_repository.dart';
import '../../features/tasks/data/task_local_repository.dart';
import '../../features/tasks/data/task_repository.dart';

/// Migra tarefas e nome do perfil do armazenamento local para o Supabase (uma vez).
class LocalDataMigration {
  LocalDataMigration({
    required TaskRepository taskRepository,
    required ProfileRepository profileRepository,
    TaskLocalRepository? localTasks,
  })  : _tasks = taskRepository,
        _profile = profileRepository,
        _localTasks = localTasks ?? TaskLocalRepository.instance;

  final TaskRepository _tasks;
  final ProfileRepository _profile;
  final TaskLocalRepository _localTasks;

  static const _migrationDoneKeyPrefix = 'cloud_migration_v1_done_';

  Future<void> runIfNeeded() async {
    final userId = currentFirebaseUserId();
    if (userId == null || userId.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final migrationKey = '$_migrationDoneKeyPrefix$userId';
    if (prefs.getBool(migrationKey) == true) return;

    final remoteTasks = await _tasks.fetchAll();
    if (remoteTasks.isEmpty) {
      final localTasks = await _localTasks.getAll();
      for (final task in localTasks) {
        await _tasks.upsertTask(task);
      }
      if (localTasks.isNotEmpty) {
        debugPrint(
          'LocalDataMigration: ${localTasks.length} tarefa(s) enviada(s) ao Supabase.',
        );
      }
    }

    final profile = await _profile.fetchCurrent();
    final localName = await _readLocalDisplayName();
    if (localName != null &&
        localName.isNotEmpty &&
        (profile?.displayName == null || profile!.displayName!.trim().isEmpty)) {
      await _profile.updateDisplayName(localName);
      debugPrint('LocalDataMigration: nome local copiado para o perfil na nuvem.');
    }

    await prefs.setBool(migrationKey, true);
  }

  static Future<String?> _readLocalDisplayName() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString('user_display_name')?.trim();
    if (name == null || name.isEmpty) return null;
    return name;
  }
}
