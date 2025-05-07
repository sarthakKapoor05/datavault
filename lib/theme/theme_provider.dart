import 'package:datavault/theme/theme.dart';
import 'package:flutter/material.dart';

class ThemeProvider with ChangeNotifier {
  ThemeData _themeData = dartMode;

  ThemeData get themeData => _themeData;

  bool get isDarkMode => themeData.brightness == Brightness.dark;

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
