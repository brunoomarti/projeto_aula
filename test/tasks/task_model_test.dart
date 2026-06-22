import 'package:flutter_test/flutter_test.dart';

import 'package:tasker_project/features/tasks/domain/task.dart';

void main() {
  final now = DateTime(2026, 6, 21, 10);

  Task baseTask() => Task(
        id: 't1',
        title: 'Reunião',
        descricao: '  Detalhes  ',
        data: '2026-06-21',
        hora: '14:00',
        createdAt: now,
        lastUpdated: now,
        location: const TaskLocation(
          lat: -23.5,
          lng: -46.6,
          name: 'Escritório',
          formattedAddress: 'Rua A, 100',
          placeId: 'place-1',
        ),
        iconKey: 'work',
        iconBackgroundArgb: 0xFFD4CCFF,
        pilhaId: 'p1',
        createdViaMagic: true,
      );

  test('displayDescription remove espaços', () {
    expect(baseTask().displayDescription, 'Detalhes');
  });

  test('copyWith limpa pilha e completedAt', () {
    final cleared = baseTask().copyWith(clearPilhaId: true, clearCompletedAt: true);
    expect(cleared.pilhaId, isNull);
    expect(cleared.completedAt, isNull);
  });

  test('fromJson e toLocalJson round-trip', () {
    final original = baseTask().copyWith(done: true, completedAt: now);
    final restored = Task.fromJson(original.toLocalJson());

    expect(restored.title, 'Reunião');
    expect(restored.pilhaId, 'p1');
    expect(restored.location?.name, 'Escritório');
    expect(restored.createdViaMagic, isTrue);
    expect(restored.done, isTrue);
  });

  test('fromSupabaseRow mapeia snake_case', () {
    final task = Task.fromSupabaseRow({
      'id': 's1',
      'title': 'Nuvem',
      'descricao': '',
      'data': '2026-06-21',
      'hora': '09:00',
      'done': false,
      'created_at': now.toIso8601String(),
      'last_updated': now.toIso8601String(),
      'deleted': false,
      'icon_key': 'gym',
      'icon_background_argb': 123,
      'postponed': true,
      'schedule_adjusted': true,
      'created_via_magic': true,
      'created_via_voice': true,
    });

    expect(task.title, 'Nuvem');
    expect(task.iconKey, 'gym');
    expect(task.postponed, isTrue);
    expect(task.createdViaVoice, isTrue);
  });

  test('toSupabaseRow inclui usuário e campos opcionais', () {
    final row = baseTask().toSupabaseRow('user-1');
    expect(row['user_id'], 'user-1');
    expect(row['icon_key'], 'work');
    expect(row['location'], isNotNull);
  });

  group('TaskLocation', () {
    test('hasPersistedAddress', () {
      const withAddress = TaskLocation(lat: 0, lng: 0, formattedAddress: 'Rua B');
      const without = TaskLocation(lat: 0, lng: 0);
      expect(withAddress.hasPersistedAddress, isTrue);
      expect(without.hasPersistedAddress, isFalse);
    });

    test('tryParse aceita latitude/longitude legado', () {
      final loc = TaskLocation.tryParse({
        'latitude': -23.0,
        'longitude': -46.0,
        'name': 'Local',
      });
      expect(loc?.lat, -23.0);
      expect(loc?.name, 'Local');
    });

    test('copyWith limpa endereço', () {
      const loc = TaskLocation(lat: 1, lng: 2, formattedAddress: 'X');
      final cleared = loc.copyWith(clearFormattedAddress: true);
      expect(cleared.formattedAddress, isNull);
    });
  });
}
