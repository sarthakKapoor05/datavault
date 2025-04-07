import 'package:flutter/material.dart';

class ReceivedFilesScreen extends StatelessWidget {
  const ReceivedFilesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Received Files',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      backgroundColor: Colors.black,
      body: ListView.builder(
        itemCount: 10, // Replace with actual number of received files
        itemBuilder: (context, index) {
          return ListTile(
            leading: const Icon(Icons.file_present, color: Colors.white),
            title: Text(
              'File $index',
              style: const TextStyle(color: Colors.white),
            ),
            subtitle: const Text(
              'Received via Nearby/Bluetooth',
              style: TextStyle(color: Colors.white60),
            ),
            onTap: () {
              // TODO: Add file open or action
            },
          );
        },
      ),
    );
  }
}
