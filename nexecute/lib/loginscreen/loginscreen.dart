import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:nexecute/services/auth.dart';
import 'package:provider/provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isAuthenticating = false;
  String? _errorMessage;

  Future<void> _authenticate(
    Future<AuthAttemptResult> Function() loginMethod,
  ) async {
    if (_isAuthenticating) return;

    setState(() {
      _isAuthenticating = true;
      _errorMessage = null;
    });

    try {
      await loginMethod();
    } on FirebaseAuthException catch (error) {
      if (mounted) {
        setState(() => _errorMessage = _firebaseErrorMessage(error.code));
      }
    } catch (_) {
      if (mounted) {
        setState(
          () =>
              _errorMessage =
                  'Sign-in could not be completed. Check your connection and try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _isAuthenticating = false);
    }
  }

  String _firebaseErrorMessage(String code) => switch (code) {
    'network-request-failed' =>
      'No network connection. Reconnect and try signing in again.',
    'operation-not-allowed' =>
      'This sign-in method is not enabled for Nexecute.',
    'user-disabled' => 'This account has been disabled.',
    _ => 'Sign-in failed. Please try again.',
  };

  @override
  Widget build(BuildContext context) {
    final authService = context.read<AuthService>();
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Padding(
              padding: const EdgeInsets.all(40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  const FlutterLogo(size: 150),
                  if (_errorMessage case final message?)
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        message,
                        key: const ValueKey('authentication-error'),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  Flexible(
                    child: LoginButton(
                      icon: Icons.account_circle_rounded,
                      text: 'Sign in with Google',
                      loginMethod: authService.googleLogin,
                      color: Colors.blue,
                      isAuthenticating: _isAuthenticating,
                      onAuthenticate: _authenticate,
                    ),
                  ),
                  Flexible(
                    child: LoginButton(
                      icon: Icons.account_box,
                      text: 'Continue as guest',
                      loginMethod: authService.anonLogin,
                      color: Colors.deepPurple,
                      isAuthenticating: _isAuthenticating,
                      onAuthenticate: _authenticate,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class LoginButton extends StatelessWidget {
  const LoginButton({
    super.key,
    required this.text,
    required this.icon,
    required this.color,
    required this.loginMethod,
    required this.isAuthenticating,
    required this.onAuthenticate,
  });

  final Color color;
  final IconData icon;
  final String text;
  final Future<AuthAttemptResult> Function() loginMethod;
  final bool isAuthenticating;
  final Future<void> Function(Future<AuthAttemptResult> Function())
  onAuthenticate;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(5),
      child: ElevatedButton.icon(
        label: Text(text),
        icon: Icon(icon, color: Colors.white, size: 20),
        style: TextButton.styleFrom(
          padding: const EdgeInsets.all(24),
          backgroundColor: color,
        ),
        onPressed: isAuthenticating ? null : () => onAuthenticate(loginMethod),
      ),
    );
  }
}
