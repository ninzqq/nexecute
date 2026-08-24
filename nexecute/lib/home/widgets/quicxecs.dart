import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:nexecute/home/widgets/searchbox.dart';
import 'package:provider/provider.dart';
import 'package:nexecute/home/widgets/quicxecitem.dart';
import 'package:nexecute/models/quicxec.dart';
import 'package:nexecute/models/quicxec_column_count.dart';

class Quicxecs extends StatefulWidget {
  const Quicxecs({super.key});

  @override
  State<Quicxecs> createState() => _QuicxecsState();
}

class _QuicxecsState extends State<Quicxecs> {
  String searchQuery = '';

  @override
  Widget build(BuildContext context) {
    var columnCount = context.watch<QuicxecsColumnCount>();
    var allQuicxecs = context.watch<List<Quicxec>>();
    var activeQuicxecs = allQuicxecs.where((q) => !q.trashed).toList();

    // Filtteröi hakusanan perusteella
    var filteredQuicxecs =
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
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: MasonryGridView.count(
              padding: const EdgeInsets.only(bottom: 96),
              crossAxisCount: columnCount.columns,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              itemCount: filteredQuicxecs.length,
              itemBuilder: (context, index) {
                var quicxec = filteredQuicxecs[index];
                return QuicxecItem(quicxec: quicxec);
              },
            ),
          ),
        ),
      ],
    );
  }
}
