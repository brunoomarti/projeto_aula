// Arquivo gerado por: dart run flutterfire_cli:flutterfire configure
// Enquanto não configurar, o app não inicia o Firebase — veja docs/CONFIGURACAO_FIREBASE_SUPABASE.md

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions não configurado para Linux. '
          'Execute: dart run flutterfire_cli:flutterfire configure',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions não suporta esta plataforma.',
        );
    }
  }

  // Substitua executando `flutterfire configure` (valores abaixo são placeholders).
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'REPLACE_ME',
    appId: 'REPLACE_ME',
    messagingSenderId: 'REPLACE_ME',
    projectId: 'REPLACE_ME',
    authDomain: 'REPLACE_ME.firebaseapp.com',
    storageBucket: 'REPLACE_ME.appspot.com',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyB1dU1Eq0TV-f-9fPdLyRO-VvBqaULHyrw',
    appId: '1:74991029564:android:9f73096adc7ef7830da239',
    messagingSenderId: '74991029564',
    projectId: 'tasker-196a2',
    storageBucket: 'tasker-196a2.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'REPLACE_ME',
    appId: 'REPLACE_ME',
    messagingSenderId: 'REPLACE_ME',
    projectId: 'REPLACE_ME',
    storageBucket: 'REPLACE_ME.appspot.com',
    iosBundleId: 'com.tasker.project',
  );

  static const FirebaseOptions macos = ios;

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'REPLACE_ME',
    appId: 'REPLACE_ME',
    messagingSenderId: 'REPLACE_ME',
    projectId: 'REPLACE_ME',
    authDomain: 'REPLACE_ME.firebaseapp.com',
    storageBucket: 'REPLACE_ME.appspot.com',
  );

  static bool get isConfigured {
    return !android.apiKey.contains('REPLACE');
  }
}
