import 'dart:io';
import 'package:datavault/Scrrens/Folders/apks_screen.dart';
import 'package:datavault/Scrrens/Folders/archives_screen.dart';
import 'package:datavault/Scrrens/Folders/audio_screen.dart';
import 'package:datavault/Scrrens/Folders/documents_screen.dart';
import 'package:datavault/Scrrens/downloads_screen.dart';
import 'package:datavault/Scrrens/Folders/photos_screen.dart';
import 'package:datavault/Scrrens/Folders/videos_screen.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:datavault/Scrrens/folders.dart';
import 'package:datavault/Scrrens/received_files_screen.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';

class DesktopDashboard extends StatelessWidget {
  const DesktopDashboard({super.key});
  @override
  Widget build(BuildContext context) {
    return FileManagerPage();
  }
}

class FileManagerPage extends StatefulWidget {
  const FileManagerPage({super.key});

  @override
  _FileManagerPageState createState() => _FileManagerPageState();
}

class _FileManagerPageState extends State<FileManagerPage> {
  bool isTextFieldEditable = false;
  final double usedStorage = 28;
  final double totalStorage = 128.0;

  final List<Map<String, dynamic>> categories = [
    {
      'title': 'Photos',
      'count': 200,
      'icon': Icons.photo,
      'color': Colors.blue,
    },
    {
      'title': 'Videos',
      'count': 100,
      'icon': Icons.video_collection,
      'color': Colors.purple,
    },
    {
      'title': 'Audio',
      'count': 255,
      'icon': Icons.music_note,
      'color': Colors.orange,
    },
    {
      'title': 'Documents',
      'count': 90,
      'icon': Icons.insert_drive_file,
      'color': Colors.lightBlue,
    },
    {'title': 'APKs', 'count': 5, 'icon': Icons.android, 'color': Colors.green},
    {
      'title': 'Archives',
      'count': 11,
      'icon': Icons.archive,
      'color': Colors.brown,
    },
  ];

  final List<Map<String, dynamic>> sources = [
    {
      'title': 'Received Files',
      'icon': Icons.file_present,
      'color': Colors.blue,
    },
    {'title': 'Downloads', 'icon': Icons.download, 'color': Colors.blue},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: AppBar(
        title: Text(
          'Desktop Files',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Theme.of(context).colorScheme.background,
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: ListView(
            children: [
              GestureDetector(
                onTap: () {
                  setState(() {
                    isTextFieldEditable = true; // Enable editing on tap
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.search,
                        color: Theme.of(context).colorScheme.secondary,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          readOnly: !isTextFieldEditable,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.secondary,
                          ),
                          cursorColor: Theme.of(context).colorScheme.secondary,
                          decoration: InputDecoration(
                            hintText: 'Search files, folders...',
                            hintStyle: TextStyle(
                              color: Theme.of(context).colorScheme.secondary,
                            ),
                            border: InputBorder.none,
                          ),
                          onChanged: (value) {
                            // 🔍 You can implement real-time filtering here if needed
                          },
                          onTap: () {
                            setState(() {
                              isTextFieldEditable =
                                  true; // Enable editing on tap
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const FolderListScreen(),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Device storage', style: TextStyle()),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${usedStorage.toStringAsFixed(1)} GB / ${totalStorage.toStringAsFixed(1)} GB',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: usedStorage / totalStorage,
                        backgroundColor: Colors.grey[700],
                        color: Colors.green,
                        minHeight: 8,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 12,
                runSpacing: 18,
                children:
                    categories
                        .map(
                          (category) => _buildCategoryCard(context, category),
                        )
                        .toList(),
              ),
              const SizedBox(height: 20),
              const Text(
                'Sources',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Column(
                children:
                    sources.map((source) => _buildSourceTile(source)).toList(),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          try {
            // Show a dialog to let the user choose between selecting files or a folder
            final action = await showDialog<String>(
              context: context,
              builder:
                  (context) => AlertDialog(
                    title: const Text('Select Option'),
                    content: const Text(
                      'Do you want to select files or a folder?',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, 'files'),
                        child: const Text('Files'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, 'folder'),
                        child: const Text('Folder'),
                      ),
                    ],
                  ),
            );

            if (action == 'files') {
              // Allow the user to select multiple files
              final result = await FilePicker.platform.pickFiles(
                allowMultiple: true,
              );
              if (result == null) return; // User canceled the picker

              for (var file in result.files) {
                debugPrint('Selected file: ${file.name}');
                openFile(file);
              }
            } else if (action == 'folder') {
              // Allow the user to select a folder
              final directoryPath =
                  await FilePicker.platform.getDirectoryPath();
              if (directoryPath == null) return; // User canceled the picker

              debugPrint('Selected folder: $directoryPath');

              // List the files in the selected folder
              final directory = Directory(directoryPath);
              final files = directory.listSync(); // List all files and folders
              for (var file in files) {
                debugPrint('File: ${file.path}');
              }
            }
          } catch (e) {
            debugPrint('Error selecting files or folder: $e');
          }
        },
        backgroundColor: Colors.blueGrey[600],
        child: const Icon(Icons.folder, color: Colors.white),
      ),
    );
  }

  Widget _buildCategoryCard(
    BuildContext context,
    Map<String, dynamic> category,
  ) {
    return GestureDetector(
      onTap: () {
        if (category['title'] == 'Photos') {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const PhotosScreen()),
          );
        } else if (category['title'] == 'Videos') {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const VideosScreen()),
          );
        } else if (category['title'] == 'Audio') {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AudioScreen()),
          );
        } else if (category['title'] == 'Documents') {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const DocumentsScreen()),
          );
        } else if (category['title'] == 'APKs') {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const ApksScreen()),
          );
        } else if (category['title'] == 'Archives') {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const ArchivesScreen()),
          );
        }
      },
      child: Container(
        width: (MediaQuery.of(context).size.width / 4) - 100,
        padding: EdgeInsets.all(100),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(category['icon'], color: category['color'], size: 30),
            const SizedBox(height: 8),
            Text(category['title'], style: const TextStyle()),
            const SizedBox(height: 4),
            Text(
              category['count'].toString(),
              style: const TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSourceTile(Map<String, dynamic> source) {
    return ListTile(
      leading: Icon(source['icon'], color: source['color'], size: 32),
      title: Text(source['title'], style: const TextStyle()),
      onTap: () {
        if (source['title'] == 'Received Files') {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const ReceivedFilesScreen(),
            ),
          );
        } else if (source['title'] == 'Downloads') {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const DownloadsScreen()),
          );
        }
      },
      contentPadding: const EdgeInsets.symmetric(vertical: 4),
    );
  }

  Future<Future<File>> saveFilesPermanently(PlatformFile file) async {
    final appStorage = await getApplicationDocumentsDirectory();
    final newFile = File('${appStorage.path}/${file.name}');

    return File(file.path!).copy(newFile.path);
  }

  void openFile(PlatformFile file) {
    OpenFile.open(file.path);
  }
}
// }  here is the full code 