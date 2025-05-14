import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'name_edit_screen.dart'; // Import the new screen

class DesktopSetting extends StatefulWidget {
  const DesktopSetting({super.key});

  @override
  State<DesktopSetting> createState() => _DesktopSettingState();
}

class _DesktopSettingState extends State<DesktopSetting> {
  String userName = "";

  @override
  void initState() {
    super.initState();
    _loadUserName();
  }

  Future<void> _loadUserName() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      userName = prefs.getString('device_name') ?? " Kapoor";
    });
  }

  Future<void> _saveUserName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('device_name', name);
  }

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
                await _saveUserName(updatedName);
              }
            },
          ),
          Divider(),
          ListTile(
          ),
        ],
      ),
    );
  }
}
