import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:tasker_project/features/tasks/data/pilha_local_repository.dart';
import 'package:tasker_project/features/tasks/domain/pilha.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('saveAll e getAll persistem pilhas', () async {
    final pilhas = [
      Pilha(id: '1', name: 'Manhã', createdAt: DateTime(2026, 6, 21)),
      Pilha(id: '2', name: 'Tarde'),
    ];

    await PilhaLocalRepository.instance.saveAll(pilhas);
    final loaded = await PilhaLocalRepository.instance.getAll();

    expect(loaded, hasLength(2));
    expect(loaded.first.name, 'Manhã');
  });
}
