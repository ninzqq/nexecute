import 'package:flutter/material.dart';
import 'package:nexecute/models/quicxec.dart';
import 'package:nexecute/models/tag.dart';
import 'package:nexecute/shared/shared.dart';
import '../home/widgets/taglistitem.dart';

class BottomMenubar extends StatelessWidget {
  final Quicxec quicxec;
  const BottomMenubar({super.key, required this.quicxec});

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.of(context).size;
    const double navBarHeight = 65.0;

    return SizedBox(
      width: size.width,
      height: navBarHeight,
      child: Container(
        color: appBarDarkCyan,
        child: Column(
          children: [
            SizedBox(
              height: 25,
              child: Padding(
                padding: const EdgeInsets.only(top: 5.0, left: 5.0),
                child: Row(
                  children: [
                    Flexible(
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: quicxec.tags.length,
                        itemBuilder: (BuildContext context, int index) {
                          return TagListItem(
                            tag: Tag(name: quicxec.tags[index]),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(
              width: size.width,
              height: 35,
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => {},
                    icon: const Icon(Icons.new_label_outlined),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
