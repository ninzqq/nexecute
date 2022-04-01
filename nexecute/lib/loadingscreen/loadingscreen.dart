import 'package:flutter/material.dart';
import 'package:nexecute/home/home.dart';
import 'package:nexecute/login/loginscreen.dart';
import 'package:nexecute/services/auth.dart';
import 'package:nexecute/shared/loading.dart';

class LoadingScreen extends StatelessWidget {
  const LoadingScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: AuthService().userStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: Column(
              children: const [
                Loader(),
                Text('Loading...'),
              ],
            ),
          );
        } else if (snapshot.hasError) {
          return const Center(
            child: Text('Error'),
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
