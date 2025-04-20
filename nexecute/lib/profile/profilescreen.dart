import 'package:flutter/material.dart';
import 'package:nexecute/shared/shared.dart';
import 'package:provider/provider.dart';
import 'package:nexecute/services/auth.dart';
import 'package:nexecute/models/count.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    var count = Provider.of<Count>(context);
    var user = AuthService().user;

    if (user != null) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: appBarLighterDarkCyan,
          title: Text(user.displayName ?? 'Guest'),
        ),
        body: SafeArea(
          child: Container(
            color: bgDarkCyan,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 100,
                    height: 100,
                    margin: const EdgeInsets.only(top: 50),
                    child: const Center(
                      child: Icon(Icons.question_mark_rounded, size: 100),
                    ),
                  ),
                  Text(
                    user.email ?? '',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const Spacer(),
                  Text(
                    '${count.count}',
                    style: Theme.of(context).textTheme.displayMedium,
                  ),
                  Text(
                    'Buttons tapped',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const Spacer(),
                  ElevatedButton(
                    child: const Text('logout'),
                    onPressed: () async {
                      await AuthService().signOut();
                      Navigator.of(
                        context,
                      ).pushNamedAndRemoveUntil('/', (route) => false);
                    },
                  ),
                  const Spacer(),
                ],
              ),
            ),
          ),
        ),
      );
    } else {
      return const Text('jaaaaa');
    }
  }
}
