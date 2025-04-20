import 'package:json_annotation/json_annotation.dart';

part 'tag.g.dart';

class Tag {
  final String id;
  final String name;

  Tag({required this.id, required this.name});
}

@JsonSerializable()
class Tags {
  List<String> tags;

  Tags({this.tags = const []});

  factory Tags.fromJson(Map<String, dynamic> json) => _$TagsFromJson(json);
  Map<String, dynamic> toJson() => _$TagsToJson(this);
}
