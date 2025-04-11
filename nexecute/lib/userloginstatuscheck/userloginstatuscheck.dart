import 'package:flutter/material.dart';
import 'package:nexecute/home/screens/homescreen.dart';
import 'package:nexecute/loginscreen/loginscreen.dart';
import 'package:nexecute/services/services.dart';
import 'package:nexecute/loadingscreen/loadingscreen.dart';

class UserLogInStatusCheck extends StatelessWidget {
  const UserLogInStatusCheck({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: AuthService().userStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: LoadingTextScreen());
        } else if (snapshot.hasError) {
          return const Center(child: Text('Error'));
        } else if (snapshot.hasData) {
          return HomeScreen();
        } else {
          return const LoginScreen();
        }
      },
    );
  }
}
