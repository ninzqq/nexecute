import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexecute/loginscreen/loginscreen.dart';
import 'package:nexecute/services/auth.dart';
import 'package:provider/provider.dart';

import 'support/fake_auth_clients.dart';

void main() {
  testWidgets('Google cancellation returns quietly to the login screen', (
    tester,
  ) async {
    final google = FakeGoogleAuthClient();
    await tester.pumpWidget(_testApp(google: google));

    await tester.tap(find.text('Sign in with Google'));
    await tester.pumpAndSettle();

    expect(google.signInCount, 1);
    expect(find.byKey(const ValueKey('authentication-error')), findsNothing);
    expect(find.text('Sign in with Google'), findsOneWidget);
  });

  testWidgets('authentication failures are visible and retryable', (
    tester,
  ) async {
    final firebase =
        FakeFirebaseAuthClient()
          ..onAnonymousSignIn =
              () => Future.error(
                FirebaseAuthException(code: 'network-request-failed'),
              );
    await tester.pumpWidget(_testApp(firebase: firebase));

    await tester.tap(find.text('Continue as guest'));
    await tester.pumpAndSettle();

    expect(
      find.text('No network connection. Reconnect and try signing in again.'),
      findsOneWidget,
    );
    expect(
      tester
          .widget<ElevatedButton>(
            find.widgetWithText(ElevatedButton, 'Continue as guest'),
          )
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('both sign-in actions are disabled while one is running', (
    tester,
  ) async {
    final completion = Completer<GoogleAuthTokens?>();
    final google = FakeGoogleAuthClient()..onSignIn = () => completion.future;
    await tester.pumpWidget(_testApp(google: google));

    await tester.tap(find.text('Sign in with Google'));
    await tester.pump();

    final buttons = tester.widgetList<ElevatedButton>(
      find.byType(ElevatedButton),
    );
    expect(buttons.every((button) => button.onPressed == null), isTrue);

    completion.complete(null);
    await tester.pumpAndSettle();
  });
}

Widget _testApp({
  FakeFirebaseAuthClient? firebase,
  FakeGoogleAuthClient? google,
}) {
  return Provider<AuthService>.value(
    value: AuthService(
      firebaseAuthClient: firebase ?? FakeFirebaseAuthClient(),
      googleAuthClient: google ?? FakeGoogleAuthClient(),
    ),
    child: const MaterialApp(home: LoginScreen()),
  );
}
