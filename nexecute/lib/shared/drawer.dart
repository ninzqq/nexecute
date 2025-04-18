import 'package:flutter/material.dart';
import 'package:nexecute/shared/shared.dart';

class MainDrawer extends StatelessWidget {
  const MainDrawer({super.key});

  @override
  Widget build(BuildContext context) {

    final List<Map<String, dynamic>> menuItem = [
      {
        "title": const Text("Profile"),
        "icon": const Icon(Icons.person),
        "function": () => {
              Navigator.pop(context),
              Navigator.pushNamed(context, "/profile"),
            },
        "selected": false,
      },
      {
        "title": const Text('Tags'),
        'icon': const Icon(Icons.label_outlined),
        'function': () => {
              Navigator.pop(context),
              Navigator.pushNamed(context, '/tags'),
            },
        'selected': false,
      },
      {
        "title": const Text("Button pressinks"),
        "icon": const Icon(Icons.add),
        "function": () => {
              Navigator.pop(context),
              Navigator.pushNamed(context, "/count"),
            },
        "selected": false,
      },
      {
        "title": const Text("Trash"),
        "icon": const Icon(Icons.delete_forever),
        "function": () => {
              Navigator.pop(context),
              Navigator.pushNamed(context, "/trash"),
            },
        "selected": false,
      },
      {
        "title": const Text("Settings"),
        "icon": const Icon(Icons.settings),
        "function": () => {
              Navigator.pop(context),
              Navigator.pushNamed(context, "/settings"),
            },
        "selected": false,
      }
    ];

    return Drawer(
      backgroundColor: drawerBgColor,
      child: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  'Nexecute',
                  style: Theme.of(context).textTheme.displayLarge,
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: menuItem.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.only(left: 14.0, right: 14),
                    child: ListTile(
                      leading: menuItem[index]['icon'],
                      title: menuItem[index]['title'],
                      onTap: () => {
                        menuItem[index]['function'](),
                      },
                      selected: menuItem[index]['selected'],
                    ),
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
