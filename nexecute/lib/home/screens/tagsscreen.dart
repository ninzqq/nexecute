import 'package:flutter/material.dart';
import 'package:nexecute/home/widgets/taglisttile.dart';
import 'package:nexecute/models/data_state.dart';
import 'package:nexecute/repositories/tag_repository.dart';
import 'package:nexecute/shared/data_state_placeholder.dart';
import 'package:provider/provider.dart';
import 'package:nexecute/models/tag.dart';

class TagsScreen extends StatelessWidget {
  const TagsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<DataState<Tags>>();

    return Scaffold(
      appBar: AppBar(title: const Text('Tags')),
      body: switch (state) {
        DataLoading<Tags>() => const DataStatePlaceholder(
          presentation: DataStatePresentation.loading,
          title: 'Loading tags…',
        ),
        DataUnauthenticated<Tags>() => const DataStatePlaceholder(
          presentation: DataStatePresentation.unauthenticated,
          message: 'Sign in to access your tags.',
        ),
        DataFailure<Tags>() => const DataStatePlaceholder(
          presentation: DataStatePresentation.failure,
          title: 'Could not load tags',
        ),
        DataEmpty<Tags>(:final value) => _TagsContent(tags: value),
        DataReady<Tags>(:final value) => _TagsContent(tags: value),
      },
    );
  }
}

class _TagsContent extends StatefulWidget {
  const _TagsContent({required this.tags});

  final Tags tags;

  @override
  State<_TagsContent> createState() => _TagsContentState();
}

class _TagsContentState extends State<_TagsContent> {
  final _newTagController = TextEditingController();

  @override
  void dispose() {
    _newTagController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 16),
        Expanded(
          child:
              widget.tags.tags.isEmpty
                  ? const DataStatePlaceholder(
                    presentation: DataStatePresentation.empty,
                    title: 'No tags yet',
                    message: 'Add a tag below to organize your items.',
                  )
                  : ListView.builder(
                    itemCount: widget.tags.tags.length,
                    itemBuilder: (BuildContext context, int index) {
                      return TagListTile(tag: widget.tags.tags[index]);
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
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outline,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: TextField(
                    controller: _newTagController,
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
              onPressed: () {
                if (_newTagController.text.isNotEmpty) {
                  context.read<TagRepository>().addTag(_newTagController.text);
                  _newTagController.clear();
                }
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
    );
  }
}
