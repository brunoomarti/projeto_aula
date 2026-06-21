import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:tasker_project/features/auth/data/auth_repository.dart';

class _MockFirebaseAuth extends Mock implements firebase_auth.FirebaseAuth {}

class _MockUser extends Mock implements firebase_auth.User {}

class _MockUserCredential extends Mock implements firebase_auth.UserCredential {}

void main() {
  group('AuthRepository', () {
    test('currentFirebaseUser reflete o usuário do FirebaseAuth', () {
      final user = MockUser(uid: 'uid-1', email: 'a@b.com');
      final auth = MockFirebaseAuth(mockUser: user, signedIn: true);
      final repo = AuthRepository(firebaseAuth: auth);

      expect(repo.currentFirebaseUser?.uid, 'uid-1');
      expect(repo.currentFirebaseUser?.email, 'a@b.com');
    });

    test('signInWithEmailAndPassword autentica e atualiza idToken', () async {
      final auth = MockFirebaseAuth(
        signedIn: false,
        mockUser: MockUser(uid: 'uid-login', email: 'user@test.com'),
      );
      final repo = AuthRepository(firebaseAuth: auth);

      final credential = await repo.signInWithEmailAndPassword(
        email: '  user@test.com  ',
        password: 'secret12',
      );

      expect(credential.user, isNotNull);
      expect(auth.currentUser, isNotNull);
      expect(auth.currentUser!.uid, 'uid-login');
    });

    test('registerWithEmailAndPassword cria usuário com displayName', () async {
      final auth = MockFirebaseAuth(signedIn: false);
      final repo = AuthRepository(firebaseAuth: auth);

      final credential = await repo.registerWithEmailAndPassword(
        email: 'new@test.com',
        password: 'secret12',
        displayName: 'Maria Silva',
      );

      expect(credential.user, isNotNull);
      expect(auth.currentUser?.displayName, 'Maria Silva');
    });

    test('sendPasswordResetEmail envia e-mail trimado', () async {
      final auth = MockFirebaseAuth(signedIn: false);
      final repo = AuthRepository(firebaseAuth: auth);

      await expectLater(
        repo.sendPasswordResetEmail('  reset@test.com  '),
        completes,
      );
    });

    test('signOut encerra sessão Firebase', () async {
      final auth = MockFirebaseAuth(
        signedIn: true,
        mockUser: MockUser(uid: 'uid-1', email: 'a@b.com'),
      );
      final repo = AuthRepository(firebaseAuth: auth);

      await repo.signOut();

      expect(auth.currentUser, isNull);
    });

    test('refreshFirebaseIdToken ignora quando não há usuário', () async {
      final auth = MockFirebaseAuth(signedIn: false);
      final repo = AuthRepository(firebaseAuth: auth);

      await expectLater(repo.refreshFirebaseIdToken(), completes);
    });

    test('refreshFirebaseIdToken obtém token quando usuário logado', () async {
      final auth = MockFirebaseAuth(
        signedIn: true,
        mockUser: MockUser(uid: 'uid-1', email: 'a@b.com'),
      );
      final repo = AuthRepository(firebaseAuth: auth);

      await expectLater(repo.refreshFirebaseIdToken(), completes);
    });

    test('updateProfilePhoto falha sem usuário autenticado', () async {
      final auth = MockFirebaseAuth(signedIn: false);
      final repo = AuthRepository(firebaseAuth: auth);

      expect(
        () => repo.updateProfilePhoto(photoUrl: 'https://x.com/p.jpg'),
        throwsA(isA<StateError>()),
      );
    });

    test('updateProfilePhoto atualiza photoURL do usuário logado', () async {
      final user = MockUser(uid: 'uid-1', email: 'a@b.com');
      final auth = MockFirebaseAuth(mockUser: user, signedIn: true);
      final repo = AuthRepository(firebaseAuth: auth);

      await repo.updateProfilePhoto(photoUrl: 'https://cdn.test/avatar.jpg');

      expect(auth.currentUser?.photoURL, 'https://cdn.test/avatar.jpg');
    });

    test('restoreSessionIfNeeded renova token sem forçar refresh', () async {
      final auth = MockFirebaseAuth(
        signedIn: true,
        mockUser: MockUser(uid: 'uid-1', email: 'a@b.com'),
      );
      final repo = AuthRepository(firebaseAuth: auth);

      await expectLater(repo.restoreSessionIfNeeded(), completes);
    });

    test('signInWithEmailAndPassword falha se Firebase não retorna usuário', () async {
      final mockAuth = _MockFirebaseAuth();
      final mockCredential = _MockUserCredential();

      when(() => mockAuth.signInWithEmailAndPassword(
            email: any(named: 'email'),
            password: any(named: 'password'),
          )).thenAnswer((_) async => mockCredential);
      when(() => mockCredential.user).thenReturn(null);

      final repo = AuthRepository(firebaseAuth: mockAuth);

      expect(
        () => repo.signInWithEmailAndPassword(
          email: 'x@test.com',
          password: '123456',
        ),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            'Login concluído sem usuário Firebase.',
          ),
        ),
      );
    });

    test('registerWithEmailAndPassword falha se Firebase não retorna usuário', () async {
      final mockAuth = _MockFirebaseAuth();
      final mockCredential = _MockUserCredential();

      when(() => mockAuth.createUserWithEmailAndPassword(
            email: any(named: 'email'),
            password: any(named: 'password'),
          )).thenAnswer((_) async => mockCredential);
      when(() => mockCredential.user).thenReturn(null);

      final repo = AuthRepository(firebaseAuth: mockAuth);

      expect(
        () => repo.registerWithEmailAndPassword(
          email: 'x@test.com',
          password: '123456',
          displayName: 'Test User',
        ),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            'Cadastro concluído sem usuário Firebase.',
          ),
        ),
      );
    });

    test('firebaseAuthStateChanges emite mudanças de sessão', () async {
      final auth = MockFirebaseAuth(signedIn: false);
      final repo = AuthRepository(firebaseAuth: auth);

      final states = <firebase_auth.User?>[];
      final sub = repo.firebaseAuthStateChanges.listen(states.add);

      await auth.signInWithEmailAndPassword(
        email: 'stream@test.com',
        password: 'secret12',
      );
      await Future<void>.delayed(Duration.zero);

      expect(states.any((u) => u != null), isTrue);

      await sub.cancel();
    });
  });
}
