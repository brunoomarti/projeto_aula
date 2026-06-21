import '../domain/task.dart';

/// Marca tarefas como adiadas quando a data muda após o período de tolerância.
abstract final class TaskPostponementRules {
  static const gracePeriod = Duration(hours: 1);

  /// Aplica a regra de adiamento quando [updated] altera a data de [previous].
  ///
  /// Qualquer troca de dia marca [Task.scheduleAdjusted] (invalida combo, inclusive
  /// tentativa de burlar dentro de 1 h). Após [gracePeriod], também marca
  /// [Task.postponed].
  static Task applyDateChange({
    required Task previous,
    required Task updated,
    required DateTime now,
  }) {
    if (previous.data == updated.data) return updated;

    var result = updated.copyWith(scheduleAdjusted: true);
    if (result.postponed) return result;

    final created = previous.createdAt ?? updated.createdAt;
    if (created == null) {
      return result.copyWith(postponed: true);
    }

    if (now.difference(created) > gracePeriod) {
      return result.copyWith(postponed: true);
    }

    return result;
  }
}
