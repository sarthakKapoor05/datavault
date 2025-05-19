import 'package:datavault/Scrrens/biometrics_and_pin_page.dart';
import 'package:datavault/theme/theme.dart';
import 'package:datavault/widgets/file_request_dialog.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_size/window_size.dart';
import 'package:datavault/services/connection_service.dart';
import 'package:provider/provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  setWindowMinSize(const Size(600, 800));
  SharedPreferences prefs = await SharedPreferences.getInstance();
  String? savedPin = prefs.getString('userPin');
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ConnectionService()),
        // Add other providers here
      ],
      child: MyApp(savedPin: savedPin),
    ),
  );
}

class MyApp extends StatelessWidget {
  final String? savedPin;
  const MyApp({super.key, required this.savedPin});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Builder(
        builder: (context) => Stack(
          children: [
      savedPin == null ? SetPinPage() : PinCheckPage(),
            // Add this to handle file request dialogs
            FileRequestDialog(),
          ],
        ),
      ),
      theme: lightMode,
      darkTheme: darkMode,
    );
  }
}