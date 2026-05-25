import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Variáveis sensíveis carregadas de `.env` (ou `--dart-define` como fallback).
class EnvConfig {
  EnvConfig._();

  static const _dartDefinePlacesKey =
      String.fromEnvironment('GOOGLE_PLACES_API_KEY');
  static const _dartDefineGeminiKey =
      String.fromEnvironment('GEMINI_API_KEY');

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
}
