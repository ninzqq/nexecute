import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:nexecute/models/data_state.dart';

class AuthService {
  AuthService({FirebaseAuth? firebaseAuth, GoogleSignIn? googleSignIn})
    : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
      _googleSignIn = googleSignIn ?? GoogleSignIn();

  final FirebaseAuth _firebaseAuth;
  final GoogleSignIn _googleSignIn;

  Stream<User?> get userStream => _firebaseAuth.authStateChanges();
  User? get user => _firebaseAuth.currentUser;

  Stream<DataState<User>> watchAuthentication() async* {
    try {
      await for (final user in userStream) {
        yield user == null
            ? const DataUnauthenticated<User>()
            : DataReady<User>(user);
      }
    } catch (error, stackTrace) {
      yield DataFailure<User>(error, stackTrace);
    }
  }

  Future<void> anonLogin() async {
    try {
      await _firebaseAuth.signInAnonymously();
    } on FirebaseAuthException {
      // handle error
    }
  }

  Future<void> signOut() async {
    final googleCurrentUser =
        _googleSignIn.currentUser ?? await _googleSignIn.signIn();
    if (googleCurrentUser != null) {
      try {
        await _googleSignIn.disconnect();
      } catch (_) {
        // Firebase sign-out should still proceed if Google disconnect fails.
      }
    }
    await _firebaseAuth.signOut();
  }

  Future<void> googleLogin() async {
    try {
      final googleUser = await _googleSignIn.signIn();

      if (googleUser == null) return;

      final googleAuth = await googleUser.authentication;
      final authCredential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      await _firebaseAuth.signInWithCredential(authCredential);
    } on FirebaseAuthException {
      // handle error
    }
  }
}
