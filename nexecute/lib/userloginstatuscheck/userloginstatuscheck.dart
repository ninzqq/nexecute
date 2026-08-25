import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:nexecute/home/screens/homescreen.dart';
import 'package:nexecute/loginscreen/loginscreen.dart';
import 'package:nexecute/services/services.dart';
import 'package:nexecute/shared/data_state_placeholder.dart';
import 'package:provider/provider.dart';

class UserLogInStatusCheck extends StatelessWidget {
  const UserLogInStatusCheck({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: context.read<AuthService>().userStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: DataStatePlaceholder(
              presentation: DataStatePresentation.loading,
              title: 'Checking sign-in…',
            ),
          );
        } else if (snapshot.hasError) {
          return const Scaffold(
            body: DataStatePlaceholder(
              presentation: DataStatePresentation.failure,
              title: 'Could not check sign-in status',
            ),
          );
        } else if (snapshot.hasData) {
          return const HomeScreen();
        } else {
          return const LoginScreen();
        }
      },
    );
  }
}
