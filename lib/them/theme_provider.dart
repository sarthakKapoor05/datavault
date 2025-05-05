import 'package:datavault/them/them.dart';
import 'package:flutter/material.dart';

class ThemeProvider with ChangeNotifier {
  ThemeData _themeData = dartMode;

  ThemeData get themeData => _themeData;

  set themeData(ThemeData themedata) {
    _themeData = themedata;
    notifyListeners();
  }

  void toggleTheme() {
    if (_themeData == lightMode) {
      _themeData = dartMode;
    } else {
      _themeData = lightMode;
    }
    notifyListeners();
  }
}
