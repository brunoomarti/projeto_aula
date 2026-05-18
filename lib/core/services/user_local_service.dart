import 'package:shared_preferences/shared_preferences.dart';

/// Nome exibido no [UserDock] (substitui `displayName` do Firebase Auth).
class UserLocalService {
  UserLocalService._();

  static const _displayNameKey = 'user_display_name';

  static Future<String?> getDisplayName() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString(_displayNameKey)?.trim();
    if (name == null || name.isEmpty) return null;
    return name;
  }

  static Future<void> setDisplayName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_displayNameKey, name.trim());
  }
}
