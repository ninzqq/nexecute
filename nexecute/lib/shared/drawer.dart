import 'package:flutter/material.dart';
import 'package:nexecute/services/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class MainDrawer extends StatelessWidget {
  const MainDrawer({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    var user = AuthService().user;

    return Drawer(
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.max,
          children: [
            Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Text(
                  'Nexecute',
                  style: Theme.of(context).textTheme.headline1,
                ),
              ),
            ),
            UserAccountsDrawerHeader(
              currentAccountPicture: CircleAvatar(
                  backgroundImage: NetworkImage(user?.photoURL ?? '')),
              accountName: Text(user?.displayName ?? 'Guest'),
              accountEmail: const Text(''), // user?.email ?? ''
            ),
            const Divider(),
            const ListTile(
              title: Text('data'),
            ),
            const Divider(),
            ListTile(
              title: const Text('Profile'),
              tileColor: Colors.deepPurple,
              onTap: () {
                Navigator.pushNamed(context, '/profile');
              },
            ),
            Expanded(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    ListTile(
                      title: Row(
                        children: const [
                          Icon(FontAwesomeIcons.faceMeh),
                          Padding(
                            padding: EdgeInsets.only(left: 15),
                            child: Text('Button pressinks'),
                          )
                        ],
                      ),
                      tileColor: const Color.fromARGB(255, 40, 50, 50),
                      onTap: () {
                        Navigator.pushNamed(context, '/count');
                      },
                    ),
                    ListTile(
                      title: Row(
                        children: const [
                          Icon(Icons.settings),
                          Padding(
                            padding: EdgeInsets.only(left: 15),
                            child: Text('Settings'),
                          ),
                        ],
                      ),
                      tileColor: const Color.fromARGB(255, 32, 41, 41),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
