import 'package:flutter/material.dart';
import 'package:nexecute/services/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class MainDrawer extends StatelessWidget {
  const MainDrawer({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    var user = AuthService().user;

    final List<Map<String, dynamic>> _menuItem = [
      {
        "title": const Text("Profile"),
        "icon": const Icon(Icons.person),
        "function": () => {
              Navigator.pushNamed(context, "/profile"),
            },
        "selected": false,
      },
      {
        "title": const Text("Button pressinks"),
        "icon": const Icon(Icons.add),
        "function": () => {
              Navigator.pushNamed(context, "/count"),
            },
        "selected": false,
      },
      {
        "title": const Text("Settings"),
        "icon": const Icon(Icons.settings),
        "function": () => {},
        "selected": false,
      }
    ];

    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                'Nexecute',
                style: Theme.of(context).textTheme.headline1,
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: _menuItem.length,
                itemBuilder: (context, index) {
                  return ListTile(
                    leading: _menuItem[index]['icon'],
                    title: _menuItem[index]['title'],
                    onTap: () => {
                      _menuItem[index]['function'](),
                    },
                    selected: _menuItem[index]['selected'],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
