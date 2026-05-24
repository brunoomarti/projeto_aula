import 'package:intl/intl.dart';

import '../../../tasks/presentation/state/task_store.dart';

/// Rótulo da data selecionada no cabeçalho da home (ex.: «Hoje, 19 de agosto»).
abstract final class SelectedDayLabel {
  static final _dayMonthFormat = DateFormat("d 'de' MMMM", 'pt_BR');
  static final _weekdayDayMonthFormat =
      DateFormat("EEEE, d 'de' MMMM", 'pt_BR');

  static String format(DateTime selected, {DateTime? now}) {
    final today = TaskStore.dateOnly(now ?? DateTime.now());
    final day = TaskStore.dateOnly(selected);
    final diff = day.difference(today).inDays;
    final datePart = _dayMonthFormat.format(day);

    return switch (diff) {
      0 => 'Hoje, $datePart',
      1 => 'Amanhã, $datePart',
      -1 => 'Ontem, $datePart',
      _ => _capitalizeFirst(_weekdayDayMonthFormat.format(day)),
    };
  }

  static String _capitalizeFirst(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1);
  }
}
