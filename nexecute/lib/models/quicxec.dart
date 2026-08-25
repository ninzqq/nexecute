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
}

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
}
