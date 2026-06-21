import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Variáveis sensíveis carregadas de `.env` (ou `--dart-define` como fallback).
class EnvConfig {
  EnvConfig._();

  static const _dartDefinePlacesKey =
      String.fromEnvironment('GOOGLE_PLACES_API_KEY');
  static const _dartDefineGeminiKey =
      String.fromEnvironment('GEMINI_API_KEY');
  static const _dartDefineSupabaseUrl =
      String.fromEnvironment('SUPABASE_URL');
  static const _dartDefineSupabaseAnonKey =
      String.fromEnvironment('SUPABASE_ANON_KEY');
  static const _dartDefineGoogleWebClientId =
      String.fromEnvironment('GOOGLE_WEB_CLIENT_ID');

  /// Chave da API Google (Places + Geocoding).
  static String get googlePlacesApiKey {
    final fromFile = dotenv.maybeGet('GOOGLE_PLACES_API_KEY')?.trim() ?? '';
    if (fromFile.isNotEmpty) return fromFile;
    return _dartDefinePlacesKey.trim();
  }

  /// Chave da API Gemini (magic input híbrido).
  static String get geminiApiKey {
    final fromFile = dotenv.maybeGet('GEMINI_API_KEY')?.trim() ?? '';
    if (fromFile.isNotEmpty) return fromFile;
    return _dartDefineGeminiKey.trim();
  }

  static bool get isGoogleConfigured => googlePlacesApiKey.isNotEmpty;

  static bool get isGeminiConfigured => geminiApiKey.isNotEmpty;

  static String get supabaseUrl {
    final fromFile = dotenv.maybeGet('SUPABASE_URL')?.trim() ?? '';
    if (fromFile.isNotEmpty) return fromFile;
    return _dartDefineSupabaseUrl.trim();
  }

  static String get supabaseAnonKey {
    final fromFile = dotenv.maybeGet('SUPABASE_ANON_KEY')?.trim() ?? '';
    if (fromFile.isNotEmpty) return fromFile;
    return _dartDefineSupabaseAnonKey.trim();
  }

  /// Web Client ID do Firebase (OAuth) — necessário para Google Sign-In no Android.
  static String get googleWebClientId {
    final fromFile = dotenv.maybeGet('GOOGLE_WEB_CLIENT_ID')?.trim() ?? '';
    if (fromFile.isNotEmpty) return fromFile;
    return _dartDefineGoogleWebClientId.trim();
  }

  static bool get isSupabaseConfigured =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}
