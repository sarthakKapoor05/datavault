import 'dart:io';
import 'package:datavault/Scrrens/Folders/apks_screen.dart';
import 'package:datavault/Scrrens/Folders/archives_screen.dart';
import 'package:datavault/Scrrens/Folders/audio_screen.dart';
import 'package:datavault/Scrrens/Folders/documents_screen.dart';
import 'package:datavault/Scrrens/downloads_screen.dart';
import 'package:datavault/Scrrens/Folders/photos_screen.dart';
import 'package:datavault/Scrrens/Folders/videos_screen.dart';
import 'package:datavault/Scrrens/settings_screen.dart';
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
  String? _currentStoragePath;

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
    {'title': 'Settings', 'icon': Icons.settings, 'color': Colors.grey},
  ];

  Map<String, List<String>> categoryExtensions = {
    'Photos': ['.jpg', '.jpeg', '.png', '.gif', '.bmp', '.webp'],
    'Videos': ['.mp4', '.avi', '.mov', '.mkv', '.flv', '.wmv'],
    'Audio': ['.mp3', '.wav', '.aac', '.ogg', '.flac', '.m4a'],
    'Documents': [
      '.pdf',
      '.doc',
      '.docx',
      '.xls',
      '.xlsx',
      '.ppt',
      '.pptx',
      '.txt',
    ],
    'APKs': ['.apk'],
    'Archives': ['.zip', '.rar', '.tar', '.gz', '.7z'],
  };

  @override
  void initState() {
    super.initState();
    _scanAndUpdateCategories();
  }

  Future<void> _scanAndUpdateCategories() async {
    final dir = await getApplicationDocumentsDirectory();
    final files = dir.listSync(recursive: true, followLinks: false);

    Map<String, int> counts = {for (var key in categoryExtensions.keys) key: 0};

    for (var entity in files) {
      if (entity is File) {
        final ext = entity.path.toLowerCase();
        categoryExtensions.forEach((cat, exts) {
          if (exts.any((e) => ext.endsWith(e))) {
            counts[cat] = (counts[cat] ?? 0) + 1;
          }
        });
      }
    }

    setState(() {
      for (var cat in categories) {
        cat['count'] = counts[cat['title']] ?? 0;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: AppBar(
        title: Text(
          'Files',
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
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: categories.length,
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 200,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  childAspectRatio: 1,
                ),
                itemBuilder: (context, index) {
                  return _buildCategoryCard(context, categories[index]);
                },
              ),

              const SizedBox(height: 20),
              Text(
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
        width: (MediaQuery.of(context).size.width / 3) - 20,
        height: 100,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 1),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.spaceEvenly, // 👈 beautifully spread content

          children: [
            Icon(category['icon'], color: category['color'], size: 32),
            const SizedBox(height: 8),
            Text(
              category['title'],
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
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
        } else if (source['title'] == 'Settings') {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const SettingsScreen()),
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

class PhotosScreen extends StatelessWidget {
  const PhotosScreen({super.key});

  Future<List<FileSystemEntity>> _getPhotoFiles() async {
    final dir = await getApplicationDocumentsDirectory();
    final files =
        dir.listSync(recursive: true, followLinks: false).where((entity) {
          final path = entity.path.toLowerCase();
          return entity is File &&
              (path.endsWith('.jpg') ||
                  path.endsWith('.jpeg') ||
                  path.endsWith('.png') ||
                  path.endsWith('.gif') ||
                  path.endsWith('.bmp') ||
                  path.endsWith('.webp'));
        }).toList();
    return files;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Photos')),
      body: FutureBuilder<List<FileSystemEntity>>(
        future: _getPhotoFiles(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No photos found.'));
          }
          final files = snapshot.data!;
          return GridView.builder(
            padding: const EdgeInsets.all(8),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: files.length,
            itemBuilder: (context, index) {
              final file = files[index] as File;
              return GestureDetector(
                onTap: () {
                  // Optionally, open the image in a viewer
                },
                child: Image.file(file, fit: BoxFit.cover),
              );
            },
          );
        },
      ),
    );
  }
}

class VideosScreen extends StatelessWidget {
  const VideosScreen({super.key});

  Future<List<FileSystemEntity>> _getVideoFiles() async {
    final dir = await getApplicationDocumentsDirectory();
    final files =
        dir.listSync(recursive: true, followLinks: false).where((entity) {
          final path = entity.path.toLowerCase();
          return entity is File &&
              (path.endsWith('.mp4') ||
                  path.endsWith('.avi') ||
                  path.endsWith('.mov') ||
                  path.endsWith('.mkv') ||
                  path.endsWith('.flv') ||
                  path.endsWith('.wmv'));
        }).toList();
    return files;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Videos')),
      body: FutureBuilder<List<FileSystemEntity>>(
        future: _getVideoFiles(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No videos found.'));
          }
          final files = snapshot.data!;
          return ListView.builder(
            itemCount: files.length,
            itemBuilder: (context, index) {
              final file = files[index] as File;
              final fileName = file.path.split(Platform.pathSeparator).last;
              return ListTile(
                leading: const Icon(Icons.videocam),
                title: Text(fileName),
                onTap: () {
                  // Optionally, open the video file
                },
              );
            },
          );
        },
      ),
    );
  }
}

class AudioScreen extends StatelessWidget {
  const AudioScreen({super.key});

  Future<List<FileSystemEntity>> _getAudioFiles() async {
    final dir = await getApplicationDocumentsDirectory();
    final files =
        dir.listSync(recursive: true, followLinks: false).where((entity) {
          final path = entity.path.toLowerCase();
          return entity is File &&
              (path.endsWith('.mp3') ||
                  path.endsWith('.wav') ||
                  path.endsWith('.aac') ||
                  path.endsWith('.ogg') ||
                  path.endsWith('.flac') ||
                  path.endsWith('.m4a'));
        }).toList();
    return files;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Audio')),
      body: FutureBuilder<List<FileSystemEntity>>(
        future: _getAudioFiles(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No audio files found.'));
          }
          final files = snapshot.data!;
          return ListView.builder(
            itemCount: files.length,
            itemBuilder: (context, index) {
              final file = files[index] as File;
              final fileName = file.path.split(Platform.pathSeparator).last;
              return ListTile(
                leading: const Icon(Icons.music_note),
                title: Text(fileName),
                onTap: () {
                  // Optionally, open the audio file
                },
              );
            },
          );
        },
      ),
    );
  }
}

class DocumentsScreen extends StatelessWidget {
  const DocumentsScreen({super.key});

  Future<List<FileSystemEntity>> _getDocumentFiles() async {
    final dir = await getApplicationDocumentsDirectory();
    final files =
        dir.listSync(recursive: true, followLinks: false).where((entity) {
          final path = entity.path.toLowerCase();
          return entity is File &&
              (path.endsWith('.pdf') ||
                  path.endsWith('.doc') ||
                  path.endsWith('.docx') ||
                  path.endsWith('.xls') ||
                  path.endsWith('.xlsx') ||
                  path.endsWith('.ppt') ||
                  path.endsWith('.pptx') ||
                  path.endsWith('.txt'));
        }).toList();
    return files;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Documents')),
      body: FutureBuilder<List<FileSystemEntity>>(
        future: _getDocumentFiles(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No documents found.'));
          }
          final files = snapshot.data!;
          return ListView.builder(
            itemCount: files.length,
            itemBuilder: (context, index) {
              final file = files[index] as File;
              final fileName = file.path.split(Platform.pathSeparator).last;
              return ListTile(
                leading: const Icon(Icons.insert_drive_file),
                title: Text(fileName),
                onTap: () {
                  // Optionally, open the document file
                },
              );
            },
          );
        },
      ),
    );
  }
}

class ApksScreen extends StatelessWidget {
  const ApksScreen({super.key});

  Future<List<FileSystemEntity>> _getApkFiles() async {
    final dir = await getApplicationDocumentsDirectory();
    final files =
        dir.listSync(recursive: true, followLinks: false).where((entity) {
          final path = entity.path.toLowerCase();
          return entity is File && path.endsWith('.apk');
        }).toList();
    return files;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('APKs')),
      body: FutureBuilder<List<FileSystemEntity>>(
        future: _getApkFiles(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No APKs found.'));
          }
          final files = snapshot.data!;
          return ListView.builder(
            itemCount: files.length,
            itemBuilder: (context, index) {
              final file = files[index] as File;
              final fileName = file.path.split(Platform.pathSeparator).last;
              return ListTile(
                leading: const Icon(Icons.android),
                title: Text(fileName),
                onTap: () {
                  // Optionally, open the APK file
                },
              );
            },
          );
        },
      ),
    );
  }
}

class ArchivesScreen extends StatelessWidget {
  const ArchivesScreen({super.key});

  Future<List<FileSystemEntity>> _getArchiveFiles() async {
    final dir = await getApplicationDocumentsDirectory();
    final files =
        dir.listSync(recursive: true, followLinks: false).where((entity) {
          final path = entity.path.toLowerCase();
          return entity is File &&
              (path.endsWith('.zip') ||
                  path.endsWith('.rar') ||
                  path.endsWith('.tar') ||
                  path.endsWith('.gz') ||
                  path.endsWith('.7z'));
        }).toList();
    return files;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Archives')),
      body: FutureBuilder<List<FileSystemEntity>>(
        future: _getArchiveFiles(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No archives found.'));
          }
          final files = snapshot.data!;
          return ListView.builder(
            itemCount: files.length,
            itemBuilder: (context, index) {
              final file = files[index] as File;
              final fileName = file.path.split(Platform.pathSeparator).last;
              return ListTile(
                leading: const Icon(Icons.archive),
                title: Text(fileName),
                onTap: () {
                  // Optionally, open the archive file
                },
              );
            },
          );
        },
      ),
    );
  }
}
