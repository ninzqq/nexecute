import 'package:flutter/material.dart';
import 'package:nexecute/shared/shared.dart';
//import 'package:google_fonts/google_fonts.dart';

var appTheme = ThemeData(
  brightness: Brightness.dark,
  primaryColor: const Color.fromARGB(255, 32, 160, 160),
  canvasColor: const Color.fromARGB(255, 20, 20, 20),
  appBarTheme: const AppBarTheme(
    color: Color.fromARGB(255, 32, 41, 41),
  ),
  textTheme: const TextTheme(
    displayLarge: TextStyle(
      fontSize: 24,
      fontWeight: FontWeight.bold,
      color: almostWhite,
    ),
    displayMedium: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
    bodyLarge: TextStyle(fontSize: 18),
    bodyMedium: TextStyle(fontSize: 12),
  ),
);
