import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:tasker_project/features/home/presentation/utils/selected_day_label.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('pt_BR');
  });

  final today = DateTime(2026, 6, 21);

  test('rótulo de hoje', () {
    final label = SelectedDayLabel.format(today, now: today);
    expect(label, startsWith('Hoje,'));
  });

  test('rótulo de amanhã', () {
    final label = SelectedDayLabel.format(
      today.add(const Duration(days: 1)),
      now: today,
    );
    expect(label, startsWith('Amanhã,'));
  });

  test('rótulo de ontem', () {
    final label = SelectedDayLabel.format(
      today.subtract(const Duration(days: 1)),
      now: today,
    );
    expect(label, startsWith('Ontem,'));
  });

  test('rótulo de outro dia usa dia da semana', () {
    final label = SelectedDayLabel.format(
      DateTime(2026, 6, 25),
      now: today,
    );
    expect(label.toLowerCase(), contains('de'));
    expect(label[0], label[0].toUpperCase());
  });
}
