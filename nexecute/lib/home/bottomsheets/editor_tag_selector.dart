import 'package:flutter/material.dart';
import 'package:nexecute/home/bottomsheets/tag_selector.dart';
import 'package:nexecute/models/data_state.dart';
import 'package:nexecute/models/tag.dart';
import 'package:nexecute/shared/data_state_placeholder.dart';
import 'package:provider/provider.dart';

class EditorTagSelector extends StatelessWidget {
  const EditorTagSelector({
    super.key,
    required this.selectedTags,
    required this.onTagToggled,
  });

  final List<String> selectedTags;
  final ValueChanged<String> onTagToggled;

  @override
  Widget build(BuildContext context) {
    return switch (context.watch<DataState<Tags>>()) {
      DataReady<Tags>(:final value) ||
      DataEmpty<Tags>(:final value) => TagSelector(
        tags: value.tags,
        selectedTags: selectedTags,
        onTagToggled: onTagToggled,
      ),
      DataLoading<Tags>() => const DataStatePlaceholder(
        presentation: DataStatePresentation.loading,
        title: 'Loading tags…',
        message: '',
        compact: true,
      ),
      DataUnauthenticated<Tags>() => const DataStatePlaceholder(
        presentation: DataStatePresentation.unauthenticated,
        title: 'Sign in to use tags',
        message: '',
        compact: true,
      ),
      DataFailure<Tags>() => const DataStatePlaceholder(
        presentation: DataStatePresentation.failure,
        title: 'Could not load tags',
        message: 'You can still save this item.',
        compact: true,
      ),
    };
  }
}
