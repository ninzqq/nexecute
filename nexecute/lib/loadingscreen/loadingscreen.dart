import 'package:flutter/material.dart';
import 'package:nexecute/home/homescreen.dart';
import 'package:nexecute/loginscreen/loginscreen.dart';
import 'package:nexecute/services/services.dart';
import 'package:nexecute/shared/shared.dart';

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
          return HomeScreen();
        } else {
          return const LoginScreen();
        }
      },
    );
  }
}
