import 'package:flutter/material.dart';
import 'package:nexecute/shared/adaptive_navigation_shell.dart';
import 'package:nexecute/shared/app_shortcuts.dart';
import 'package:nexecute/themes.dart';

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
  const PersistentMainMenu({
    super.key,
    this.compact = false,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.destinations,
    required this.onSearch,
  });

  static const width = 180.0;
  static const compactWidth = 80.0;

  final bool compact;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<AdaptiveNavigationItem> destinations;
  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SizedBox(
      key: const Key('persistent-main-menu'),
      width: compact ? compactWidth : width,
      child: Material(
        color: Theme.of(context).appBarTheme.backgroundColor ?? colors.surface,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(
              right: BorderSide(color: colors.outline.withValues(alpha: 0.75)),
            ),
          ),
          child:
              compact
                  ? _MediumMainMenuRail(
                    selectedIndex: selectedIndex,
                    onDestinationSelected: onDestinationSelected,
                    destinations: destinations,
                    onSearch: onSearch,
                  )
                  : _DesktopMainMenuContent(
                    selectedIndex: selectedIndex,
                    onDestinationSelected: onDestinationSelected,
                    destinations: destinations,
                    onSearch: onSearch,
                  ),
        ),
      ),
    );
  }
}

class _MediumMainMenuRail extends StatelessWidget {
  const _MediumMainMenuRail({
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.destinations,
    required this.onSearch,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<AdaptiveNavigationItem> destinations;
  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context) {
    return ListView(
      key: const Key('medium-persistent-navigation-rail'),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      children: [
        for (var index = 0; index < 3; index++)
          _MediumRailTile.destination(
            destination: destinations[index],
            selected: selectedIndex == index,
            onTap: () => onDestinationSelected(index),
            destinationKey: ValueKey('desktop-destination-$index'),
          ),
        const _MediumRailDivider(key: Key('medium-section-divider-0')),
        _MediumRailTile.action(
          label: 'Search',
          icon: Icons.search_rounded,
          onTap: onSearch,
          tileKey: const Key('medium-search-action'),
        ),
        for (var index = 3; index < 6; index++)
          _MediumRailTile.destination(
            destination: destinations[index],
            selected: selectedIndex == index,
            onTap: () => onDestinationSelected(index),
            destinationKey: ValueKey('desktop-destination-$index'),
          ),
        const _MediumRailDivider(key: Key('medium-section-divider-1')),
        for (var index = 6; index < destinations.length; index++)
          _MediumRailTile.destination(
            destination: destinations[index],
            selected: selectedIndex == index,
            onTap: () => onDestinationSelected(index),
            destinationKey: ValueKey('desktop-destination-$index'),
          ),
        _MediumRailTile.action(
          label: 'Shortcuts',
          tooltip: 'Keyboard shortcuts',
          icon: Icons.keyboard_outlined,
          onTap: () => showKeyboardShortcutsDialog(context),
          tileKey: const Key('medium-keyboard-shortcuts-action'),
        ),
      ],
    );
  }
}

class _MediumRailDivider extends StatelessWidget {
  const _MediumRailDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 6),
      child: Divider(height: 1, indent: 8, endIndent: 8),
    );
  }
}

class _MediumRailTile extends StatelessWidget {
  _MediumRailTile.destination({
    required AdaptiveNavigationItem destination,
    required this.selected,
    required this.onTap,
    required Key destinationKey,
  }) : label = destination.label,
       tooltip = destination.label,
       icon = destination.icon,
       selectedIcon = destination.selectedIcon,
       tileKey = destinationKey;

  const _MediumRailTile.action({
    required this.label,
    String? tooltip,
    required this.icon,
    required this.onTap,
    required this.tileKey,
  }) : tooltip = tooltip ?? label,
       selected = false,
       selectedIcon = icon;

  final String label;
  final String tooltip;
  final IconData icon;
  final IconData selectedIcon;
  final bool selected;
  final VoidCallback onTap;
  final Key tileKey;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final navigationTheme = theme.navigationRailTheme;
    final colors = theme.colorScheme;
    final selectedColor =
        navigationTheme.selectedIconTheme?.color ?? colors.primary;
    final unselectedColor =
        navigationTheme.unselectedIconTheme?.color ?? colors.onSurfaceVariant;
    final indicatorColor =
        navigationTheme.indicatorColor ?? colors.secondaryContainer;
    final selectedLabelStyle =
        navigationTheme.selectedLabelTextStyle ?? theme.textTheme.labelMedium;
    final unselectedLabelStyle =
        navigationTheme.unselectedLabelTextStyle ?? theme.textTheme.labelMedium;

    return Tooltip(
      message: tooltip,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 2),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            key: tileKey,
            borderRadius: BorderRadius.circular(8),
            onTap: onTap,
            child: Semantics(
              selected: selected,
              button: true,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedContainer(
                      duration: kThemeAnimationDuration,
                      width: 52,
                      height: 30,
                      decoration: BoxDecoration(
                        color: selected ? indicatorColor : Colors.transparent,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        selected ? selectedIcon : icon,
                        size: 22,
                        color: selected ? selectedColor : unselectedColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: (selected
                              ? selectedLabelStyle
                              : unselectedLabelStyle)
                          ?.copyWith(fontSize: 11),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DesktopMainMenuContent extends StatelessWidget {
  const _DesktopMainMenuContent({
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.destinations,
    required this.onSearch,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<AdaptiveNavigationItem> destinations;
  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context) {
    return ListView(
      key: const Key('desktop-source-list'),
      padding: const EdgeInsets.fromLTRB(10, 12, 10, 12),
      children: [
        const _MenuSectionLabel('Workspace'),
        const SizedBox(height: 4),
        for (var index = 0; index < 3; index++)
          _DestinationTile(
            key: ValueKey('desktop-destination-$index'),
            destination: destinations[index],
            selected: selectedIndex == index,
            onTap: () => onDestinationSelected(index),
          ),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 10),
          child: Divider(height: 1),
        ),
        const _MenuSectionLabel('Tools'),
        const SizedBox(height: 4),
        _DesktopMenuTile(
          label: 'Search',
          icon: Icons.search_rounded,
          onTap: onSearch,
        ),
        for (var index = 3; index < 6; index++)
          _DestinationTile(
            key: ValueKey('desktop-destination-$index'),
            destination: destinations[index],
            selected: selectedIndex == index,
            onTap: () => onDestinationSelected(index),
          ),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 10),
          child: Divider(height: 1),
        ),
        const _MenuSectionLabel('Account'),
        const SizedBox(height: 4),
        for (var index = 6; index < destinations.length; index++)
          _DestinationTile(
            key: ValueKey('desktop-destination-$index'),
            destination: destinations[index],
            selected: selectedIndex == index,
            onTap: () => onDestinationSelected(index),
          ),
        _DesktopMenuTile(
          label: 'Keyboard shortcuts',
          icon: Icons.keyboard_outlined,
          onTap: () => showKeyboardShortcutsDialog(context),
        ),
      ],
    );
  }
}

class _MenuSectionLabel extends StatelessWidget {
  const _MenuSectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Text(
        label.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.7,
        ),
      ),
    );
  }
}

class _DestinationTile extends StatelessWidget {
  const _DestinationTile({
    super.key,
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final AdaptiveNavigationItem destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.appPalette;
    final navigationTheme = theme.navigationRailTheme;
    final selectedBackground =
        navigationTheme.indicatorColor ??
        palette.primary.withValues(alpha: 0.16);
    final selectedIconColor =
        navigationTheme.selectedIconTheme?.color ?? palette.primary;
    final selectedLabelColor =
        navigationTheme.selectedLabelTextStyle?.color ?? palette.primary;
    final indicatorShape = navigationTheme.indicatorShape;
    final selectedSide =
        indicatorShape is StadiumBorder
            ? indicatorShape.side
            : BorderSide(color: palette.outline);
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Material(
        color: selected ? selectedBackground : Colors.transparent,
        shape: RoundedRectangleBorder(
          side: selected ? selectedSide : BorderSide.none,
          borderRadius: BorderRadius.circular(7),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          borderRadius: BorderRadius.circular(7),
          onTap: onTap,
          child: Semantics(
            selected: selected,
            button: true,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Row(
                children: [
                  Icon(
                    selected ? destination.selectedIcon : destination.icon,
                    size: 19,
                    color: selected ? selectedIconColor : null,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      destination.label,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight:
                            selected ? FontWeight.w700 : FontWeight.w500,
                        color: selected ? selectedLabelColor : null,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DesktopMenuTile extends StatelessWidget {
  const _DesktopMenuTile({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: InkWell(
        borderRadius: BorderRadius.circular(7),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            children: [
              Icon(icon, size: 19),
              const SizedBox(width: 10),
              Expanded(child: Text(label)),
            ],
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
                label: 'Archive',
                icon: Icons.archive_outlined,
                routeName: '/archive',
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
