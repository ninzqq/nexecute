import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:nexecute/models/data_state.dart';
import 'package:nexecute/home/widgets/searchbox.dart';
import 'package:nexecute/shared/data_state_placeholder.dart';
import 'package:provider/provider.dart';
import 'package:nexecute/home/widgets/quicxecitem.dart';
import 'package:nexecute/models/quicxec.dart';

class Quicxecs extends StatefulWidget {
  const Quicxecs({super.key});

  @override
  State<Quicxecs> createState() => _QuicxecsState();
}

class _QuicxecsState extends State<Quicxecs> {
  String searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final state = context.watch<DataState<List<Quicxec>>>();

    return switch (state) {
      DataLoading<List<Quicxec>>() => const DataStatePlaceholder(
        presentation: DataStatePresentation.loading,
        title: 'Loading notes…',
      ),
      DataUnauthenticated<List<Quicxec>>() => const DataStatePlaceholder(
        presentation: DataStatePresentation.unauthenticated,
        message: 'Sign in to access your notes.',
      ),
      DataFailure<List<Quicxec>>() => const DataStatePlaceholder(
        presentation: DataStatePresentation.failure,
        title: 'Could not load notes',
      ),
      DataEmpty<List<Quicxec>>(:final value) => _buildNotes(context, value),
      DataReady<List<Quicxec>>(:final value) => _buildNotes(context, value),
    };
  }

  Widget _buildNotes(BuildContext context, List<Quicxec> allQuicxecs) {
    final activeQuicxecs = allQuicxecs.where((q) => !q.trashed).toList();

    // Filtteröi hakusanan perusteella
    final filteredQuicxecs =
        searchQuery.isEmpty
            ? activeQuicxecs
            : activeQuicxecs
                .where(
                  (q) =>
                      q.title.toLowerCase().contains(
                        searchQuery.toLowerCase(),
                      ) ||
                      q.searchableText.toLowerCase().contains(
                        searchQuery.toLowerCase(),
                      ) ||
                      q.tags.any(
                        (tag) => tag.toLowerCase().contains(
                          searchQuery.toLowerCase(),
                        ),
                      ),
                )
                .toList();

    return Column(
      children: [
        SizedBox(height: 2),
        SizedBox(
          child: SearchBox(
            onChanged: (value) {
              setState(() {
                searchQuery = value;
              });
            },
          ),
        ),
        Expanded(
          child:
              filteredQuicxecs.isEmpty
                  ? DataStatePlaceholder(
                    presentation: DataStatePresentation.empty,
                    title:
                        activeQuicxecs.isEmpty
                            ? 'No notes yet'
                            : 'No matching notes',
                    message:
                        activeQuicxecs.isEmpty
                            ? 'Create a note when inspiration strikes.'
                            : 'Try a different search.',
                  )
                  : Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: MasonryGridView.count(
                      padding: const EdgeInsets.only(bottom: 96),
                      crossAxisCount: 2,
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                      itemCount: filteredQuicxecs.length,
                      itemBuilder: (context, index) {
                        final quicxec = filteredQuicxecs[index];
                        return QuicxecItem(quicxec: quicxec);
                      },
                    ),
                  ),
        ),
      ],
    );
  }
}
