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
import 'package:storage_info/storage_info.dart';
import 'package:datavault/utils/storage_manager.dart';

class MobileDashboard extends StatelessWidget {
  const MobileDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return const FileManagerPage();
  }
}

class FileManagerPage extends StatefulWidget {
  const FileManagerPage({super.key});

  @override
  _FileManagerPageState createState() => _FileManagerPageState();
}

class _FileManagerPageState extends State<FileManagerPage> {
  double usedStorage = 0;
  double totalStorage = 0;
  String? _currentStoragePath;
  bool _isLoadingStoragePath = true;

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
    {'title': 'Storage Settings', 'icon': Icons.storage, 'color': Color(0xFF50C2C9)},
  ];

  @override
  void initState() {
    super.initState();
    getStorageInfo();
    _loadStoragePath(); // Add this line
  }

  Future<void> getStorageInfo() async {
    final storageInfo = StorageInfo();
    final totalStorage = await storageInfo.getStorageTotalSpace();
    final freeStorage = await storageInfo.getStorageFreeSpace();
    final usedStorage = totalStorage - freeStorage;

    // Convert to GB
    final usedGB = usedStorage / (1024 * 1024 * 1024);
    final totalGB = totalStorage / (1024 * 1024 * 1024);

    setState(() {
      this.usedStorage = usedGB;
      this.totalStorage = totalGB;
    });
  }

  // Add this method
  Future<void> _loadStoragePath() async {
    setState(() {
      _isLoadingStoragePath = true;
    });
    
    try {
      final path = await StorageManager.getDefaultStoragePath();
      setState(() {
        _currentStoragePath = path;
        _isLoadingStoragePath = false;
      });
    } catch (e) {
      print('Error loading storage path: $e');
      setState(() {
        _isLoadingStoragePath = false;
      });
    }
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
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Storage location updated'),
          action: SnackBarAction(
            label: 'Reset',
            onPressed: _resetToDefault,
          ),
        )
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update storage location'))
      );
    }
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error: $e'))
    );
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
        SnackBar(content: Text('Reset to default storage location'))
      );
    }
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error: $e'))
    );
  }
}

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: AppBar(
        title: Text(
          'Files',
          style: TextStyle(
            color: Theme.of(context).colorScheme.secondary,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Theme.of(context).colorScheme.background,
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.04),
          child: ListView(
            children: [
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: screenWidth * 0.03,
                  vertical: screenHeight * 0.015,
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
                    SizedBox(width: screenWidth * 0.025),
                    Expanded(
                      child: TextField(
                        readOnly: true,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.secondary,
                        ),
                        cursorColor: Colors.white70,
                        decoration: InputDecoration(
                          hintText: 'Search files, folsdjfhghders...',
                          hintStyle: TextStyle(
                            color: Theme.of(context).colorScheme.secondary,
                          ),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: screenHeight * 0.02),
              Text('Test'),
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
                  padding: EdgeInsets.all(screenWidth * 0.04),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Device storage',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.secondary,
                            ),
                          ),
                          Row(
                            children: [
                              IconButton(
                                icon: Icon(Icons.info_outline, size: 16),
                                padding: EdgeInsets.zero,
                                constraints: BoxConstraints(),
                                onPressed: () {
                                  showDialog(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      backgroundColor: Theme.of(context).colorScheme.primary,
                                      title: Text('Received Files Location'),
                                      content: Text('This is where files received from other devices will be stored.'),
                                      actions: [
                                        TextButton(
                                          child: Text('OK'),
                                          onPressed: () => Navigator.pop(context),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                                color: Theme.of(context).colorScheme.secondary,
                              ),
                              SizedBox(width: 5),
                              TextButton.icon(
                                icon: Icon(Icons.folder_open, size: 16),
                                label: Text('Change', style: TextStyle(fontSize: 12)),
                                onPressed: _selectStorageLocation,
                                style: TextButton.styleFrom(
                                  foregroundColor: Color(0xFF50C2C9),
                                  padding: EdgeInsets.symmetric(horizontal: 8),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      if (_currentStoragePath != null) ...[
                        Container(
                          padding: EdgeInsets.symmetric(vertical: 4),
                          width: double.infinity,
                          child: Text(
                            _currentStoragePath!,
                            style: TextStyle(
                              fontSize: 10,
                              color: Theme.of(context).colorScheme.secondary.withOpacity(0.7),
                              fontFamily: 'monospace',
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                      SizedBox(height: screenHeight * 0.01),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${usedStorage.toStringAsFixed(1)} GB / ${totalStorage.toStringAsFixed(1)} GB',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.secondary,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: screenHeight * 0.01),
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
              SizedBox(height: screenHeight * 0.025),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: categories.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1,
                ),
                itemBuilder: (context, index) {
                  return _buildCategoryCard(
                    context,
                    categories[index],
                    screenWidth,
                    screenHeight,
                  );
                },
              ),
              SizedBox(height: screenHeight * 0.025),
              const Text(
                'Sources',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: screenHeight * 0.015),
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
            final action = await showDialog<String>(
              context: context,
              builder:
                  (context) => AlertDialog(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    title: const Text('Select Option'),
                    content: const Text(
                      'Do you want to select files or a folder?',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, 'files'),
                        style: TextButton.styleFrom(
                          foregroundColor:
                              Theme.of(context).colorScheme.secondary,
                        ),
                        child: const Text('Files'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, 'folder'),
                        style: TextButton.styleFrom(
                          foregroundColor:
                              Theme.of(context).colorScheme.secondary,
                        ),
                        child: const Text('Folder'),
                      ),
                    ],
                  ),
            );

            if (action == 'files') {
              final result = await FilePicker.platform.pickFiles(
                allowMultiple: true,
              );
              if (result == null) return;

              for (var file in result.files) {
                debugPrint('Selected file: ${file.name}');
                openFile(file);
              }
            } else if (action == 'folder') {
              final directoryPath =
                  await FilePicker.platform.getDirectoryPath();
              if (directoryPath == null) return;

              debugPrint('Selected folder: $directoryPath');

              final directory = Directory(directoryPath);
              final files = directory.listSync();
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
    double screenWidth,
    double screenHeight,
  ) {
    return GestureDetector(
      onTap: () {
        switch (category['title']) {
          case 'Photos':
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PhotosScreen()),
            );
            break;
          case 'Videos':
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const VideosScreen()),
            );
            break;
          case 'Audio':
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AudioScreen()),
            );
            break;
          case 'Documents':
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const DocumentsScreen()),
            );
            break;
          case 'APKs':
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ApksScreen()),
            );
            break;
          case 'Archives':
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ArchivesScreen()),
            );
            break;
        }
      },
      child: Container(
        padding: EdgeInsets.symmetric(
          vertical: screenHeight * 0.02,
          horizontal: screenWidth * 0.01,
        ),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Icon(category['icon'], color: category['color'], size: 26),
            const SizedBox(height: 8),
            Text(
              category['title'],
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
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
      title: Text(source['title']),
      onTap: () {
        if (source['title'] == 'Received Files') {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ReceivedFilesScreen()),
          );
        } else if (source['title'] == 'Downloads') {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const DownloadsScreen()),
          );
        } else if (source['title'] == 'Storage Settings') {
          _showStorageSettingsDialog();
        }
      },
      contentPadding: const EdgeInsets.symmetric(vertical: 4),
    );
  }

  // Add this method to show a dialog for more storage options
  void _showStorageSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.primary,
        title: Text('Storage Settings'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Current location for received files:'),
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
          ],
        ),
        actions: [
          TextButton(
            child: Text('Reset to Default'),
            onPressed: () {
              _resetToDefault();
              Navigator.pop(context);
            },
          ),
          ElevatedButton(
            child: Text('Change Location'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFF50C2C9),
            ),
            onPressed: () {
              Navigator.pop(context);
              _selectStorageLocation();
            },
          ),
        ],
      ),
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

  // Create a new widget that clearly shows the current destination folder
  Widget _buildDestinationFolderCard(double screenWidth, double screenHeight) {
    return Container(
      padding: EdgeInsets.all(screenWidth * 0.04),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Color(0xFF50C2C9).withOpacity(0.5),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.folder_special,
                    color: Color(0xFF50C2C9),
                    size: 20,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Current Destination Folder',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.secondary,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
              TextButton.icon(
                icon: Icon(Icons.edit, size: 16),
                label: Text('Change', style: TextStyle(fontSize: 12)),
                onPressed: _selectStorageLocation,
                style: TextButton.styleFrom(
                  foregroundColor: Color(0xFF50C2C9),
                  padding: EdgeInsets.symmetric(horizontal: 8),
                ),
              ),
            ],
          ),
          SizedBox(height: screenHeight * 0.01),
          _isLoadingStoragePath 
              ? Center(child: CircularProgressIndicator())
              : Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.background,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.folder_open,
                        color: Colors.amber,
                        size: 18,
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _currentStoragePath ?? 'Not set',
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
          SizedBox(height: screenHeight * 0.01),
          
          Text(
            'Files received from other devices and downloads will be saved here.',
            style: TextStyle(
              color: Theme.of(context).colorScheme.secondary.withOpacity(0.7),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
