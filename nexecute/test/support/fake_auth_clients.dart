import 'package:firebase_auth/firebase_auth.dart';
import 'package:nexecute/services/auth.dart';

class FakeFirebaseAuthClient implements FirebaseAuthClient {
  Stream<User?> authenticationStream = const Stream.empty();
  User? currentUserValue;
  Future<void> Function()? onAnonymousSignIn;
  Future<void> Function(GoogleAuthTokens tokens)? onGoogleSignIn;
  Future<void> Function()? onSignOut;

  int anonymousSignInCount = 0;
  int googleSignInCount = 0;
  int signOutCount = 0;
  GoogleAuthTokens? lastGoogleTokens;

  @override
  Stream<User?> authStateChanges() => authenticationStream;

  @override
  User? get currentUser => currentUserValue;

  @override
  Future<void> signInAnonymously() async {
    anonymousSignInCount += 1;
    await onAnonymousSignIn?.call();
  }

  @override
  Future<void> signInWithGoogle(GoogleAuthTokens tokens) async {
    googleSignInCount += 1;
    lastGoogleTokens = tokens;
    await onGoogleSignIn?.call(tokens);
  }

  @override
  Future<void> signOut() async {
    signOutCount += 1;
    await onSignOut?.call();
  }
}

class FakeGoogleAuthClient implements GoogleAuthClient {
  GoogleAuthTokens? signInResult;
  Future<GoogleAuthTokens?> Function()? onSignIn;
  Future<void> Function()? onSignOut;

  int signInCount = 0;
  int signOutCount = 0;

  @override
  Future<GoogleAuthTokens?> signIn() async {
    signInCount += 1;
    return await onSignIn?.call() ?? signInResult;
  }

  @override
  Future<void> signOut() async {
    signOutCount += 1;
    await onSignOut?.call();
  }
}
