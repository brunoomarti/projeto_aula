import 'package:flutter_test/flutter_test.dart';

import 'package:tasker_project/features/profile/data/profile_repository.dart';
import 'package:tasker_project/features/tasks/domain/task.dart';

/// Contrato JSON das tabelas PostgREST (Supabase REST).
void main() {
  group('Supabase REST — tabela tasks', () {
    test('toSupabaseRow / fromSupabaseRow preservam campos da API', () {
      final created = DateTime.utc(2026, 5, 24, 10, 0);
      final updated = DateTime.utc(2026, 5, 24, 11, 30);

      final task = Task(
        id: 'task-abc',
        title: 'Reunião Sapion',
        descricao: 'Negócios',
        data: '2026-05-25',
        hora: '14:00',
        done: false,
        createdAt: created,
        lastUpdated: updated,
        location: const TaskLocation(lat: -19.5, lng: -40.6, name: 'Sapion'),
        iconKey: 'work',
        createdViaMagic: true,
        createdViaVoice: true,
      );

      final row = task.toSupabaseRow('firebase-uid-1');
      expect(row['user_id'], 'firebase-uid-1');
      expect(row['title'], 'Reunião Sapion');
      expect(row['created_via_magic'], isTrue);
      expect(row['created_via_voice'], isTrue);
      expect(row['location'], isA<Map>());

      final restored = Task.fromSupabaseRow({
        ...row,
        'created_at': created.toIso8601String(),
        'last_updated': updated.toIso8601String(),
      });

      expect(restored.id, task.id);
      expect(restored.title, task.title);
      expect(restored.location?.name, 'Sapion');
      expect(restored.synced, isTrue);
    });
  });

  group('Supabase REST — tabela profiles', () {
    test('UserProfile JSON usa snake_case do PostgREST', () {
      const profile = UserProfile(
        id: 'firebase-uid-1',
        email: 'user@test.com',
        displayName: 'Maria Silva',
        avatarUrl: 'https://cdn.test/avatar.jpg',
      );

      final json = profile.toJson();
      expect(json['id'], 'firebase-uid-1');
      expect(json['display_name'], 'Maria Silva');
      expect(json['avatar_url'], 'https://cdn.test/avatar.jpg');

      final restored = UserProfile.fromJson({
        'id': 'firebase-uid-1',
        'email': 'user@test.com',
        'display_name': 'Maria Silva',
        'avatar_url': 'https://cdn.test/avatar.jpg',
      });

      expect(restored.effectiveDisplayName, 'Maria Silva');
      expect(restored.avatarUrl, 'https://cdn.test/avatar.jpg');
    });
  });
}
