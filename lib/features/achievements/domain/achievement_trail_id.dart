/// Identificadores das trilhas de conquistas.
enum AchievementTrailId {
  tasksCreated,
  unfinishedTasks,
  taskAdvances,
  daysCompleted,
  pilhasCreated,
  magicInput,
  curiosities,
}

extension AchievementTrailIdX on AchievementTrailId {
  String get storageKey => name;

  static AchievementTrailId? tryParse(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    for (final value in AchievementTrailId.values) {
      if (value.name == raw) return value;
    }
    return null;
  }
}
