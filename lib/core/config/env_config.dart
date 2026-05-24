import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Variáveis sensíveis carregadas de `.env` (ou `--dart-define` como fallback).
class EnvConfig {
  EnvConfig._();

  static const _dartDefineKey = String.fromEnvironment('GOOGLE_PLACES_API_KEY');

  /// Chave da API Google (Places + Geocoding).
  static String get googlePlacesApiKey {
    final fromFile = dotenv.maybeGet('GOOGLE_PLACES_API_KEY')?.trim() ?? '';
    if (fromFile.isNotEmpty) return fromFile;
    return _dartDefineKey.trim();
  }

  static bool get isGoogleConfigured => googlePlacesApiKey.isNotEmpty;
}
