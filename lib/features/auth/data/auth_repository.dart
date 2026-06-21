import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../../core/bootstrap/app_bootstrap.dart';

/// Firebase Auth; Supabase recebe o JWT via [AppBootstrap] `accessToken`.
class AuthRepository {
  AuthRepository({firebase_auth.FirebaseAuth? firebaseAuth})
      : _firebaseAuth = firebaseAuth ?? firebase_auth.FirebaseAuth.instance;

  final firebase_auth.FirebaseAuth _firebaseAuth;

  firebase_auth.User? get currentFirebaseUser => _firebaseAuth.currentUser;

  Stream<firebase_auth.User?> get firebaseAuthStateChanges =>
      _firebaseAuth.authStateChanges();

  /// Atualiza o ID token (ex.: após login) para o Supabase usar nas próximas queries.
  Future<void> refreshFirebaseIdToken({bool forceRefresh = true}) async {
    final user = _firebaseAuth.currentUser;
    if (user == null) return;
    final token = await user.getIdToken(forceRefresh);
    if (token == null || token.isEmpty) {
      throw StateError('Firebase não retornou idToken.');
    }
  }

  Future<firebase_auth.UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    final credential = await _firebaseAuth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final user = credential.user;
    if (user == null) {
      throw StateError('Login concluído sem usuário Firebase.');
    }
    await refreshFirebaseIdToken();
    return credential;
  }

  Future<firebase_auth.UserCredential> registerWithEmailAndPassword({
    required String email,
    required String password,
    required String displayName,
  }) async {
    final credential = await _firebaseAuth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    var user = credential.user;
    if (user == null) {
      throw StateError('Cadastro concluído sem usuário Firebase.');
    }

    final trimmedName = displayName.trim();
    if (trimmedName.isNotEmpty) {
      await user.updateProfile(displayName: trimmedName);
      await user.reload();
      user = _firebaseAuth.currentUser ?? user;
    }

    await refreshFirebaseIdToken();
    return credential;
  }

  Future<firebase_auth.UserCredential> signInWithGoogle() async {
    await AppBootstrap.ensureGoogleSignInInitialized();
    if (!GoogleSignIn.instance.supportsAuthenticate()) {
      throw UnsupportedError(
        'Google Sign-In interativo não suportado nesta plataforma.',
      );
    }

    final account = await GoogleSignIn.instance.authenticate();
    final idToken = account.authentication.idToken;
    if (idToken == null || idToken.isEmpty) {
      throw StateError('Google Sign-In não retornou idToken.');
    }

    final credential =
        firebase_auth.GoogleAuthProvider.credential(idToken: idToken);
    final userCredential = await _firebaseAuth.signInWithCredential(credential);
    var user = userCredential.user;
    if (user == null) {
      throw StateError('Login Google concluído sem usuário Firebase.');
    }

    final googleName = account.displayName?.trim();
    final googlePhoto = account.photoUrl?.trim();
    final needsProfileUpdate =
        (googleName?.isNotEmpty == true && (user.displayName?.trim().isEmpty ?? true)) ||
        (googlePhoto?.isNotEmpty == true && (user.photoURL?.trim().isEmpty ?? true));

    if (needsProfileUpdate) {
      await user.updateProfile(
        displayName: (user.displayName?.trim().isNotEmpty == true)
            ? user.displayName
            : googleName,
        photoURL: (user.photoURL?.trim().isNotEmpty == true)
            ? user.photoURL
            : googlePhoto,
      );
      await user.reload();
      user = _firebaseAuth.currentUser ?? user;
    }

    await refreshFirebaseIdToken();
    return userCredential;
  }

  Future<void> sendPasswordResetEmail(String email) async {
    await _firebaseAuth.sendPasswordResetEmail(email: email.trim());
  }

  Future<void> updateProfilePhoto({String? photoUrl}) async {
    final user = _firebaseAuth.currentUser;
    if (user == null) {
      throw StateError('Usuário não autenticado no Firebase.');
    }
    await user.updateProfile(photoURL: photoUrl);
    await user.reload();
    await refreshFirebaseIdToken();
  }

  Future<void> signOut() async {
    try {
      await GoogleSignIn.instance.signOut();
    } catch (e, st) {
      debugPrint('AuthRepository.signOut Google: $e\n$st');
    }
    await _firebaseAuth.signOut();
  }

  Future<void> restoreSessionIfNeeded() async {
    await refreshFirebaseIdToken(forceRefresh: false);
  }
}
