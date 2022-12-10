// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Count _$CountFromJson(Map<String, dynamic> json) => Count(
      uid: json['uid'] as String? ?? '',
      count: json['count'] as int? ?? 0,
    );

Map<String, dynamic> _$CountToJson(Count instance) => <String, dynamic>{
      'uid': instance.uid,
      'count': instance.count,
    };

Quicxec _$QuicxecFromJson(Map<String, dynamic> json) => Quicxec(
      id: json['id'] as int,
      title: json['title'] as String,
      done: json['done'] as bool,
    );

Map<String, dynamic> _$QuicxecToJson(Quicxec instance) => <String, dynamic>{
      'id': instance.id,
      'title': instance.title,
      'done': instance.done,
    };

QuicxecsList _$QuicxecsListFromJson(Map<String, dynamic> json) => QuicxecsList(
      quicxecsList: (json['quicxecsList'] as List<dynamic>?)
              ?.map((e) => Quicxec.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );

Map<String, dynamic> _$QuicxecsListToJson(QuicxecsList instance) =>
    <String, dynamic>{
      'quicxecsList': instance.quicxecsList,
    };

Task _$TaskFromJson(Map<String, dynamic> json) => Task(
      created: json['created'] == null
          ? null
          : DateTime.parse(json['created'] as String),
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      inProgress: json['inProgress'] as bool? ?? false,
      done: json['done'] as bool? ?? false,
      deadline: json['deadline'] == null
          ? null
          : DateTime.parse(json['deadline'] as String),
    );

Map<String, dynamic> _$TaskToJson(Task instance) => <String, dynamic>{
      'created': instance.created.toIso8601String(),
      'title': instance.title,
      'description': instance.description,
      'inProgress': instance.inProgress,
      'done': instance.done,
      'deadline': instance.deadline.toIso8601String(),
    };
