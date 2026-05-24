import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'env_config.dart';

/// Carrega `.env` do bundle Flutter (arquivo na raiz do projeto).
Future<void> loadEnv() async {
  try {
    await dotenv.load(fileName: '.env');
    if (!EnvConfig.isGoogleConfigured) {
      debugPrint(
        'Env: GOOGLE_PLACES_API_KEY vazio. '
        'Copie .env.example para .env e preencha a chave.',
      );
    }
  } catch (e) {
    debugPrint(
      'Env: não foi possível carregar .env ($e). '
      'Copie .env.example para .env na raiz do projeto.',
    );
  }
}
