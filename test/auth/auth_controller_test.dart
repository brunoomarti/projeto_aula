import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mock_exceptions/mock_exceptions.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:tasker_project/core/services/connectivity_service.dart';
import 'package:tasker_project/features/auth/data/auth_repository.dart';
import 'package:tasker_project/features/auth/presentation/auth_controller.dart';
import 'package:tasker_project/features/profile/data/profile_local_cache.dart';

import 'fake_repositories.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeProfileRepository profileRepo;
  late FakeTaskRepository taskRepo;
  late NoOpLocalDataMigration migration;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    profileRepo = FakeProfileRepository();
    taskRepo = FakeTaskRepository();
    migration = NoOpLocalDataMigration(
      taskRepository: taskRepo,
      profileRepository: profileRepo,
    );
  });

  AuthController buildController({
    required firebase_auth.FirebaseAuth firebaseAuth,
    ConnectivityService? connectivity,
  }) {
    return AuthController(
      authRepository: AuthRepository(firebaseAuth: firebaseAuth),
      profileRepository: profileRepo,
      migration: migration,
      profileCache: ProfileLocalCache(),
      connectivity: connectivity,
    );
  }

  group('AuthController', () {
    test('initialize sem usuário deixa status unauthenticated', () async {
      final auth = MockFirebaseAuth(signedIn: false);
      final controller = buildController(firebaseAuth: auth);

      await controller.initialize();

      expect(controller.status, AuthStatus.unauthenticated);
      expect(controller.isAuthenticated, isFalse);
      expect(controller.canUseApp, isFalse);
    });

    test('initialize com sessão Firebase deixa status authenticated', () async {
      final auth = MockFirebaseAuth(
        signedIn: true,
        mockUser: MockUser(uid: 'uid-1', email: 'user@test.com'),
      );
      final controller = buildController(firebaseAuth: auth);

      await controller.initialize();
      await Future<void>.delayed(Duration.zero);

      expect(controller.status, AuthStatus.authenticated);
      expect(controller.isAuthenticated, isTrue);
      expect(controller.firebaseUser?.uid, 'uid-1');
    });

    test('signInWithEmail autentica e cria perfil na nuvem', () async {
      final auth = MockFirebaseAuth(
        signedIn: false,
        mockUser: MockUser(uid: 'uid-login', email: 'login@test.com'),
      );
      final controller = buildController(firebaseAuth: auth);
      await controller.initialize();

      await controller.signInWithEmail(
        email: 'login@test.com',
        password: 'secret12',
      );

      expect(controller.isAuthenticated, isTrue);
      expect(controller.isBusy, isFalse);
      expect(profileRepo.ensureProfileCalls, greaterThanOrEqualTo(1));
      expect(controller.profile?.id, 'uid-login');
      expect(controller.displayName, isNotEmpty);
    });

    test('registerWithEmail cadastra usuário e perfil', () async {
      final auth = MockFirebaseAuth(signedIn: false);
      final controller = buildController(firebaseAuth: auth);
      await controller.initialize();

      await controller.registerWithEmail(
        email: 'new@test.com',
        password: 'secret12',
        displayName: 'João Silva',
      );

      expect(controller.isAuthenticated, isTrue);
      expect(profileRepo.ensureProfileCalls, greaterThanOrEqualTo(1));
      expect(auth.currentUser?.email, 'new@test.com');
    });

    test('sendPasswordReset conclui sem erro', () async {
      final auth = MockFirebaseAuth(signedIn: false);
      final controller = buildController(firebaseAuth: auth);
      await controller.initialize();

      await expectLater(
        controller.sendPasswordReset('reset@test.com'),
        completes,
      );
      expect(controller.isBusy, isFalse);
    });

    test('signInWithEmail com credencial inválida expõe mensagem amigável', () async {
      final auth = MockFirebaseAuth(signedIn: false);
      whenCalling(Invocation.method(#signInWithEmailAndPassword, null))
          .on(auth)
          .thenThrow(firebase_auth.FirebaseAuthException(code: 'wrong-password'));
      final controller = buildController(firebaseAuth: auth);
      await controller.initialize();

      await expectLater(
        controller.signInWithEmail(
          email: 'user@test.com',
          password: 'errada',
        ),
        throwsA(isA<firebase_auth.FirebaseAuthException>()),
      );

      expect(controller.errorMessage, 'E-mail ou senha incorretos.');
      expect(controller.isAuthenticated, isFalse);
    });

    test('registerWithEmail com e-mail em uso expõe mensagem amigável', () async {
      final auth = MockFirebaseAuth(signedIn: false);
      whenCalling(Invocation.method(#createUserWithEmailAndPassword, null))
          .on(auth)
          .thenThrow(
            firebase_auth.FirebaseAuthException(code: 'email-already-in-use'),
          );
      final controller = buildController(firebaseAuth: auth);
      await controller.initialize();

      await expectLater(
        controller.registerWithEmail(
          email: 'dup@test.com',
          password: 'secret12',
          displayName: 'Ana Costa',
        ),
        throwsA(isA<firebase_auth.FirebaseAuthException>()),
      );

      expect(controller.errorMessage, 'Este e-mail já está cadastrado.');
    });

    test('continueWithoutLogin entra em modo visitante', () async {
      final auth = MockFirebaseAuth(signedIn: false);
      final controller = buildController(firebaseAuth: auth);
      await controller.initialize();

      controller.continueWithoutLogin();

      expect(controller.status, AuthStatus.guest);
      expect(controller.isGuest, isTrue);
      expect(controller.canUseApp, isTrue);
      expect(controller.displayName, 'Visitante');
      expect(controller.avatarUrl, isNull);
    });

    test('signOut encerra sessão Firebase e limpa perfil', () async {
      final auth = MockFirebaseAuth(
        signedIn: true,
        mockUser: MockUser(uid: 'uid-1', email: 'user@test.com'),
      );
      final controller = buildController(firebaseAuth: auth);
      await controller.initialize();
      await controller.signInWithEmail(
        email: 'user@test.com',
        password: 'secret12',
      );

      await controller.signOut();

      expect(controller.status, AuthStatus.unauthenticated);
      expect(controller.profile, isNull);
      expect(auth.currentUser, isNull);
    });

    test('signOut no modo visitante volta ao login', () async {
      final auth = MockFirebaseAuth(signedIn: false);
      final controller = buildController(firebaseAuth: auth);
      await controller.initialize();
      controller.continueWithoutLogin();

      await controller.signOut();

      expect(controller.status, AuthStatus.unauthenticated);
      expect(controller.isGuest, isFalse);
    });

    test('exitGuestMode restaura tela de login', () async {
      final auth = MockFirebaseAuth(signedIn: false);
      final controller = buildController(firebaseAuth: auth);
      await controller.initialize();
      controller.continueWithoutLogin();

      await controller.exitGuestMode();

      expect(controller.status, AuthStatus.unauthenticated);
    });
  });
}
