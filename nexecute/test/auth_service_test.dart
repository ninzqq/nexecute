import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexecute/models/data_state.dart';
import 'package:nexecute/services/auth.dart';

import 'support/fake_auth_clients.dart';

void main() {
  late FakeFirebaseAuthClient firebase;
  late FakeGoogleAuthClient google;
  late AuthService service;

  setUp(() {
    firebase = FakeFirebaseAuthClient();
    google = FakeGoogleAuthClient();
    service = AuthService(
      firebaseAuthClient: firebase,
      googleAuthClient: google,
    );
  });

  test(
    'restores authentication state from the Firebase session stream',
    () async {
      final restoredUser = _FakeUser();
      firebase.authenticationStream = Stream.fromIterable([null, restoredUser]);

      final states = await service.watchAuthentication().toList();

      expect(states.first, isA<DataUnauthenticated<User>>());
      expect(states.last, isA<DataReady<User>>());
      expect((states.last as DataReady<User>).value, same(restoredUser));
    },
  );

  test('exposes authentication stream failures', () async {
    final failure = StateError('session unavailable');
    firebase.authenticationStream = Stream.error(failure);

    final states = await service.watchAuthentication().toList();

    expect(states, hasLength(1));
    expect(states.single, isA<DataFailure<User>>());
    expect((states.single as DataFailure<User>).error, same(failure));
  });

  test('forwards Google tokens to Firebase', () async {
    const tokens = GoogleAuthTokens(
      accessToken: 'access-token',
      idToken: 'id-token',
    );
    google.signInResult = tokens;

    final result = await service.googleLogin();

    expect(result, AuthAttemptResult.signedIn);
    expect(firebase.googleSignInCount, 1);
    expect(firebase.lastGoogleTokens, same(tokens));
  });

  test('treats a dismissed Google account chooser as cancellation', () async {
    final result = await service.googleLogin();

    expect(result, AuthAttemptResult.cancelled);
    expect(firebase.googleSignInCount, 0);
  });

  test('propagates Google and Firebase authentication failures', () async {
    final googleFailure = StateError('Google unavailable');
    google.onSignIn = () => Future.error(googleFailure);

    await expectLater(service.googleLogin(), throwsA(same(googleFailure)));

    google.onSignIn = null;
    google.signInResult = const GoogleAuthTokens(idToken: 'id-token');
    final firebaseFailure = StateError('Firebase rejected credential');
    firebase.onGoogleSignIn = (_) => Future.error(firebaseFailure);

    await expectLater(service.googleLogin(), throwsA(same(firebaseFailure)));
  });

  test('propagates anonymous authentication failures', () async {
    final failure = StateError('anonymous auth unavailable');
    firebase.onAnonymousSignIn = () => Future.error(failure);

    await expectLater(service.anonLogin(), throwsA(same(failure)));
  });

  test('signs out without opening an interactive Google flow', () async {
    await service.signOut();

    expect(google.signInCount, 0);
    expect(google.signOutCount, 1);
    expect(firebase.signOutCount, 1);
  });

  test('Firebase sign-out continues when Google sign-out fails', () async {
    google.onSignOut = () => Future.error(StateError('stale provider session'));

    await service.signOut();

    expect(firebase.signOutCount, 1);
  });
}

class _FakeUser extends Fake implements User {}
