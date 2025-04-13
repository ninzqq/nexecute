// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'quicxec.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Quicxec _$QuicxecFromJson(Map<String, dynamic> json) => Quicxec(
  id: json['id'] as String,
  text: json['text'] as String,
  title: json['title'] as String? ?? '',
  trashed: json['trashed'] as bool? ?? false,
  tags:
      (json['tags'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      const [],
  created: DateTime.parse(json['created']),
);

Map<String, dynamic> _$QuicxecToJson(Quicxec instance) => <String, dynamic>{
  'id': instance.id,
  'text': instance.text,
  'title': instance.title,
  'trashed': instance.trashed,
  'tags': instance.tags,
  'created': instance.created.toIso8601String(),
};
