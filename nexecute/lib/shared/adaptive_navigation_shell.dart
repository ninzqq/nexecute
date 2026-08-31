import 'package:flutter/material.dart';

enum AppLayoutClass { compact, medium, expanded }

extension AppLayoutClassDetails on AppLayoutClass {
  bool get usesNavigationRail => this != AppLayoutClass.compact;
  bool get usesExtendedNavigationRail => this == AppLayoutClass.expanded;
}

abstract final class AppLayoutBreakpoints {
  static const double minimumMediumWidth = 600;
  static const double minimumExpandedWidth = 840;

  static AppLayoutClass fromWidth(double width) {
    if (width < minimumMediumWidth) return AppLayoutClass.compact;
    if (width < minimumExpandedWidth) return AppLayoutClass.medium;
    return AppLayoutClass.expanded;
  }
}

class AppLayoutScope extends InheritedWidget {
  const AppLayoutScope({
    super.key,
    required this.layoutClass,
    required super.child,
  });

  final AppLayoutClass layoutClass;

  static AppLayoutClass of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppLayoutScope>();
    assert(scope != null, 'No AppLayoutScope found in this context.');
    return scope!.layoutClass;
  }

  static AppLayoutClass? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppLayoutScope>()?.layoutClass;

  @override
  bool updateShouldNotify(AppLayoutScope oldWidget) =>
      layoutClass != oldWidget.layoutClass;
}

@immutable
class AdaptiveNavigationItem {
  const AdaptiveNavigationItem({
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

class AdaptiveNavigationShell extends StatelessWidget {
  const AdaptiveNavigationShell({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.destinations,
    required this.body,
    this.appBar,
    this.drawer,
    this.floatingActionButton,
    this.resizeToAvoidBottomInset = true,
  }) : assert(destinations.length >= 2),
       assert(selectedIndex >= 0 && selectedIndex < destinations.length);

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<AdaptiveNavigationItem> destinations;
  final Widget body;
  final PreferredSizeWidget? appBar;
  final Widget? drawer;
  final Widget? floatingActionButton;
  final bool resizeToAvoidBottomInset;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final layoutClass = AppLayoutBreakpoints.fromWidth(
            constraints.maxWidth,
          );
          final usesRail = layoutClass.usesNavigationRail;

          return AppLayoutScope(
            layoutClass: layoutClass,
            child: Scaffold(
              appBar: appBar,
              drawer: drawer,
              resizeToAvoidBottomInset: resizeToAvoidBottomInset,
              body: Row(
                children: [
                  if (usesRail) _navigationRail(context, layoutClass),
                  Expanded(
                    key: const Key('adaptive-navigation-content'),
                    child: body,
                  ),
                ],
              ),
              bottomNavigationBar: usesRail ? null : _bottomNavigation(context),
              floatingActionButton: floatingActionButton,
            ),
          );
        },
      ),
    );
  }

  Widget _navigationRail(BuildContext context, AppLayoutClass layoutClass) {
    final extended = layoutClass.usesExtendedNavigationRail;
    final colors = Theme.of(context).colorScheme;
    return DecoratedBox(
      key: const Key('adaptive-navigation-rail-shell'),
      decoration: BoxDecoration(
        color: Theme.of(context).appBarTheme.backgroundColor ?? colors.surface,
        border: Border(
          right: BorderSide(color: colors.outline.withValues(alpha: 0.75)),
        ),
      ),
      child: NavigationRail(
        selectedIndex: selectedIndex,
        onDestinationSelected: onDestinationSelected,
        extended: extended,
        minExtendedWidth: 200,
        labelType:
            extended
                ? NavigationRailLabelType.none
                : NavigationRailLabelType.all,
        groupAlignment: -1,
        destinations: [
          for (final destination in destinations)
            NavigationRailDestination(
              icon: Icon(destination.icon),
              selectedIcon: Icon(destination.selectedIcon),
              label: Text(destination.label),
            ),
        ],
      ),
    );
  }

  Widget _bottomNavigation(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      key: const Key('bottom-navigation-shell'),
      foregroundDecoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: colors.outline.withValues(alpha: 0.75)),
        ),
      ),
      child: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: onDestinationSelected,
        destinations: [
          for (final destination in destinations)
            NavigationDestination(
              icon: Icon(destination.icon),
              selectedIcon: Icon(destination.selectedIcon),
              label: destination.label,
            ),
        ],
      ),
    );
  }
}
