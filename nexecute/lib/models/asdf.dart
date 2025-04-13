import 'package:flutter/material.dart';

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