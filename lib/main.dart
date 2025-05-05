import 'package:datavault/Scrrens/pin_page.dart';
import 'package:datavault/them/them.dart';
import 'package:datavault/them/theme_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_size/window_size.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SharedPreferences prefs = await SharedPreferences.getInstance();
  String? savedPin = prefs.getString('userPin');
  runApp(
    ChangeNotifierProvider(
      create: (context) => ThemeProvider(),
      child: MyApp(savedPin: savedPin),
    ),
  );
  WidgetsFlutterBinding.ensureInitialized();

  setWindowMinSize(const Size(600, 800));
}

class MyApp extends StatelessWidget {
  final String? savedPin;
  const MyApp({super.key, required this.savedPin});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: savedPin == null ? SetPinPage() : PinCheckPage(),
      theme: Provider.of<ThemeProvider>(context).themeData,
    );
  }
}
