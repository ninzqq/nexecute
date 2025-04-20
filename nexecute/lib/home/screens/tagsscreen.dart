import 'package:flutter/material.dart';
import 'package:nexecute/home/widgets/taglisttile.dart';
import 'package:nexecute/shared/shared.dart';
import 'package:nexecute/services/services.dart';
import 'package:provider/provider.dart';
import 'package:nexecute/models/tag.dart';

class TagsScreen extends StatelessWidget {
  const TagsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    var tags = context.watch<Tags>();
    final newTagController = TextEditingController();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tags'),
        backgroundColor: appBarDarkCyan,
      ),
      backgroundColor: bgDarkCyan,
      body: Column(
        children: [
          const SizedBox(height: 16),
          Expanded(
            child: ListView.builder(
              itemCount: tags.tags.length,
              itemBuilder: (BuildContext context, int index) {
                return TagListTile(tag: tags.tags[index]);
              },
            ),
          ),
          Row(
            children: [
              const SizedBox(width: 20),
              Expanded(
                child: Container(
                  width: MediaQuery.of(context).size.width,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white70),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: TextField(
                      controller: newTagController,
                      keyboardType: TextInputType.text,
                      maxLines: 1,
                      expands: false,
                      keyboardAppearance: Brightness.dark,
                      decoration: const InputDecoration.collapsed(
                        hintText: 'Tag',
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: darkCyan),
                onPressed: () {
                  FirestoreService().addNewTag(newTagController.text);
                  newTagController.text = '';
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 18.0),
                  child: const Icon(Icons.new_label_outlined, size: 30),
                ),
              ),
              const SizedBox(width: 20),
            ],
          ),
          // Small lift from bottom of the screen
          const SizedBox(height: 25),
        ],
      ),
    );
  }
}
