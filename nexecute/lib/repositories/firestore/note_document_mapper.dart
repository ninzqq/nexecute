import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:nexecute/models/quicxec.dart';

abstract final class NoteDocumentMapper {
  static Map<String, dynamic> toMap(Quicxec note) => {
    'id': note.id,
    'text': note.text,
    'title': note.title,
    'trashed': note.trashed,
    'tags': note.tags,
    'created': note.created,
    'contentType': note.contentType.name,
    'checklistItems': checklistItemsToData(note.checklistItems),
  };

  static Quicxec fromDocument(DocumentSnapshot<Map<String, dynamic>> document) {
    return fromMap(document.id, document.data() ?? const {});
  }

  static Quicxec fromMap(String id, Map<String, dynamic> data) {
    final rawItems = data['checklistItems'];
    return Quicxec(
      id: id,
      text: data['text']?.toString() ?? '',
      title: data['title']?.toString() ?? '',
      trashed: data['trashed'] == true,
      tags: _stringList(data['tags']),
      created: _date(data['created']) ?? DateTime.now(),
      contentType: NoteContentType.values.firstWhere(
        (type) => type.name == data['contentType'],
        orElse: () => NoteContentType.text,
      ),
      checklistItems:
          rawItems is List
              ? rawItems
                  .whereType<Map>()
                  .map(
                    (item) =>
                        _checklistItemFromMap(Map<String, dynamic>.from(item)),
                  )
                  .toList()
              : const [],
    );
  }

  static List<Map<String, dynamic>> checklistItemsToData(
    Iterable<NoteChecklistItem> items,
  ) {
    return items.map(_checklistItemToMap).toList();
  }

  static Map<String, dynamic> _checklistItemToMap(NoteChecklistItem item) => {
    'id': item.id,
    'text': item.text,
    'isChecked': item.isChecked,
  };

  static NoteChecklistItem _checklistItemFromMap(Map<String, dynamic> data) {
    return NoteChecklistItem(
      id: data['id']?.toString() ?? '',
      text: data['text']?.toString() ?? '',
      isChecked: data['isChecked'] == true,
    );
  }

  static DateTime? _date(Object? value) => switch (value) {
    Timestamp timestamp => timestamp.toDate(),
    DateTime date => date,
    _ => null,
  };

  static List<String> _stringList(Object? value) =>
      value is List ? value.map((item) => item.toString()).toList() : const [];
}
