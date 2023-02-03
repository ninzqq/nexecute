import 'package:flutter/material.dart';
import 'package:nexecute/shared/shared.dart';
import 'package:nexecute/services/services.dart';
import 'package:provider/provider.dart';

class TagsScreen extends StatelessWidget {
  const TagsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    var tags = context.watch<Tags>();
    final newTagController = TextEditingController();

    return Scaffold(
      appBar: AppBar(
        title: const Text(''),
        backgroundColor: appBarDarkCyan,
      ),
      body: Container(
        color: bgDarkCyan,
        child: Column(
          children: [
            Expanded(
              child: Container(
                child: ListView.builder(
                  itemCount: tags.tags.length,
                  itemBuilder: (BuildContext context, int index) {
                    return ListTile(
                      title: Text(tags.tags[index]),
                    );
                  },
                ),
              ),
            ),
            Padding(
              padding:
                  const EdgeInsets.only(bottom: 25.0, left: 10.0, right: 85.0),
              child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white70),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: TextField(
                      controller: newTagController,
                      keyboardType: TextInputType.text,
                      maxLines: 1,
                      expands: false,
                      keyboardAppearance: Brightness.dark,
                      decoration:
                          const InputDecoration.collapsed(hintText: 'Tag'),
                    ),
                  )),
            )
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: primaryButtonCyan,
        onPressed: () => {
          FirestoreService().addNewTag(newTagController.text),
          newTagController.text = '',
        },
        child: const Icon(Icons.new_label_outlined),
      ),
    );
  }
}
