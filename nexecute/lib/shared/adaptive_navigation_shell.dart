import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

enum AppLayoutClass { compact, medium, expanded }

extension AppLayoutClassDetails on AppLayoutClass {
  bool get usesNavigationRail => this != AppLayoutClass.compact;
  bool get usesExtendedNavigationRail => this == AppLayoutClass.expanded;

  bool get usesCalendarSidePane => this == AppLayoutClass.expanded;

  int get notesColumnCount => switch (this) {
    AppLayoutClass.compact => 2,
    AppLayoutClass.medium => 3,
    AppLayoutClass.expanded => 4,
  };

  double? get readableContentMaxWidth => switch (this) {
    AppLayoutClass.compact => null,
    AppLayoutClass.medium => 720,
    AppLayoutClass.expanded => 840,
  };
}

abstract final class AppLayoutBreakpoints {
  static const double minimumMediumWidth = 600;
  static const double minimumExpandedWidth = 840;

  static AppLayoutClass fromWidth(double width) {
    if (width < minimumMediumWidth) return AppLayoutClass.compact;
    if (width < minimumExpandedWidth) return AppLayoutClass.medium;
    return AppLayoutClass.expanded;
  }

  static AppLayoutClass fromContext(BuildContext context) =>
      AppLayoutScope.maybeOf(context) ??
      fromWidth(MediaQuery.sizeOf(context).width);
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

class AdaptiveContentFrame extends StatelessWidget {
  const AdaptiveContentFrame({
    super.key,
    required this.child,
    this.maxWidth,
    this.alignment = Alignment.topCenter,
    this.contentKey,
  });

  final Widget child;
  final double? maxWidth;
  final AlignmentGeometry alignment;
  final Key? contentKey;

  @override
  Widget build(BuildContext context) {
    final layoutClass = AppLayoutBreakpoints.fromContext(context);
    final effectiveMaxWidth = maxWidth ?? layoutClass.readableContentMaxWidth;
    if (effectiveMaxWidth == null) return child;

    return LayoutBuilder(
      builder:
          (context, constraints) => Align(
            alignment: alignment,
            child: SizedBox(
              key: contentKey,
              width: constraints.constrainWidth(effectiveMaxWidth),
              height:
                  constraints.hasBoundedHeight ? constraints.maxHeight : null,
              child: child,
            ),
          ),
    );
  }
}

BoxConstraints adaptiveSheetConstraints(
  BuildContext context, {
  double? minHeight,
  double? maxHeight,
}) {
  final layoutClass = AppLayoutBreakpoints.fromContext(context);
  return BoxConstraints(
    minHeight: minHeight ?? 0,
    maxHeight: maxHeight ?? double.infinity,
    maxWidth: layoutClass == AppLayoutClass.compact ? double.infinity : 640,
  );
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
    this.persistentMenu,
    this.persistentMenuWidth = 240,
    this.floatingActionButton,
    this.desktopToolbarSearch,
    this.desktopPrimaryAction,
    this.desktopTitle,
    this.resizeToAvoidBottomInset = true,
  }) : assert(destinations.length >= 2),
       assert(selectedIndex >= 0 && selectedIndex < destinations.length);

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<AdaptiveNavigationItem> destinations;
  final Widget body;
  final PreferredSizeWidget? appBar;
  final Widget? drawer;
  final Widget? persistentMenu;
  final double persistentMenuWidth;
  final Widget? floatingActionButton;
  final Widget? desktopToolbarSearch;
  final Widget? desktopPrimaryAction;
  final String? desktopTitle;
  final bool resizeToAvoidBottomInset;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final layoutClass = AppLayoutBreakpoints.fromWidth(
            constraints.maxWidth,
          );
          final usesPersistentMenu =
              layoutClass != AppLayoutClass.compact && persistentMenu != null;
          final usesRail =
              layoutClass.usesNavigationRail && !usesPersistentMenu;

          return AppLayoutScope(
            layoutClass: layoutClass,
            child: Scaffold(
              appBar:
                  usesPersistentMenu
                      ? _desktopAppBar(
                        context,
                        compact: layoutClass == AppLayoutClass.medium,
                      )
                      : appBar,
              drawer: usesPersistentMenu ? null : drawer,
              resizeToAvoidBottomInset: resizeToAvoidBottomInset,
              body: Row(
                children: [
                  if (usesPersistentMenu) _persistentMenu(),
                  if (usesRail) _navigationRail(context, layoutClass),
                  Expanded(
                    key: const Key('adaptive-navigation-content'),
                    child: FocusTraversalOrder(
                      key: const Key('content-focus-order'),
                      order: const NumericFocusOrder(2),
                      child: Semantics(
                        container: true,
                        sortKey: const OrdinalSortKey(2),
                        child: body,
                      ),
                    ),
                  ),
                ],
              ),
              bottomNavigationBar:
                  layoutClass == AppLayoutClass.compact
                      ? _bottomNavigation(context)
                      : null,
              floatingActionButton:
                  floatingActionButton == null ||
                          layoutClass == AppLayoutClass.expanded
                      ? null
                      : FocusTraversalOrder(
                        key: const Key('create-focus-order'),
                        order: const NumericFocusOrder(3),
                        child: Semantics(
                          container: true,
                          sortKey: const OrdinalSortKey(3),
                          child: floatingActionButton!,
                        ),
                      ),
            ),
          );
        },
      ),
    );
  }

  PreferredSizeWidget _desktopAppBar(
    BuildContext context, {
    required bool compact,
  }) {
    return AppBar(
      toolbarHeight: 58,
      automaticallyImplyLeading: false,
      leadingWidth: persistentMenuWidth,
      leading: Align(
        alignment: Alignment.centerLeft,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 20),
          child:
              compact
                  ? FittedBox(
                    key: const Key('medium-app-title-fitted-box'),
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Nexecute',
                      maxLines: 1,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  )
                  : Text(
                    'Nexecute',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
        ),
      ),
      titleSpacing: 16,
      title: Text(
        desktopTitle ?? destinations[selectedIndex].label,
        key: const Key('desktop-page-title'),
      ),
      actions:
          compact ||
                  (desktopToolbarSearch == null && desktopPrimaryAction == null)
              ? null
              : [
                if (desktopToolbarSearch != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: Align(
                      alignment: Alignment.center,
                      child: desktopToolbarSearch!,
                    ),
                  ),
                if (desktopPrimaryAction != null)
                  FocusTraversalOrder(
                    key: const Key('create-focus-order'),
                    order: const NumericFocusOrder(3),
                    child: Padding(
                      padding: const EdgeInsets.only(right: 16),
                      child: Align(
                        alignment: Alignment.center,
                        child: desktopPrimaryAction!,
                      ),
                    ),
                  ),
              ],
    );
  }

  Widget _persistentMenu() {
    return FocusTraversalOrder(
      key: const Key('navigation-focus-order'),
      order: const NumericFocusOrder(1),
      child: Semantics(
        container: true,
        sortKey: const OrdinalSortKey(1),
        child: SizedBox(width: persistentMenuWidth, child: persistentMenu),
      ),
    );
  }

  Widget _navigationRail(BuildContext context, AppLayoutClass layoutClass) {
    final extended = layoutClass.usesExtendedNavigationRail;
    final colors = Theme.of(context).colorScheme;
    return FocusTraversalOrder(
      key: const Key('navigation-focus-order'),
      order: const NumericFocusOrder(1),
      child: Semantics(
        container: true,
        sortKey: const OrdinalSortKey(1),
        child: DecoratedBox(
          key: const Key('adaptive-navigation-rail-shell'),
          decoration: BoxDecoration(
            color:
                Theme.of(context).appBarTheme.backgroundColor ?? colors.surface,
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
        ),
      ),
    );
  }

  Widget _bottomNavigation(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return FocusTraversalOrder(
      key: const Key('navigation-focus-order'),
      order: const NumericFocusOrder(1),
      child: Semantics(
        container: true,
        sortKey: const OrdinalSortKey(1),
        child: Container(
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
        ),
      ),
    );
  }
}
