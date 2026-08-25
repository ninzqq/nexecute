import 'package:flutter/material.dart';
import 'package:nexecute/home/home.dart';
import 'package:nexecute/models/data_state.dart';
import 'package:nexecute/shared/data_state_placeholder.dart';
import 'package:provider/provider.dart';
import 'package:nexecute/buttons/emtpytrashpermanentlybutton.dart';
import 'package:nexecute/models/quicxec.dart';

class TrashScreen extends StatelessWidget {
  const TrashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<DataState<List<Quicxec>>>();
    final notes = state.valueOrNull ?? const <Quicxec>[];
    final trashedQuicxecs = notes.where((note) => note.trashed).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Trashed quicxecs'),
        actions: [
          EmptyTrashPermanentlyButton(enabled: trashedQuicxecs.isNotEmpty),
        ],
      ),
      body: switch (state) {
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
      },
    );
  }
}

class _TrashGrid extends StatelessWidget {
  const _TrashGrid({required this.notes});

  final List<Quicxec> notes;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisExtent: 120,
      ),
      itemCount: notes.length,
      itemBuilder: (context, index) {
        final quicxec = notes[index];
        return QuicxecItem(
          quicxec: Quicxec(
            id: quicxec.id,
            text: quicxec.text,
            title: quicxec.title,
            trashed: quicxec.trashed,
            tags: quicxec.tags,
            created: quicxec.created,
            contentType: quicxec.contentType,
            checklistItems: quicxec.checklistItems,
          ),
        );
      },
    );
  }
}
