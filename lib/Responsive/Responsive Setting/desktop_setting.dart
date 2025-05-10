import 'package:datavault/theme/theme_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'name_edit_screen.dart'; // Import the new screen

class DesktopSetting extends StatefulWidget {
  const DesktopSetting({super.key});

  @override
  State<DesktopSetting> createState() => _DesktopSettingState();
}

class _DesktopSettingState extends State<DesktopSetting> {
  String userName = "Sarthak Kapoor";

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
              Icons.person,
              color: Theme.of(context).colorScheme.secondary,
            ),
            title: Text(
              'Device Name',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onBackground,
              ),
            ),
            subtitle: Text(
              userName,
              style: TextStyle(
                color: Theme.of(
                  context,
                ).colorScheme.onBackground.withOpacity(0.7),
              ),
            ),
            onTap: () async {
              final updatedName = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => NameEditScreen(currentName: userName),
                ),
              );
              if (updatedName != null && updatedName is String) {
                setState(() {
                  userName = updatedName;
                });
              }
            },
          ),
          Divider(),
          ListTile(
            leading: Icon(
              Icons.brightness_6,
              color: Theme.of(context).colorScheme.secondary,
            ),
            title: Text(
              themeProvider.isDarkMode ? 'Dark Mode' : 'Light Mode',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onBackground,
              ),
            ),
            trailing: Switch(
              value: themeProvider.isDarkMode,
              onChanged: (value) {
                themeProvider.toggleTheme();
              },
              activeColor: Theme.of(context).colorScheme.secondary,
            ),
          ),
        ],
      ),
    );
  }
}
