import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class MacosAppMenuBar extends StatelessWidget {
  const MacosAppMenuBar({
    super.key,
    required this.newItemLabel,
    required this.onNewItem,
    required this.onSelectDestination,
    required this.onSearch,
    required this.onAssistant,
    required this.onSettings,
    required this.onShowKeyboardShortcuts,
    required this.child,
  });

  final String newItemLabel;
  final VoidCallback onNewItem;
  final ValueChanged<int> onSelectDestination;
  final VoidCallback onSearch;
  final VoidCallback onAssistant;
  final VoidCallback onSettings;
  final VoidCallback onShowKeyboardShortcuts;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.macOS) return child;

    return PlatformMenuBar(
      menus: buildMacosAppMenus(
        newItemLabel: newItemLabel,
        onNewItem: onNewItem,
        onSelectDestination: onSelectDestination,
        onSearch: onSearch,
        onAssistant: onAssistant,
        onSettings: onSettings,
        onShowKeyboardShortcuts: onShowKeyboardShortcuts,
      ),
      child: child,
    );
  }
}

List<PlatformMenuItem> buildMacosAppMenus({
  required String newItemLabel,
  required VoidCallback onNewItem,
  required ValueChanged<int> onSelectDestination,
  required VoidCallback onSearch,
  required VoidCallback onAssistant,
  required VoidCallback onSettings,
  required VoidCallback onShowKeyboardShortcuts,
}) {
  const keyboardCause = SelectionChangedCause.keyboard;
  return [
    PlatformMenu(
      label: 'Nexecute',
      menus: [
        const PlatformMenuItemGroup(
          members: [
            PlatformProvidedMenuItem(type: PlatformProvidedMenuItemType.about),
          ],
        ),
        PlatformMenuItemGroup(
          members: [
            PlatformMenuItem(
              label: 'Settings…',
              shortcut: const SingleActivator(
                LogicalKeyboardKey.comma,
                meta: true,
              ),
              onSelected: onSettings,
            ),
          ],
        ),
        const PlatformMenuItemGroup(
          members: [
            PlatformProvidedMenuItem(
              type: PlatformProvidedMenuItemType.servicesSubmenu,
            ),
          ],
        ),
        const PlatformMenuItemGroup(
          members: [
            PlatformProvidedMenuItem(type: PlatformProvidedMenuItemType.hide),
            PlatformProvidedMenuItem(
              type: PlatformProvidedMenuItemType.hideOtherApplications,
            ),
            PlatformProvidedMenuItem(
              type: PlatformProvidedMenuItemType.showAllApplications,
            ),
          ],
        ),
        const PlatformMenuItemGroup(
          members: [
            PlatformProvidedMenuItem(type: PlatformProvidedMenuItemType.quit),
          ],
        ),
      ],
    ),
    PlatformMenu(
      label: 'File',
      menus: [
        PlatformMenuItem(
          label: newItemLabel,
          shortcut: const SingleActivator(LogicalKeyboardKey.keyN, meta: true),
          onSelected: onNewItem,
        ),
      ],
    ),
    const PlatformMenu(
      label: 'Edit',
      menus: [
        PlatformMenuItemGroup(
          members: [
            PlatformMenuItem(
              label: 'Undo',
              shortcut: SingleActivator(LogicalKeyboardKey.keyZ, meta: true),
              onSelectedIntent: UndoTextIntent(keyboardCause),
            ),
            PlatformMenuItem(
              label: 'Redo',
              shortcut: SingleActivator(
                LogicalKeyboardKey.keyZ,
                shift: true,
                meta: true,
              ),
              onSelectedIntent: RedoTextIntent(keyboardCause),
            ),
          ],
        ),
        PlatformMenuItemGroup(
          members: [
            PlatformMenuItem(
              label: 'Cut',
              shortcut: SingleActivator(LogicalKeyboardKey.keyX, meta: true),
              onSelectedIntent: CopySelectionTextIntent.cut(keyboardCause),
            ),
            PlatformMenuItem(
              label: 'Copy',
              shortcut: SingleActivator(LogicalKeyboardKey.keyC, meta: true),
              onSelectedIntent: CopySelectionTextIntent.copy,
            ),
            PlatformMenuItem(
              label: 'Paste',
              shortcut: SingleActivator(LogicalKeyboardKey.keyV, meta: true),
              onSelectedIntent: PasteTextIntent(keyboardCause),
            ),
            PlatformMenuItem(
              label: 'Select All',
              shortcut: SingleActivator(LogicalKeyboardKey.keyA, meta: true),
              onSelectedIntent: SelectAllTextIntent(keyboardCause),
            ),
          ],
        ),
      ],
    ),
    PlatformMenu(
      label: 'Navigate',
      menus: [
        PlatformMenuItemGroup(
          members: [
            for (final destination in const [
              (0, 'Calendar'),
              (1, 'Tasks'),
              (2, 'Notes'),
            ])
              PlatformMenuItem(
                label: destination.$2,
                shortcut: SingleActivator(switch (destination.$1) {
                  0 => LogicalKeyboardKey.digit1,
                  1 => LogicalKeyboardKey.digit2,
                  _ => LogicalKeyboardKey.digit3,
                }, meta: true),
                onSelected: () => onSelectDestination(destination.$1),
              ),
          ],
        ),
        PlatformMenuItemGroup(
          members: [
            PlatformMenuItem(
              label: 'Search',
              shortcut: const SingleActivator(
                LogicalKeyboardKey.keyK,
                meta: true,
              ),
              onSelected: onSearch,
            ),
            PlatformMenuItem(label: 'Assistant', onSelected: onAssistant),
          ],
        ),
      ],
    ),
    const PlatformMenu(
      label: 'Window',
      menus: [
        PlatformMenuItemGroup(
          members: [
            PlatformProvidedMenuItem(
              type: PlatformProvidedMenuItemType.minimizeWindow,
            ),
            PlatformProvidedMenuItem(
              type: PlatformProvidedMenuItemType.zoomWindow,
            ),
          ],
        ),
        PlatformMenuItemGroup(
          members: [
            PlatformProvidedMenuItem(
              type: PlatformProvidedMenuItemType.toggleFullScreen,
            ),
            PlatformProvidedMenuItem(
              type: PlatformProvidedMenuItemType.arrangeWindowsInFront,
            ),
          ],
        ),
      ],
    ),
    PlatformMenu(
      label: 'Help',
      menus: [
        PlatformMenuItem(
          label: 'Keyboard Shortcuts…',
          shortcut: const SingleActivator(LogicalKeyboardKey.slash, meta: true),
          onSelected: onShowKeyboardShortcuts,
        ),
      ],
    ),
  ];
}
