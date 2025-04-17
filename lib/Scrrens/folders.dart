import 'package:flutter/material.dart';

class FolderListScreen extends StatelessWidget {
  const FolderListScreen({super.key});

  // Example folder metadata
  final List<Map<String, String>> folders = const [
    // {'name': 'Alarms', 'date': '4 March'},
    {'name': 'Android', 'date': '4 March'},
    {'name': 'Audiobooks', 'date': '4 March'},
    {'name': 'DCIM', 'date': '14 March'},
    {'name': 'Documents', 'date': '4 March'},
    {'name': 'Download', 'date': '4 March'},
    {'name': 'Movies', 'date': '14 March'},
    {'name': 'Music', 'date': '4 March'},
    {'name': 'Notifications', 'date': '4 March'},
    {'name': 'Pictures', 'date': '10 March'},
    {'name': 'Podcasts', 'date': '4 March'},
    {'name': 'Recordings', 'date': '4 March'},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Device Storage',
          style: TextStyle(color: Colors.white), // White text in AppBar
        ),
        backgroundColor: Colors.black, // Black AppBar background
        iconTheme: const IconThemeData(color: Colors.white), // White back arrow
      ),
      backgroundColor: Colors.black, // Set background color to black
      body: ListView.builder(
        itemCount: folders.length,
        itemBuilder: (context, index) {
          return ListTile(
            leading: const Icon(Icons.folder, color: Colors.blue, size: 36.0),
            title: Text(
              folders[index]['name']!,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white, // White text color
              ),
            ),
            subtitle: Text(
              "Last modified: ${folders[index]['date']}",
              style: const TextStyle(
                color: Colors.white70,
              ), // Light white text for subtitle
            ),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('${folders[index]['name']} opened')),
              );
            },
          );
        },
      ),
    );
  }
}
