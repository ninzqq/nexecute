import 'package:flutter/cupertino.dart';
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
