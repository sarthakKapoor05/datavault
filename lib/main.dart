import 'package:datavault/Scrrens/biometrics_and_pin_page.dart';
import 'package:datavault/theme/theme.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_size/window_size.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  setWindowMinSize(const Size(600, 800));
  SharedPreferences prefs = await SharedPreferences.getInstance();
  String? savedPin = prefs.getString('userPin');
  runApp(MyApp(savedPin: savedPin));
}

class MyApp extends StatelessWidget {
  final String? savedPin;
  const MyApp({super.key, required this.savedPin});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: savedPin == null ? SetPinPage() : PinCheckPage(),
      theme: lightMode,
      darkTheme: darkMode,
    );
  }
}
