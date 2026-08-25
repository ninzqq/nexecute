import 'package:nexecute/models/tag.dart';

abstract final class TagDocumentMapper {
  static Map<String, dynamic> toMap(Tags tags) => {'tags': tags.tags};

  static Tags fromMap(Map<String, dynamic> data) {
    final values = data['tags'];
    return Tags(
      tags:
          values is List
              ? values.map((value) => value.toString()).toList()
              : const [],
    );
  }
}
