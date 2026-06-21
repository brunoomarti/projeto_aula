import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;

/// ID do usuário logado (Firebase UID) — usado nas tabelas Supabase com third-party auth.
String? currentFirebaseUserId() =>
    firebase_auth.FirebaseAuth.instance.currentUser?.uid;
