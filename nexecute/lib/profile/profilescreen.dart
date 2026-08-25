import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:nexecute/services/auth.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = context.read<AuthService>();
    final user = authService.user;

    if (user != null) {
      return Scaffold(
        appBar: AppBar(title: Text(user.displayName ?? 'Guest')),
        body: SafeArea(
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
                ElevatedButton(
                  onPressed: () async {
                    await authService.signOut();
                    if (!context.mounted) return;
                    Navigator.of(
                      context,
                    ).pushNamedAndRemoveUntil('/', (route) => false);
                  },
                  child: const Text('Log out'),
                ),
                const Spacer(),
              ],
            ),
          ),
        ),
      );
    } else {
      return const Scaffold(body: Center(child: Text('Not signed in')));
    }
  }
}
