import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:nexecute/models/quicxec.dart';
import 'package:nexecute/models/event.dart';
import 'package:nexecute/home/bottomsheets/item_editor_sheet.dart';
import 'package:nexecute/shared/bottom_sheet_safe_area.dart';
import 'package:nexecute/shared/adaptive_navigation_shell.dart';

Future<void> showItemEditor(
  BuildContext context, {
  Event? event,
  Quicxec? quicxec,
  DateTime? date,
  bool isEditing = false,
}) {
  Widget editor({required bool desktopPresentation}) => ItemEditorSheet(
    event: event,
    quicxec: quicxec,
    date: date,
    isEditing: isEditing,
    desktopPresentation: desktopPresentation,
  );

  if (AppLayoutBreakpoints.fromContext(context) == AppLayoutClass.expanded) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final availableHeight = MediaQuery.sizeOf(dialogContext).height - 80;
        return Dialog(
          key: const Key('desktop-item-editor-dialog'),
          clipBehavior: Clip.antiAlias,
          insetPadding: const EdgeInsets.all(40),
          child: SizedBox(
            width: 680,
            height: math.min(760, availableHeight),
            child: editor(desktopPresentation: true),
          ),
        );
      },
    );
  }

  return showModalBottomSheet<void>(
    isScrollControlled: true,
    isDismissible: true,
    enableDrag: true,
    useSafeArea: true,
    constraints: adaptiveSheetConstraints(
      context,
      maxHeight: MediaQuery.of(context).size.height,
      minHeight: MediaQuery.of(context).size.height * 0.3,
    ),
    context: context,
    builder:
        (context) => BottomSheetSafeArea(
          child: AnimatedPadding(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: editor(desktopPresentation: false),
          ),
        ),
  );
}
