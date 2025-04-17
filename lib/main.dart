import 'package:datavault/Scrrens/pin_page.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
      home: savedPin == null ? SetPinPage() : PinCheckPage()
    );
  }
}
