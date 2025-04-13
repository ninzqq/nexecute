import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:json_annotation/json_annotation.dart';
part 'quicxec.g.dart';

@JsonSerializable()
class Quicxec {
  final String id;
  String text;
  String title;
  bool trashed;
  List<String> tags;
  final DateTime created;

  Quicxec({
    required this.id,
    required this.text,
    this.title = '',
    this.trashed = false,
    this.tags = const [],
    required this.created,
  });

  //factory Quicxec.fromJson(Map<String, dynamic> json) =>
  //   _$QuicxecFromJson(json);
  //Map<String, dynamic> toJson() => _$QuicxecToJson(this);

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'text': text,
      'title': title,
      'trashed': trashed,
      'tags': tags,
      'created': created,
    };
  }

  factory Quicxec.fromFirestore(DocumentSnapshot doc) {
    var rawTags = doc.get('tags') ?? [];
    List<String> tags = List<String>.from(rawTags.map((item) => item.toString()));
    
    return Quicxec(
      id: doc.id,
      text: doc.get('text') ?? '',
      title: doc.get('title') ?? '',
      trashed: doc.get('trashed') ?? false,
      tags: tags,
      created: doc.get('created').toDate(),
    );
  }
}