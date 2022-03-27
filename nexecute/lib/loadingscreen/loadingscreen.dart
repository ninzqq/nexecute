import 'package:flutter/material.dart';
import 'package:nexecute/home/home.dart';

class LoadingScreen extends StatelessWidget {
  const LoadingScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      //stream: AuthService().userStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Text('Loading...'),
          );
        } else if (snapshot.hasError) {
          return const Center(
            child: Text('Error'),
          );
        } else if (snapshot.hasData) {
          return const HomeScreen();
        } else {
          //return const LoginScreen();
          return const HomeScreen();
        }
      },
    );
  }
}
