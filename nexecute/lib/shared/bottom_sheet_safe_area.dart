import 'package:flutter/material.dart';

/// Keeps bottom-sheet content clear of system navigation and task bars.
///
/// Flutter's `showModalBottomSheet(useSafeArea: true)` only applies safe-area
/// padding to the top, left, and right edges, so the bottom inset needs to be
/// handled by the sheet content itself.
class BottomSheetSafeArea extends StatelessWidget {
  const BottomSheetSafeArea({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SafeArea(top: false, child: child);
  }
}
