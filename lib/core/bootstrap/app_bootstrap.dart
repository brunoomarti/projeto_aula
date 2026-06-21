import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../firebase_options.dart';
import '../config/env_config.dart';

/// Inicializa Firebase, Supabase e Google Sign-In.
class AppBootstrap {
  AppBootstrap._();

  static bool _initialized = false;

  static bool get isInitialized => _initialized;

  static SupabaseClient get supabase => Supabase.instance.client;

  static Future<void> initialize() async {
    if (_initialized) return;

    if (!DefaultFirebaseOptions.isConfigured) {
      throw StateError(
        'Firebase não configurado. Execute: dart run flutterfire_cli:flutterfire configure',
      );
    }

    if (!EnvConfig.isSupabaseConfigured) {
      throw StateError(
        'Supabase não configurado. Defina SUPABASE_URL e SUPABASE_ANON_KEY no .env',
      );
    }

    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // Third-party Firebase: JWT do Firebase nas requisições (não use signInWithIdToken).
    await Supabase.initialize(
      url: EnvConfig.supabaseUrl,
      anonKey: EnvConfig.supabaseAnonKey,
      accessToken: () async {
        final user = firebase_auth.FirebaseAuth.instance.currentUser;
        if (user == null) return null;
        return user.getIdToken();
      },
    );

    _initialized = true;
  }

  static bool _googleSignInReady = false;

  /// Inicializa Google Sign-In sob demanda (evita crash na abertura em emuladores sem Play Services).
  static Future<void> ensureGoogleSignInInitialized() async {
    if (_googleSignInReady) return;
    final webClientId = EnvConfig.googleWebClientId;
    try {
      if (webClientId.isNotEmpty) {
        await GoogleSignIn.instance.initialize(serverClientId: webClientId);
      } else {
        await GoogleSignIn.instance.initialize();
        debugPrint(
          'Env: GOOGLE_WEB_CLIENT_ID vazio — login Google no Android pode falhar.',
        );
      }
      _googleSignInReady = true;
    } catch (e, st) {
      debugPrint('GoogleSignIn.initialize: $e\n$st');
      rethrow;
    }
  }
}
