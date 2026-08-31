import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SelectDestinationIntent extends Intent {
  const SelectDestinationIntent(this.index);

  final int index;
}

class CreateItemIntent extends Intent {
  const CreateItemIntent();
}

class OpenSearchIntent extends Intent {
  const OpenSearchIntent();
}

class FocusAssistantComposerIntent extends Intent {
  const FocusAssistantComposerIntent();
}

class SaveAppIntent extends Intent {
  const SaveAppIntent();
}

class CancelAppIntent extends Intent {
  const CancelAppIntent();
}

abstract final class AppShortcutBindings {
  static const Map<ShortcutActivator, Intent> home = {
    SingleActivator(
      LogicalKeyboardKey.digit1,
      control: true,
    ): SelectDestinationIntent(0),
    SingleActivator(
      LogicalKeyboardKey.digit1,
      meta: true,
    ): SelectDestinationIntent(0),
    SingleActivator(
      LogicalKeyboardKey.digit2,
      control: true,
    ): SelectDestinationIntent(1),
    SingleActivator(
      LogicalKeyboardKey.digit2,
      meta: true,
    ): SelectDestinationIntent(1),
    SingleActivator(
      LogicalKeyboardKey.digit3,
      control: true,
    ): SelectDestinationIntent(2),
    SingleActivator(
      LogicalKeyboardKey.digit3,
      meta: true,
    ): SelectDestinationIntent(2),
    SingleActivator(LogicalKeyboardKey.keyN, control: true): CreateItemIntent(),
    SingleActivator(LogicalKeyboardKey.keyN, meta: true): CreateItemIntent(),
    SingleActivator(LogicalKeyboardKey.keyK, control: true): OpenSearchIntent(),
    SingleActivator(LogicalKeyboardKey.keyK, meta: true): OpenSearchIntent(),
  };

  static const Map<ShortcutActivator, Intent> editor = {
    SingleActivator(LogicalKeyboardKey.enter, control: true): SaveAppIntent(),
    SingleActivator(LogicalKeyboardKey.enter, meta: true): SaveAppIntent(),
    SingleActivator(LogicalKeyboardKey.escape): CancelAppIntent(),
  };

  static const Map<ShortcutActivator, Intent> assistant = {
    SingleActivator(LogicalKeyboardKey.keyA, control: true, shift: true):
        FocusAssistantComposerIntent(),
    SingleActivator(LogicalKeyboardKey.keyA, meta: true, shift: true):
        FocusAssistantComposerIntent(),
    SingleActivator(LogicalKeyboardKey.enter, control: true): SaveAppIntent(),
    SingleActivator(LogicalKeyboardKey.enter, meta: true): SaveAppIntent(),
    SingleActivator(LogicalKeyboardKey.escape): CancelAppIntent(),
  };

  static const Map<ShortcutActivator, Intent> search = {
    SingleActivator(LogicalKeyboardKey.keyK, control: true): OpenSearchIntent(),
    SingleActivator(LogicalKeyboardKey.keyK, meta: true): OpenSearchIntent(),
    SingleActivator(LogicalKeyboardKey.escape): CancelAppIntent(),
  };
}

class AppCancelShortcutRegion extends StatelessWidget {
  const AppCancelShortcutRegion({
    super.key,
    required this.onCancel,
    required this.child,
  });

  final VoidCallback onCancel;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.escape): CancelAppIntent(),
      },
      child: Actions(
        actions: {
          CancelAppIntent: CallbackAction<CancelAppIntent>(
            onInvoke: (_) {
              onCancel();
              return null;
            },
          ),
        },
        child: Focus(autofocus: true, child: child),
      ),
    );
  }
}

abstract final class AppShortcutLabels {
  static String get modifier =>
      defaultTargetPlatform == TargetPlatform.macOS ? '⌘' : 'Ctrl+';

  static String destination(int index) => '$modifier${index + 1}';
  static String get create => '${modifier}N';
  static String get search => '${modifier}K';
  static String get save => '${modifier}Enter';
  static String get cancel => 'Esc';
  static String get assistantComposer => '$modifier⇧A';
}

bool canInvokeGlobalAppShortcut(BuildContext context) {
  final route = ModalRoute.of(context);
  if (route != null && !route.isCurrent) return false;

  final focusContext = FocusManager.instance.primaryFocus?.context;
  if (focusContext == null) return true;
  return focusContext.widget is! EditableText &&
      focusContext.findAncestorWidgetOfExactType<EditableText>() == null;
}

bool isCurrentAppRoute(BuildContext context) =>
    ModalRoute.of(context)?.isCurrent ?? true;

class AppEditorShortcutRegion extends StatelessWidget {
  const AppEditorShortcutRegion({
    super.key,
    required this.onSave,
    required this.onCancel,
    required this.child,
  });

  final VoidCallback onSave;
  final VoidCallback onCancel;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: AppShortcutBindings.editor,
      child: Actions(
        actions: {
          SaveAppIntent: CallbackAction<SaveAppIntent>(
            onInvoke: (_) {
              onSave();
              return null;
            },
          ),
          CancelAppIntent: CallbackAction<CancelAppIntent>(
            onInvoke: (_) {
              onCancel();
              return null;
            },
          ),
        },
        child: Focus(autofocus: true, child: child),
      ),
    );
  }
}

Future<void> showKeyboardShortcutsDialog(BuildContext context) {
  final shortcuts = [
    ('Calendar', AppShortcutLabels.destination(0)),
    ('Tasks', AppShortcutLabels.destination(1)),
    ('Notes', AppShortcutLabels.destination(2)),
    ('Create in the current section', AppShortcutLabels.create),
    ('Search', AppShortcutLabels.search),
    ('Save or confirm', AppShortcutLabels.save),
    ('Close or cancel', AppShortcutLabels.cancel),
    ('Focus Assistant composer', AppShortcutLabels.assistantComposer),
  ];

  return showDialog<void>(
    context: context,
    builder:
        (context) => AlertDialog(
          title: const Text('Keyboard shortcuts'),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final shortcut in shortcuts)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          Expanded(child: Text(shortcut.$1)),
                          const SizedBox(width: 24),
                          Semantics(
                            label: 'Shortcut ${shortcut.$2}',
                            child: Text(
                              shortcut.$2,
                              style: Theme.of(context).textTheme.labelLarge,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
  );
}
