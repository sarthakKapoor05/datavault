import 'package:flutter/material.dart';

ThemeData lightMode = ThemeData(
  brightness: Brightness.light,
  colorScheme: ColorScheme.light(
    background: const Color.fromARGB(241, 240, 243, 255),
    primary: const Color.fromARGB(255, 255, 255, 255),
    secondary: const Color.fromARGB(255, 0, 0, 0),
  ),
);

ThemeData dartMode = ThemeData(
  brightness: Brightness.dark,
  colorScheme: ColorScheme.dark(
    background: Colors.black,
    primary: Colors.grey.shade900,
    secondary: const Color.fromARGB(255, 255, 255, 255),
  ),
);
