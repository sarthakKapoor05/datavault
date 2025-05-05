import 'package:datavault/them/theme_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class DesktopSetting extends StatefulWidget {
  const DesktopSetting({super.key});

  @override
  State<DesktopSetting> createState() => _DesktopSettingState();
}

class _DesktopSettingState extends State<DesktopSetting> {
  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Settings',
          style: TextStyle(color: Theme.of(context).colorScheme.secondary),
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
      ),
      backgroundColor: Theme.of(context).colorScheme.background,
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          ListTile(
            leading: Icon(
              Icons.brightness_6,
              color: Theme.of(context).colorScheme.secondary,
            ),
            title: const Text('Dark Mode'),
            trailing: Switch(
              value: themeProvider.isDarkMode,
              onChanged: (value) {
                themeProvider.toggleTheme();
              },
              activeColor: Theme.of(context).colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}
