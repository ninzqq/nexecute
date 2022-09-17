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

  int getCount() {
    return Count().count;
  }
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

@JsonSerializable()
class Quicxec {
  final String title;
  final bool done;

  const Quicxec({
    required this.title,
    required this.done,
  });

  factory Quicxec.fromJson(Map<String, dynamic> json) =>
      _$QuicxecFromJson(json);
  Map<String, dynamic> toJson() => _$QuicxecToJson(this);
}

@JsonSerializable()
class QuicxecsList with ChangeNotifier {
  final List<Quicxec> quicxecsList;

  QuicxecsList({
    this.quicxecsList = const [],
  });

  factory QuicxecsList.fromJson(Map<String, dynamic> json) =>
      _$QuicxecsListFromJson(json);
  Map<String, dynamic> toJson() => _$QuicxecsListToJson(this);
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
