import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:nexecute/home/widgets/quicxecitem.dart';
import 'package:nexecute/models/data_state.dart';
import 'package:nexecute/shared/adaptive_navigation_shell.dart';
import 'package:nexecute/shared/data_state_placeholder.dart';
import 'package:provider/provider.dart';
import 'package:nexecute/buttons/emtpytrashpermanentlybutton.dart';
import 'package:nexecute/models/quicxec.dart';

class TrashScreen extends StatelessWidget {
  const TrashScreen({super.key, this.embedded = false});

  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<DataState<List<Quicxec>>>();
    final notes = state.valueOrNull ?? const <Quicxec>[];
    final trashedQuicxecs = notes.where((note) => note.trashed).toList();

    final content = switch (state) {
      DataLoading<List<Quicxec>>() => const DataStatePlaceholder(
        presentation: DataStatePresentation.loading,
        title: 'Loading trash…',
      ),
      DataUnauthenticated<List<Quicxec>>() => const DataStatePlaceholder(
        presentation: DataStatePresentation.unauthenticated,
        message: 'Sign in to access your trash.',
      ),
      DataFailure<List<Quicxec>>() => const DataStatePlaceholder(
        presentation: DataStatePresentation.failure,
        title: 'Could not load trash',
      ),
      DataEmpty<List<Quicxec>>() => const DataStatePlaceholder(
        presentation: DataStatePresentation.empty,
        title: 'Trash is empty',
      ),
      DataReady<List<Quicxec>>() when trashedQuicxecs.isEmpty =>
        const DataStatePlaceholder(
          presentation: DataStatePresentation.empty,
          title: 'Trash is empty',
        ),
      DataReady<List<Quicxec>>() => _TrashGrid(notes: trashedQuicxecs),
    };

    if (embedded) {
      return Material(
        key: const Key('desktop-trash-tab'),
        color: Theme.of(context).scaffoldBackgroundColor,
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: EmptyTrashPermanentlyButton(
                  enabled: trashedQuicxecs.isNotEmpty,
                ),
              ),
            ),
            const Divider(height: 1),
            Expanded(child: content),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Trashed quicxecs'),
        actions: [
          EmptyTrashPermanentlyButton(enabled: trashedQuicxecs.isNotEmpty),
        ],
      ),
      body: content,
    );
  }
}

class _TrashGrid extends StatelessWidget {
  const _TrashGrid({required this.notes});

  final List<Quicxec> notes;

  @override
  Widget build(BuildContext context) {
    final columnCount =
        AppLayoutBreakpoints.fromContext(context).notesColumnCount;
    return MasonryGridView.count(
      key: const Key('trash-notes-grid'),
      padding: const EdgeInsets.all(8),
      crossAxisCount: columnCount,
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      itemCount: notes.length,
      itemBuilder: (context, index) {
        final quicxec = notes[index];
        return QuicxecItem(
          key: ValueKey('trash-note-${quicxec.id}'),
          quicxec: quicxec,
        );
      },
    );
  }
}
