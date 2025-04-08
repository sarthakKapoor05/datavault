import 'package:curved_navigation_bar/curved_navigation_bar.dart';
import 'package:datavault/Scrrens/dashboard.dart';
import 'package:datavault/Scrrens/settings.dart';
import 'package:datavault/Scrrens/share.dart';
import 'package:flutter/material.dart';

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  int index = 0;

  // ✅ Screens for navigation
  final screens = [Dashboard(), Share(), Settings()];

  @override
  Widget build(BuildContext context) {
    final items = <Widget>[
      Icon(Icons.folder, size: 30),
      Icon(Icons.ios_share_sharp, size: 30),
      Icon(Icons.settings_suggest_rounded, size: 30),
    ];

    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 0, 0, 0),
      body: index < screens.length ? screens[index] : screens[0],
      bottomNavigationBar: Theme(
        data: Theme.of(
          context,
        ).copyWith(iconTheme: IconThemeData(color: Colors.white)),
        child: CurvedNavigationBar(
          index: index,
          height: 60,
          color: Colors.blueGrey,
          buttonBackgroundColor: Colors.blueGrey[600],
          backgroundColor: const Color.fromARGB(255, 0, 0, 0),
          items: items,
          animationCurve: Curves.easeInOut,
          animationDuration: Duration(milliseconds: 300),
          onTap: (selectedIcon) {
            setState(() {
              index = selectedIcon;
            });
          },
        ),
      ),
    );
  }
}
