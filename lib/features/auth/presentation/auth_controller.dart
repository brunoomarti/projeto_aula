import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthException;

import '../../../core/services/connectivity_service.dart';
import '../../../core/services/local_data_migration.dart';
import '../../profile/data/profile_local_cache.dart';
import '../../profile/data/profile_repository.dart';
import '../../profile/data/profile_supabase_repository.dart';
import '../data/auth_repository.dart';

enum AuthStatus {
  unknown,
  authenticated,
  unauthenticated,
  guest,
}

/// Estado global de autenticação e perfil na nuvem.
class AuthController extends ChangeNotifier {
  AuthController({
    AuthRepository? authRepository,
    ProfileRepository? profileRepository,
    required LocalDataMigration migration,
    ProfileLocalCache? profileCache,
    ConnectivityService? connectivity,
  })  : _auth = authRepository ?? AuthRepository(),
        _profileRepo = profileRepository ?? ProfileSupabaseRepository(),
        _migration = migration,
        _profileCache = profileCache ?? ProfileLocalCache(),
        _connectivity = connectivity ?? ConnectivityService() {
    _connectivitySub = _connectivity.onStatusChange.listen((online) {
      if (online && isAuthenticated) {
        unawaited(_syncProfileWithCloud());
      }
    });
  }

  final AuthRepository _auth;
  final ProfileRepository _profileRepo;
  final LocalDataMigration _migration;
  final ProfileLocalCache _profileCache;
  final ConnectivityService _connectivity;

  StreamSubscription<firebase_auth.User?>? _authSub;
  StreamSubscription<bool>? _connectivitySub;

  AuthStatus _status = AuthStatus.unknown;
  bool _busy = false;
  String? _errorMessage;
  UserProfile? _userProfile;

  AuthStatus get status => _status;
  bool get isBusy => _busy;
  String? get errorMessage => _errorMessage;
  UserProfile? get profile => _userProfile;
  firebase_auth.User? get firebaseUser => _auth.currentFirebaseUser;

  bool get isAuthenticated => _status == AuthStatus.authenticated;

  bool get isGuest => _status == AuthStatus.guest;

  /// Pode usar a home (logado ou visitante local).
  bool get canUseApp => isAuthenticated || isGuest;

  String get displayName {
    if (isGuest) return 'Visitante';
    return _userProfile?.effectiveDisplayName ?? 'Usuário';
  }

  String? get avatarUrl {
    if (isGuest) return null;
    final url = _userProfile?.avatarUrl?.trim();
    return (url != null && url.isNotEmpty) ? url : null;
  }

  Future<void> initialize() async {
    _authSub = _auth.firebaseAuthStateChanges.listen(_handleAuthChange);

    final user = _auth.currentFirebaseUser;
    if (user == null) {
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return;
    }

    // Sessão Firebase em cache → autenticado de imediato (funciona offline).
    // A restauração (token/perfil/migração) roda em background via listener.
    _status = AuthStatus.authenticated;
    notifyListeners();
  }

  Future<void> _handleAuthChange(firebase_auth.User? user) async {
    if (user == null) {
      if (_status == AuthStatus.guest) return;
      _userProfile = null;
      _status = AuthStatus.unauthenticated;
      _errorMessage = null;
      notifyListeners();
      return;
    }
    await _onSignedIn(user);
  }

  Future<void> _onSignedIn(firebase_auth.User user) async {
    // Já há sessão Firebase: considera autenticado mesmo antes da nuvem.
    _status = AuthStatus.authenticated;
    _errorMessage = null;

    // 1) Mostra o perfil em cache imediatamente (instantâneo / offline).
    final cached = await _profileCache.read();
    if (cached != null && cached.id == user.uid) {
      _userProfile = cached;
    }
    notifyListeners();

    // 2) Sincroniza com a nuvem em background.
    try {
      await _auth.refreshFirebaseIdToken();
      await _flushPendingProfile();
      await user.reload();
      final freshUser = _auth.currentFirebaseUser ?? user;
      final fresh = await _profileRepo.ensureProfile(freshUser);
      _userProfile = fresh;
      await _profileCache.write(fresh);
      await _migration.runIfNeeded();
      notifyListeners();
    } catch (e, st) {
      debugPrint('AuthController._onSignedIn: $e\n$st');
      if (_isAuthError(e)) {
        // Credencial inválida/revogada: desloga de fato.
        _errorMessage = _mapError(e);
        _status = AuthStatus.unauthenticated;
        await _auth.signOut();
        notifyListeners();
      } else {
        // Offline / erro de rede: segue autenticado com o que houver em cache.
        debugPrint('AuthController: seguindo offline com sessão em cache.');
      }
    }
  }

  /// Envia ao Supabase um nome editado offline (se houver pendência).
  Future<void> _flushPendingProfile() async {
    if (!await _profileCache.isDirty()) return;
    final cached = await _profileCache.read();
    final name = cached?.displayName;
    if (name == null || name.trim().isEmpty) return;
    await _profileRepo.updateDisplayName(name);
    if (cached != null) await _profileCache.write(cached, dirty: false);
  }

  /// Disparado ao reconectar: envia pendências e atualiza o cache.
  Future<void> _syncProfileWithCloud() async {
    try {
      await _flushPendingProfile();
      final fresh = await _profileRepo.fetchCurrent();
      if (fresh != null) {
        _userProfile = fresh;
        await _profileCache.write(fresh);
        notifyListeners();
      }
    } catch (e, st) {
      debugPrint('AuthController._syncProfileWithCloud: $e\n$st');
    }
  }

  /// `true` quando o erro indica credencial inválida/revogada (deve deslogar),
  /// em oposição a falhas de rede (offline) que devem ser toleradas.
  bool _isAuthError(Object e) {
    if (e is firebase_auth.FirebaseAuthException) {
      const authCodes = {
        'user-disabled',
        'user-not-found',
        'user-token-expired',
        'invalid-user-token',
        'user-mismatch',
        'requires-recent-login',
        'invalid-credential',
      };
      return authCodes.contains(e.code);
    }
    if (e is AuthException) return true;
    return false;
  }

  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {
    await _runAuthAction(() async {
      final cred = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      final user = cred.user;
      if (user != null) {
        _userProfile = await _profileRepo.ensureProfile(user);
        await _profileCache.write(_userProfile!);
        await _migration.runIfNeeded();
      }
    });
  }

  Future<void> registerWithEmail({
    required String email,
    required String password,
    required String displayName,
  }) async {
    await _runAuthAction(() async {
      final cred = await _auth.registerWithEmailAndPassword(
        email: email,
        password: password,
        displayName: displayName,
      );
      final user = cred.user ?? _auth.currentFirebaseUser;
      if (user != null) {
        _userProfile = await _profileRepo.ensureProfile(user);
        await _profileCache.write(_userProfile!);
        await _migration.runIfNeeded();
      }
    });
  }

  Future<void> signInWithGoogle() async {
    await _runAuthAction(() async {
      final cred = await _auth.signInWithGoogle();
      final user = cred.user ?? _auth.currentFirebaseUser;
      if (user != null) {
        await user.reload();
        final freshUser = _auth.currentFirebaseUser ?? user;
        _userProfile = await _profileRepo.ensureProfile(freshUser);
        await _profileCache.write(_userProfile!);
        await _migration.runIfNeeded();
      }
    });
  }

  Future<void> sendPasswordReset(String email) async {
    await _runAuthAction(() => _auth.sendPasswordResetEmail(email));
  }

  /// Entra no app sem conta — tarefas só locais, sem sync na nuvem.
  void continueWithoutLogin() {
    _status = AuthStatus.guest;
    _errorMessage = null;
    notifyListeners();
  }

  /// Sai do modo visitante e volta para a tela de login.
  Future<void> exitGuestMode() async {
    _status = AuthStatus.unauthenticated;
    _errorMessage = null;
    notifyListeners();
  }

  Future<void> signOut() async {
    if (_status == AuthStatus.guest) {
      await exitGuestMode();
      return;
    }
    await _auth.signOut();
    await _profileCache.clear();
    _userProfile = null;
    _status = AuthStatus.unauthenticated;
    notifyListeners();
  }

  /// Carrega o perfil do cache (instantâneo) e atualiza da nuvem, se online.
  Future<void> reloadProfile() async {
    final cached = await _profileCache.read();
    if (cached != null) {
      _userProfile = cached;
      notifyListeners();
    }

    // Mantém edição local pendente; só busca da nuvem se não há pendência.
    if (await _profileCache.isDirty()) {
      unawaited(_syncProfileWithCloud());
      return;
    }

    if (!await _connectivity.isOnline()) return;
    try {
      final fresh = await _profileRepo.fetchCurrent();
      if (fresh != null) {
        _userProfile = fresh;
        await _profileCache.write(fresh);
        notifyListeners();
      }
    } catch (e, st) {
      debugPrint('AuthController.reloadProfile: $e\n$st');
    }
  }

  /// Atualiza o nome de forma otimista (cache imediato) e envia à nuvem.
  /// Offline, fica pendente e sincroniza ao reconectar.
  Future<void> updateDisplayName(String name) async {
    final trimmed = name.trim();
    final base = _userProfile ??
        UserProfile(
          id: _auth.currentFirebaseUser?.uid ?? '',
          email: _auth.currentFirebaseUser?.email,
        );
    final updated = base.copyWith(displayName: trimmed);

    _userProfile = updated;
    await _profileCache.write(updated, dirty: true);
    notifyListeners();

    try {
      await _profileRepo.updateDisplayName(trimmed);
      await _profileCache.write(updated);
    } catch (e, st) {
      debugPrint('AuthController.updateDisplayName: $e\n$st');
      // Offline / erro de rede: mantém pendente (já salvo no cache).
    }
  }

  /// Envia foto para o Supabase Storage e atualiza perfil + Firebase.
  Future<void> updateAvatar(Uint8List bytes) async {
    final url = await _profileRepo.uploadAvatar(bytes);
    await _applyAvatarUrl(url);
  }

  Future<void> _applyAvatarUrl(String url) async {
    final trimmed = url.trim();
    final base = _userProfile ??
        UserProfile(
          id: _auth.currentFirebaseUser?.uid ?? '',
          email: _auth.currentFirebaseUser?.email,
        );
    final updated = base.copyWith(avatarUrl: trimmed);

    _userProfile = updated;
    await _profileCache.write(updated, dirty: true);
    notifyListeners();

    try {
      await _profileRepo.updateAvatarUrl(trimmed);
      await _auth.updateProfilePhoto(photoUrl: trimmed);
      await _profileCache.write(updated);
    } catch (e, st) {
      debugPrint('AuthController.updateAvatar: $e\n$st');
    }
  }

  /// Salva nome e/ou foto escolhida na tela de edição de perfil.
  Future<void> updateProfileDetails({
    required String displayName,
    Uint8List? avatarBytes,
  }) async {
    await updateDisplayName(displayName);
    if (avatarBytes != null) {
      await updateAvatar(avatarBytes);
    }
  }

  Future<void> _runAuthAction(Future<void> Function() action) async {
    _busy = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await action();
      if (_auth.currentFirebaseUser != null) {
        _status = AuthStatus.authenticated;
      }
    } catch (e, st) {
      debugPrint('AuthController: $e\n$st');
      _errorMessage = _mapError(e);
      rethrow;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  String _mapError(Object e) {
    if (e is firebase_auth.FirebaseAuthException) {
      switch (e.code) {
        case 'invalid-email':
          return 'E-mail inválido.';
        case 'user-disabled':
          return 'Esta conta foi desativada.';
        case 'user-not-found':
        case 'wrong-password':
        case 'invalid-credential':
          return 'E-mail ou senha incorretos.';
        case 'email-already-in-use':
          return 'Este e-mail já está cadastrado.';
        case 'weak-password':
          return 'Senha muito fraca (mínimo 6 caracteres).';
        case 'too-many-requests':
          return 'Muitas tentativas. Tente novamente mais tarde.';
        default:
          return e.message ?? 'Erro de autenticação (${e.code}).';
      }
    }
    if (e is AuthException) {
      return e.message;
    }
    return e.toString();
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _connectivitySub?.cancel();
    super.dispose();
  }
}
