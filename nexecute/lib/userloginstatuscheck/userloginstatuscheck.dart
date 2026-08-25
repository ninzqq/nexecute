import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:nexecute/home/screens/homescreen.dart';
import 'package:nexecute/loginscreen/loginscreen.dart';
import 'package:nexecute/models/data_state.dart';
import 'package:nexecute/shared/data_state_placeholder.dart';
import 'package:provider/provider.dart';

class UserLogInStatusCheck extends StatelessWidget {
  const UserLogInStatusCheck({super.key});

  @override
  Widget build(BuildContext context) {
    return switch (context.watch<DataState<User>>()) {
      DataLoading<User>() => const Scaffold(
        body: DataStatePlaceholder(
          presentation: DataStatePresentation.loading,
          title: 'Checking sign-in…',
        ),
      ),
      DataFailure<User>() => const Scaffold(
        body: DataStatePlaceholder(
          presentation: DataStatePresentation.failure,
          title: 'Could not check sign-in status',
        ),
      ),
      DataReady<User>() => const HomeScreen(),
      DataEmpty<User>() || DataUnauthenticated<User>() => const LoginScreen(),
    };
  }
}
