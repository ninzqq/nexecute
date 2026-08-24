import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:json_annotation/json_annotation.dart';

enum NoteContentType { text, checklist }

class NoteChecklistItem {
  const NoteChecklistItem({
    required this.id,
    required this.text,
    this.isChecked = false,
  });

  final String id;
  final String text;
  final bool isChecked;

  NoteChecklistItem copyWith({String? text, bool? isChecked}) {
    return NoteChecklistItem(
      id: id,
      text: text ?? this.text,
      isChecked: isChecked ?? this.isChecked,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'text': text,
    'isChecked': isChecked,
  };

  factory NoteChecklistItem.fromMap(Map<String, dynamic> data) {
    return NoteChecklistItem(
      id: data['id']?.toString() ?? '',
      text: data['text']?.toString() ?? '',
      isChecked: data['isChecked'] == true,
    );
  }
}

@JsonSerializable()
class Quicxec {
  final String id;
  String text;
  String title;
  bool trashed;
  List<String> tags;
  final DateTime created;
  final NoteContentType contentType;
  final List<NoteChecklistItem> checklistItems;

  Quicxec({
    required this.id,
    required this.text,
    this.title = '',
    this.trashed = false,
    this.tags = const [],
    required this.created,
    this.contentType = NoteContentType.text,
    this.checklistItems = const [],
  });

  bool get isChecklist => contentType == NoteContentType.checklist;

  String get contentAsPlainText {
    if (!isChecklist) return text;
    return checklistItems
        .map((item) => '${item.isChecked ? '☑' : '☐'} ${item.text}')
        .join('\n');
  }

  String get searchableText =>
      [text, ...checklistItems.map((item) => item.text)].join(' ');

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'text': text,
      'title': title,
      'trashed': trashed,
      'tags': tags,
      'created': created,
      'contentType': contentType.name,
      'checklistItems': checklistItems.map((item) => item.toMap()).toList(),
    };
  }

  factory Quicxec.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    return Quicxec.fromMap(doc.id, doc.data() ?? const {});
  }

  factory Quicxec.fromMap(String id, Map<String, dynamic> data) {
    final rawTags = data['tags'];
    final rawItems = data['checklistItems'];
    final contentType = NoteContentType.values.firstWhere(
      (type) => type.name == data['contentType'],
      orElse: () => NoteContentType.text,
    );

    return Quicxec(
      id: id,
      text: data['text']?.toString() ?? '',
      title: data['title']?.toString() ?? '',
      trashed: data['trashed'] == true,
      tags:
          rawTags is List
              ? rawTags.map((item) => item.toString()).toList()
              : const [],
      created: _readDate(data['created']),
      contentType: contentType,
      checklistItems:
          rawItems is List
              ? rawItems
                  .whereType<Map>()
                  .map(
                    (item) => NoteChecklistItem.fromMap(
                      Map<String, dynamic>.from(item),
                    ),
                  )
                  .toList()
              : const [],
    );
  }

  static DateTime _readDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return DateTime.now();
  }
}
