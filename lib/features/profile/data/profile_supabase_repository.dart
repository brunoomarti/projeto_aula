import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/auth/firebase_user_id.dart';
import '../../../core/bootstrap/app_bootstrap.dart';
import 'profile_repository.dart';

class ProfileSupabaseRepository implements ProfileRepository {
  ProfileSupabaseRepository({SupabaseClient? client})
      : _client = client ?? AppBootstrap.supabase;

  final SupabaseClient _client;

  static const _table = 'profiles';
  static const _avatarBucket = 'avatars';

  @override
  Future<UserProfile?> fetchCurrent() async {
    final userId = currentFirebaseUserId();
    if (userId == null) return null;

    final row = await _client
        .from(_table)
        .select()
        .eq('id', userId)
        .maybeSingle();

    if (row == null) return null;
    return _fromRow(Map<String, dynamic>.from(row));
  }

  @override
  Future<UserProfile> ensureProfile(firebase_auth.User firebaseUser) async {
    final userId = firebaseUser.uid;
    final existing = await fetchCurrent();

    final displayName = _coalesce(
          existing?.displayName,
          firebaseUser.displayName,
        ) ??
        '';
    final avatarUrl = _coalesce(existing?.avatarUrl, firebaseUser.photoURL);
    final email = firebaseUser.email ?? existing?.email;

    final profile = UserProfile(
      id: userId,
      email: email,
      displayName: displayName.isEmpty ? null : displayName,
      avatarUrl: avatarUrl,
    );

    final shouldWrite = existing == null ||
        _text(existing.displayName) != _text(profile.displayName) ||
        _text(existing.avatarUrl) != _text(profile.avatarUrl) ||
        _text(existing.email) != _text(profile.email);

    if (shouldWrite) {
      await _client.from(_table).upsert({
        'id': userId,
        'email': email,
        'display_name': displayName,
        'avatar_url': avatarUrl,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
    }

    return profile;
  }

  @override
  Future<void> updateDisplayName(String displayName) async {
    final userId = currentFirebaseUserId();
    if (userId == null) {
      throw StateError('Usuário não autenticado no Firebase.');
    }

    await _client.from(_table).upsert({
      'id': userId,
      'display_name': displayName.trim(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  @override
  Future<String> uploadAvatar(Uint8List bytes) async {
    final userId = currentFirebaseUserId();
    if (userId == null) {
      throw StateError('Usuário não autenticado no Firebase.');
    }

    final path = '$userId/avatar.jpg';
    await _client.storage.from(_avatarBucket).uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(
            upsert: true,
            contentType: 'image/jpeg',
          ),
        );

    final baseUrl = _client.storage.from(_avatarBucket).getPublicUrl(path);
    final cacheBuster = DateTime.now().millisecondsSinceEpoch;
    return '$baseUrl?t=$cacheBuster';
  }

  @override
  Future<void> updateAvatarUrl(String avatarUrl) async {
    final userId = currentFirebaseUserId();
    if (userId == null) {
      throw StateError('Usuário não autenticado no Firebase.');
    }

    await _client.from(_table).upsert({
      'id': userId,
      'avatar_url': avatarUrl.trim(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  static String? _coalesce(String? saved, String? provider) {
    final local = saved?.trim();
    if (local != null && local.isNotEmpty) return local;
    final remote = provider?.trim();
    if (remote != null && remote.isNotEmpty) return remote;
    return null;
  }

  static String _text(String? value) => value?.trim() ?? '';

  UserProfile _fromRow(Map<String, dynamic> row) {
    return UserProfile(
      id: '${row['id']}',
      email: row['email'] as String?,
      displayName: row['display_name'] as String?,
      avatarUrl: row['avatar_url'] as String?,
    );
  }
}
