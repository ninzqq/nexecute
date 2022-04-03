import 'package:flutter/material.dart';
//import 'package:google_fonts/google_fonts.dart';

var appTheme = ThemeData(
  brightness: Brightness.dark,
  primaryColor: const Color.fromARGB(255, 32, 160, 160),
  canvasColor: const Color.fromARGB(255, 20, 20, 20),
  appBarTheme: const AppBarTheme(
    color: Color.fromARGB(255, 32, 41, 41),
  ),
  textTheme: const TextTheme(
    headline1: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
    headline2: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
    bodyText1: TextStyle(fontSize: 18),
    bodyText2: TextStyle(fontSize: 12),
  ),
);
