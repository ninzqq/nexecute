import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:json_annotation/json_annotation.dart';
part 'models.g.dart';

@JsonSerializable()
class Count {
  final String uid;
  final int count;

  Count({
    this.uid = '',
    this.count = 0,
  });

  factory Count.fromJson(Map<String, dynamic> json) => _$CountFromJson(json);
  Map<String, dynamic> toJson() => _$CountToJson(this);
}

// For practice, a local model and provider for it.
class Asdf with ChangeNotifier {
  int asd;
  Asdf({
    this.asd = 0,
  });

  void incAsd() {
    asd += 1;
    notifyListeners();
  }
}

class HomeTabIndex with ChangeNotifier {
  int idx;
  HomeTabIndex({
    this.idx = 1,
  });

  void changeIndex(index) {
    idx = index;
    notifyListeners();
  }
}

class QuicxecsColumnCount extends ChangeNotifier {
  int columnCount;

  int get columns {
    return columnCount;
  }

  set columns(int columns) {
    columnCount = columns;
    notifyListeners();
  }

  QuicxecsColumnCount({
    this.columnCount = 2,
  });
}

@JsonSerializable()
class Quicxec {
  final String id;
  String text;
  String title;
  bool trashed;
  List<String> tags;

  Quicxec({
    required this.id,
    required this.text,
    this.title = '',
    this.trashed = false,
    this.tags = const [],
  });

  factory Quicxec.fromJson(Map<String, dynamic> json) =>
      _$QuicxecFromJson(json);
  Map<String, dynamic> toJson() => _$QuicxecToJson(this);

  factory Quicxec.fromMap(Map data) {
    data = data;
    return Quicxec(
      id: data['id'] ?? '',
      text: data['text'] ?? '',
      title: data['title'] ?? '',
      trashed: data['trashed'] ?? false,
      tags: data['tags'] ?? [],
    );
  }
}

@JsonSerializable()
class Tags {
  List<String> tags;

  Tags({
    this.tags = const [],
  });

  factory Tags.fromJson(Map<String, dynamic> json) => _$TagsFromJson(json);
  Map<String, dynamic> toJson() => _$TagsToJson(this);
}

@JsonSerializable()
class Task with ChangeNotifier {
  final DateTime created;
  final String title;
  final String description;
  final bool inProgress;
  final bool done;
  final DateTime deadline;

  Task({
    DateTime? created,
    this.title = '',
    this.description = '',
    this.inProgress = false,
    this.done = false,
    DateTime? deadline,
  })  : this.created = created ?? DateTime.now(),
        this.deadline = deadline ?? DateTime.now();

  factory Task.fromJson(Map<String, dynamic> json) => _$TaskFromJson(json);
  Map<String, dynamic> toJson() => _$TaskToJson(this);
}
