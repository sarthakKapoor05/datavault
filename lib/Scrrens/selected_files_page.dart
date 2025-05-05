import 'dart:io';

import 'package:flutter/material.dart';

class SelectedFilesPage extends StatelessWidget {
  final String? folderPath;
  final List<FileSystemEntity>? files;
  final List<String>? selectedFiles;

  const SelectedFilesPage({
    super.key,
    this.folderPath,
    this.files,
    this.selectedFiles,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Selected Files',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.black,
      ),
      backgroundColor: Colors.black,
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            if (folderPath != null) ...[
              const Text(
                'Selected Folder:',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(folderPath!, style: const TextStyle(color: Colors.white70)),
              const SizedBox(height: 16),
              const Text(
                'Files in Folder:',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              if (files != null && files!.isNotEmpty)
                ...files!.map((file) {
                  return ListTile(
                    title: Text(
                      file.path.split('/').last,
                      style: const TextStyle(color: Colors.white),
                    ),
                    leading: const Icon(
                      Icons.insert_drive_file,
                      color: Colors.white,
                    ),
                  );
                }).toList()
              else
                const Text(
                  'No files found in the selected folder.',
                  style: TextStyle(color: Colors.white70),
                ),
            ],
            if (selectedFiles != null && selectedFiles!.isNotEmpty) ...[
              const Text(
                'Selected Files:',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              ...selectedFiles!.map((filePath) {
                return ListTile(
                  title: Text(
                    filePath.split('/').last,
                    style: const TextStyle(color: Colors.white),
                  ),
                  leading: const Icon(
                    Icons.insert_drive_file,
                    color: Colors.white,
                  ),
                );
              }).toList(),
            ],
          ],
        ),
      ),
    );
  }
}
