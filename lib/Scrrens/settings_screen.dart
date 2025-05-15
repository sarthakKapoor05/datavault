import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:datavault/utils/storage_manager.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String? _currentStoragePath;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStoragePath();
  }

  Future<void> _loadStoragePath() async {
    final path = await StorageManager.getDefaultStoragePath();
    setState(() {
      _currentStoragePath = path;
      _isLoading = false;
    });
  }

  Future<void> _selectStorageLocation() async {
    try {
      final selectedDir = await FilePicker.platform.getDirectoryPath();

      if (selectedDir == null) return; // User canceled

      // Save the new storage location
      final success = await StorageManager.setDefaultStoragePath(selectedDir);

      if (success) {
        setState(() {
          _currentStoragePath = selectedDir;
        });

        // Notify the user the path was updated
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Storage location updated successfully'),
            action: SnackBarAction(
              label: 'View Files',
              onPressed: () {
                Navigator.pop(context); // Return to the dashboard
              },
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update storage location')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _resetToDefault() async {
    try {
      final documentsDir = await getApplicationDocumentsDirectory();
      final defaultPath = '${documentsDir.path}/Downloads';

      // Save the default path
      final success = await StorageManager.setDefaultStoragePath(defaultPath);

      if (success) {
        setState(() {
          _currentStoragePath = defaultPath;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Reset to default storage location')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Settings'), elevation: 0),
      body:
          _isLoading
              ? Center(child: CircularProgressIndicator())
              : ListView(
                padding: EdgeInsets.all(16),
                children: [
                  Card(
                    color: Theme.of(context).colorScheme.primary,
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Storage Settings',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 16),
                          Text('Default storage location:'),
                          SizedBox(height: 8),
                          Container(
                            padding: EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.background,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            width: double.infinity,
                            child: Text(
                              _currentStoragePath ?? 'Not set',
                              style: TextStyle(fontFamily: 'monospace'),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              ElevatedButton.icon(
                                icon: Icon(Icons.folder),
                                label: Text('Change Location'),
                                onPressed: _selectStorageLocation,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Color(0xFF50C2C9),
                                ),
                              ),
                              TextButton.icon(
                                icon: Icon(Icons.restore),
                                label: Text('Reset to Default'),
                                onPressed: _resetToDefault,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 16),
                  Card(
                    color: Theme.of(context).colorScheme.primary,
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Storage Information',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 16),
                          FutureBuilder<Directory>(
                            future: StorageManager.ensureDefaultStorageExists(),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState ==
                                  ConnectionState.waiting) {
                                return Center(
                                  child: CircularProgressIndicator(),
                                );
                              }

                              if (snapshot.hasError || !snapshot.hasData) {
                                return Text('Error checking storage');
                              }

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildInfoRow('Status', 'Ready to use'),
                                  _buildInfoRow('Path exists', 'Yes'),
                                  _buildInfoRow(
                                    'Used for',
                                    'Received files, Downloads',
                                  ),
                                ],
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey)),
          Text(value),
        ],
      ),
    );
  }
}
