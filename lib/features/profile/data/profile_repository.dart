import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;

/// Perfil do usuário na nuvem (Supabase `profiles`).
class UserProfile {
  const UserProfile({
    required this.id,
    this.email,
    this.displayName,
    this.avatarUrl,
  });

  final String id;
  final String? email;
  final String? displayName;
  final String? avatarUrl;

  String get effectiveDisplayName {
    final name = displayName?.trim();
    if (name != null && name.isNotEmpty) return name;
    final mail = email?.trim();
    if (mail != null && mail.isNotEmpty) {
      final at = mail.indexOf('@');
      return at > 0 ? mail.substring(0, at) : mail;
    }
    return 'Usuário';
  }

  UserProfile copyWith({
    String? id,
    String? email,
    String? displayName,
    String? avatarUrl,
  }) {
    return UserProfile(
      id: id ?? this.id,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        if (email != null) 'email': email,
        if (displayName != null) 'display_name': displayName,
        if (avatarUrl != null) 'avatar_url': avatarUrl,
      };

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: '${json['id'] ?? ''}',
      email: json['email'] as String?,
      displayName: json['display_name'] as String?,
      avatarUrl: json['avatar_url'] as String?,
    );
  }
}

abstract class ProfileRepository {
  Future<UserProfile?> fetchCurrent();

  Future<UserProfile> ensureProfile(firebase_auth.User firebaseUser);

  Future<void> updateDisplayName(String displayName);

  Future<String> uploadAvatar(Uint8List bytes);

  Future<void> updateAvatarUrl(String avatarUrl);
}
