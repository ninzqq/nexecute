import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:nexecute/models/data_state.dart';

enum AuthAttemptResult { signedIn, cancelled }

final class GoogleAuthTokens {
  const GoogleAuthTokens({this.accessToken, this.idToken});

  final String? accessToken;
  final String? idToken;
}

abstract interface class FirebaseAuthClient {
  Stream<User?> authStateChanges();

  User? get currentUser;

  Future<void> signInAnonymously();

  Future<void> signInWithGoogle(GoogleAuthTokens tokens);

  Future<void> signOut();
}

abstract interface class GoogleAuthClient {
  Future<GoogleAuthTokens?> signIn();

  Future<void> signOut();
}

final class DefaultFirebaseAuthClient implements FirebaseAuthClient {
  DefaultFirebaseAuthClient(this._firebaseAuth);

  final FirebaseAuth _firebaseAuth;

  @override
  Stream<User?> authStateChanges() => _firebaseAuth.authStateChanges();

  @override
  User? get currentUser => _firebaseAuth.currentUser;

  @override
  Future<void> signInAnonymously() async {
    await _firebaseAuth.signInAnonymously();
  }

  @override
  Future<void> signInWithGoogle(GoogleAuthTokens tokens) async {
    final credential = GoogleAuthProvider.credential(
      accessToken: tokens.accessToken,
      idToken: tokens.idToken,
    );
    await _firebaseAuth.signInWithCredential(credential);
  }

  @override
  Future<void> signOut() => _firebaseAuth.signOut();
}

final class DefaultGoogleAuthClient implements GoogleAuthClient {
  DefaultGoogleAuthClient(this._googleSignIn);

  final GoogleSignIn _googleSignIn;

  @override
  Future<GoogleAuthTokens?> signIn() async {
    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) return null;

    final authentication = await googleUser.authentication;
    return GoogleAuthTokens(
      accessToken: authentication.accessToken,
      idToken: authentication.idToken,
    );
  }

  @override
  Future<void> signOut() => _googleSignIn.signOut();
}

class AuthService {
  AuthService({
    FirebaseAuth? firebaseAuth,
    GoogleSignIn? googleSignIn,
    FirebaseAuthClient? firebaseAuthClient,
    GoogleAuthClient? googleAuthClient,
  }) : assert(firebaseAuth == null || firebaseAuthClient == null),
       assert(googleSignIn == null || googleAuthClient == null),
       _firebaseAuth =
           firebaseAuthClient ??
           DefaultFirebaseAuthClient(firebaseAuth ?? FirebaseAuth.instance),
       _googleAuth =
           googleAuthClient ??
           DefaultGoogleAuthClient(googleSignIn ?? GoogleSignIn());

  final FirebaseAuthClient _firebaseAuth;
  final GoogleAuthClient _googleAuth;

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

  Future<AuthAttemptResult> anonLogin() async {
    await _firebaseAuth.signInAnonymously();
    return AuthAttemptResult.signedIn;
  }

  Future<void> signOut() async {
    try {
      await _googleAuth.signOut();
    } catch (_) {
      // Firebase sign-out must still proceed if the provider session is stale.
    }
    await _firebaseAuth.signOut();
  }

  Future<AuthAttemptResult> googleLogin() async {
    final tokens = await _googleAuth.signIn();
    if (tokens == null) return AuthAttemptResult.cancelled;

    await _firebaseAuth.signInWithGoogle(tokens);
    return AuthAttemptResult.signedIn;
  }
}
