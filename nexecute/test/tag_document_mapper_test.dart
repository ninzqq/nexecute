import 'package:nexecute/repositories/firestore/tag_document_mapper.dart';
import 'package:test/test.dart';

void main() {
  test('maps the user document tag array', () {
    final tags = TagDocumentMapper.fromMap({
      'tags': ['work', 'personal'],
    });

    expect(tags.tags, ['work', 'personal']);
    expect(TagDocumentMapper.toMap(tags), {
      'tags': ['work', 'personal'],
    });
  });

  test('uses an empty collection when tags are absent', () {
    expect(TagDocumentMapper.fromMap(const {}).tags, isEmpty);
  });
}
