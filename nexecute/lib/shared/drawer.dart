import 'package:flutter/material.dart';
import 'package:nexecute/shared/app_shortcuts.dart';

class MainDrawer extends StatelessWidget {
  const MainDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return const Drawer(
      child: SafeArea(
        child: MainMenuContent(closeDrawerBeforeAction: true, showHeader: true),
      ),
    );
  }
}

class PersistentMainMenu extends StatelessWidget {
  const PersistentMainMenu({super.key});

  static const width = 240.0;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SizedBox(
      key: const Key('persistent-main-menu'),
      width: width,
      child: Material(
        color: Theme.of(context).appBarTheme.backgroundColor ?? colors.surface,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(
              right: BorderSide(color: colors.outline.withValues(alpha: 0.75)),
            ),
          ),
          child: const MainMenuContent(
            closeDrawerBeforeAction: false,
            showHeader: false,
          ),
        ),
      ),
    );
  }
}

class MainMenuContent extends StatelessWidget {
  const MainMenuContent({
    super.key,
    required this.closeDrawerBeforeAction,
    required this.showHeader,
  });

  final bool closeDrawerBeforeAction;
  final bool showHeader;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (showHeader)
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
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            children: [
              _routeTile(
                context,
                label: 'Profile',
                icon: Icons.person,
                routeName: '/profile',
              ),
              _routeTile(
                context,
                label: 'Search',
                icon: Icons.search_rounded,
                routeName: '/search',
                subtitle: AppShortcutLabels.search,
              ),
              _routeTile(
                context,
                label: 'Assistant',
                icon: Icons.auto_awesome_outlined,
                routeName: '/assistant',
              ),
              _routeTile(
                context,
                label: 'Tags',
                icon: Icons.label_outlined,
                routeName: '/tags',
              ),
              _routeTile(
                context,
                label: 'Trash',
                icon: Icons.delete_forever,
                routeName: '/trash',
              ),
              ListTile(
                leading: const Icon(Icons.keyboard_outlined),
                title: const Text('Keyboard shortcuts'),
                onTap: () {
                  _closeDrawer(context);
                  showKeyboardShortcutsDialog(context);
                },
              ),
              _routeTile(
                context,
                label: 'Settings',
                icon: Icons.settings,
                routeName: '/settings',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _routeTile(
    BuildContext context, {
    required String label,
    required IconData icon,
    required String routeName,
    String? subtitle,
  }) {
    return ListTile(
      leading: Icon(icon),
      title: Text(label),
      subtitle: subtitle == null ? null : Text(subtitle),
      onTap: () {
        _closeDrawer(context);
        Navigator.pushNamed(context, routeName);
      },
    );
  }

  void _closeDrawer(BuildContext context) {
    if (closeDrawerBeforeAction) Navigator.pop(context);
  }
}
