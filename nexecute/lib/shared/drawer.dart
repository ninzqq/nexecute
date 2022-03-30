import 'package:flutter/material.dart';

class MainDrawer extends StatelessWidget {
  const MainDrawer({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Column(
        mainAxisSize: MainAxisSize.max,
        children: [
          DrawerHeader(
            child: Align(
              alignment: Alignment.topLeft,
              child: Text(
                'Nexecute',
                style: Theme.of(context).textTheme.headline1,
              ),
            ),
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
              child: ListTile(
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
            ),
          ),
        ],
      ),
    );
  }
}
