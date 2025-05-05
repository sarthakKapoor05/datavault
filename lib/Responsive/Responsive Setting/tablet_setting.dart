import 'package:datavault/them/theme_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class TabletSetting extends StatefulWidget {
  const TabletSetting({super.key});

  @override
  State<TabletSetting> createState() => _TabletSettingState();
}

class _TabletSettingState extends State<TabletSetting> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Settings',
          style: TextStyle(color: Theme.of(context).colorScheme.secondary),
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
      ),
      backgroundColor: Theme.of(context).colorScheme.background,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            GestureDetector(
              onTap: () {
                Provider.of<ThemeProvider>(
                  context,
                  listen: false,
                ).toggleTheme(); // Toggle the theme when text is tapped
              },
              child: Text(
                'Settings',
                style: TextStyle(
                  fontSize: 24,
                  color: Theme.of(context).colorScheme.secondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
