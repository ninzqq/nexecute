import 'package:flutter/material.dart';
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
                      q.text.toLowerCase().contains(
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
                for (var q in activeQuicxecs) {
                  print(q.tags);
                }
              });
            },
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2.0),
            child: GridView.builder(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columnCount.columns,
                mainAxisExtent: 120,
                mainAxisSpacing: 1,
              ),
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
