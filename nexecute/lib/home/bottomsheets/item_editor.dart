import 'package:flutter/material.dart';
import 'package:nexecute/models/quicxec.dart';
import 'package:nexecute/models/event.dart';
import 'package:nexecute/home/bottomsheets/item_editor_sheet.dart';
import 'package:nexecute/shared/bottom_sheet_safe_area.dart';
import 'package:nexecute/shared/adaptive_navigation_shell.dart';

void showItemEditor(
  BuildContext context, {
  Event? event,
  Quicxec? quicxec,
  DateTime? date,
  bool isEditing = false,
}) {
  showModalBottomSheet(
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
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: SingleChildScrollView(
              child: ItemEditorSheet(
                event: event,
                quicxec: quicxec,
                date: date,
                isEditing: isEditing,
              ),
            ),
          ),
        ),
  );
}
