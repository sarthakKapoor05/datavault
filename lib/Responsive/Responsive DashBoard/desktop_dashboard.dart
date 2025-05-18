import 'dart:async';
import 'dart:convert'; // For jsonEncode
import 'dart:io';
import 'package:datavault/Scrrens/downloads_screen.dart';
import 'package:datavault/Scrrens/settings_screen.dart';
import 'package:datavault/Scrrens/remote_files_screen.dart'; // Add this line
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:datavault/Scrrens/folders.dart';
import 'package:datavault/Scrrens/received_files_screen.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:datavault/utils/storage_manager.dart'; // Add this import
import 'package:intl/intl.dart'; // Add this import for date formatting
import 'package:datavault/services/connection_service.dart';
import 'package:provider/provider.dart';

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
  double usedStorage = 0;
  double totalStorage = 0;
  String? _currentStoragePath;
  List<FileSystemEntity> _storageFiles = []; // Add this for storage files
  bool _isLoadingStorageFiles = false; // Add loading indicator state

  int usedStorageBytes = 0;
  int totalStorageBytes = 0;

  final List<Map<String, dynamic>> categories = [
    {'title': 'Photos', 'count': 0, 'icon': Icons.photo, 'color': Colors.blue},
    {
      'title': 'Videos',
      'count': 0,
      'icon': Icons.video_collection,
      'color': Colors.purple,
    },
    {
      'title': 'Audio',
      'count': 0,
      'icon': Icons.music_note,
      'color': Colors.orange,
    },
    {
      'title': 'Documents',
      'count': 0,
      'icon': Icons.insert_drive_file,
      'color': Colors.lightBlue,
    },
    {'title': 'APKs', 'count': 5, 'icon': Icons.android, 'color': Colors.green},
    {
      'title': 'Archives',
      'count': 0,
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
    _loadStorageFiles();
    _calculateFolderUsage(); // Add this
  }

  // Calculate the total and used size of the selected storage folder
  Future<void> _calculateFolderUsage() async {
    try {
      final storagePath = await StorageManager.getDefaultStoragePath();
      final directory = Directory(storagePath);

      int totalBytes = 0;
      int fileCount = 0;

      if (await directory.exists()) {
        await for (var entity in directory.list(
          recursive: true,
          followLinks: false,
        )) {
          if (entity is File) {
            totalBytes += await entity.length();
            fileCount++;
          }
        }
      }

      setState(() {
        usedStorage =
            totalBytes / (1024 * 1024 * 1024); // (keep for progress bar)
        totalStorage = usedStorage; // (keep for progress bar)
        usedStorageBytes = totalBytes;
        totalStorageBytes = totalBytes;
      });
    } catch (e) {
      print('Error calculating folder usage: $e');
      setState(() {
        usedStorage = 0;
        totalStorage = 0;
      });
    }
  }

  // Add this method to load files from the default storage
  Future<void> _loadStorageFiles() async {
    setState(() {
      _isLoadingStorageFiles = true;
    });

    try {
      // Get the default storage path
      final storagePath = await StorageManager.getDefaultStoragePath();
      setState(() {
        _currentStoragePath = storagePath;
      });

      // Load files from the path
      final directory = Directory(storagePath);
      if (await directory.exists()) {
        final files = await directory.list().toList();
        setState(() {
          _storageFiles = files;
        });
      }
    } catch (e) {
      print('Error loading storage files: $e');
    } finally {
      setState(() {
        _isLoadingStorageFiles = false;
      });
    }
  }

  // Add this method to your _FileManagerPageState class
  Future<void> _scanAndUpdateCategories() async {
    try {
      // Get the default storage path
      final storagePath = await StorageManager.getDefaultStoragePath();

      // Scan both the root and the Received subfolder
      final receivedDir = Directory('$storagePath/Received');
      final List<Directory> scanDirs = [Directory(storagePath)];
      if (await receivedDir.exists()) {
        scanDirs.add(receivedDir);
      }

      // Create counters for each category
      Map<String, int> categoryCounts = {
        'Photos': 0,
        'Videos': 0,
        'Audio': 0,
        'Documents': 0,
        'APKs': 0,
        'Archives': 0,
      };

      // Scan all directories
      for (final directory in scanDirs) {
        await for (var entity in directory.list(recursive: true)) {
          if (entity is File) {
            final path = entity.path.toLowerCase();
            for (var category in categoryExtensions.keys) {
              if (categoryExtensions[category]!.any(
                (ext) => path.endsWith(ext),
              )) {
                categoryCounts[category] = (categoryCounts[category] ?? 0) + 1;
                break;
              }
            }
          }
        }
      }

      // Update the category counts in the UI
      setState(() {
        for (int i = 0; i < categories.length; i++) {
          categories[i]['count'] = categoryCounts[categories[i]['title']] ?? 0;
        }
      });

      print('Category counts updated: $categoryCounts');
    } catch (e) {
      print('Error scanning categories: $e');
    }
  }

  // Function to get file icon based on extension
  IconData _getFileIcon(String path) {
    final ext = path.split('.').last.toLowerCase();

    if (['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp'].contains(ext)) {
      return Icons.image;
    } else if (['mp4', 'avi', 'mov', 'wmv', 'flv', 'mkv'].contains(ext)) {
      return Icons.video_file;
    } else if (['mp3', 'wav', 'ogg', 'flac', 'm4a'].contains(ext)) {
      return Icons.audio_file;
    } else if (['pdf'].contains(ext)) {
      return Icons.picture_as_pdf;
    } else if (['doc', 'docx', 'txt', 'rtf'].contains(ext)) {
      return Icons.description;
    } else if (['xls', 'xlsx', 'csv'].contains(ext)) {
      return Icons.table_chart;
    } else if (['ppt', 'pptx'].contains(ext)) {
      return Icons.slideshow;
    } else if (['zip', 'rar', '7z', 'tar', 'gz'].contains(ext)) {
      return Icons.folder_zip;
    } else {
      return Icons.insert_drive_file;
    }
  }

  // Function to format file size
  String _formatFileSize(num bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(2)} KB';
    if (bytes < 1024 * 1024 * 1024)
      return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
    if (bytes < 1024 * 1024 * 1024 * 1024)
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
    return '${(bytes / (1024 * 1024 * 1024 * 1024)).toStringAsFixed(2)} TB';
  }

  // Add this widget builder method
  Widget _buildStorageFilesSection() {
    return Container(
      padding: const EdgeInsets.all(16),
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
                'Files in Default Storage',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              Row(
                children: [
                  TextButton.icon(
                    icon: Icon(Icons.settings),
                    label: Text('Change'),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const SettingsScreen(),
                        ),
                      ).then(
                        (_) => _loadStorageFiles(),
                      ); // Reload files when returning from settings
                    },
                  ),
                  IconButton(
                    icon: Icon(Icons.refresh),
                    onPressed: _loadStorageFiles,
                    tooltip: 'Refresh',
                  ),
                ],
              ),
            ],
          ),
          if (_currentStoragePath != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                _currentStoragePath!,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  color: Colors.grey,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          if (_isLoadingStorageFiles)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_storageFiles.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  children: [
                    Icon(Icons.folder_open, size: 48, color: Colors.grey),
                    SizedBox(height: 16),
                    Text('No files found in default storage location'),
                  ],
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              itemCount:
                  _storageFiles.length > 10
                      ? 10
                      : _storageFiles.length, // Limit to 10 files
              separatorBuilder: (context, index) => Divider(height: 1),
              itemBuilder: (context, index) {
                final file = _storageFiles[index];
                final fileName = file.path.split(Platform.pathSeparator).last;
                final isDirectory = file is Directory;

                return ListTile(
                  leading: Icon(
                    isDirectory ? Icons.folder : _getFileIcon(file.path),
                    color: isDirectory ? Colors.amber : Colors.blue,
                  ),
                  title: Text(fileName, overflow: TextOverflow.ellipsis),
                  subtitle: FutureBuilder<FileStat>(
                    future: file.stat(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return Text('Loading...');
                      }

                      final modified = DateFormat(
                        'MMM d, yyyy',
                      ).format(snapshot.data!.modified);

                      final size =
                          isDirectory
                              ? 'Directory'
                              : _formatFileSize(snapshot.data!.size);

                      return Text('$modified • $size');
                    },
                  ),
                  trailing:
                      isDirectory
                          ? null
                          : IconButton(
                            icon: Icon(Icons.open_in_new),
                            onPressed: () async {
                              try {
                                await OpenFile.open(file.path);
                              } catch (e) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Error opening file: $e'),
                                  ),
                                );
                              }
                            },
                            tooltip: 'Open',
                          ),
                  onTap:
                      isDirectory
                          ? () async {
                            // Navigate into the directory
                            final dirPath = file.path;
                            final dir = Directory(dirPath);
                            final files = await dir.list().toList();

                            setState(() {
                              _currentStoragePath = dirPath;
                              _storageFiles = files;
                            });
                          }
                          : () async {
                            try {
                              await OpenFile.open(file.path);
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Error opening file: $e'),
                                ),
                              );
                            }
                          },
                );
              },
            ),
          if (_storageFiles.length > 10) // If we have more than 10 files
            Padding(
              padding: const EdgeInsets.only(top: 16.0),
              child: Center(
                child: TextButton.icon(
                  icon: Icon(Icons.more_horiz),
                  label: Text('View All (${_storageFiles.length} files)'),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder:
                            (context) => StorageFilesScreen(
                              initialPath: _currentStoragePath!,
                            ),
                      ),
                    );
                  },
                ),
              ),
            ),
          if (_currentStoragePath != null)
            FutureBuilder<String>(
              future: StorageManager.getDefaultStoragePath(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return SizedBox.shrink();
                }
                if (_currentStoragePath != snapshot.data) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Center(
                      child: TextButton.icon(
                        icon: Icon(Icons.arrow_upward),
                        label: Text('Go to Parent Directory'),
                        onPressed: () async {
                          final parentDir =
                              Directory(_currentStoragePath!).parent;
                          final files = await parentDir.list().toList();

                          setState(() {
                            _currentStoragePath = parentDir.path;
                            _storageFiles = files;
                          });
                        },
                      ),
                    ),
                  );
                }
                return SizedBox.shrink();
              },
            ),
        ],
      ),
    );
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
        actions: [
          // Add connection status indicator
          Consumer<ConnectionService>(
            builder: (context, connectionService, child) {
              return Padding(
                padding: const EdgeInsets.all(8.0),
                child: connectionService.isConnected
                    ? Row(
                        children: [
                          Icon(Icons.wifi, color: Colors.green),
                          SizedBox(width: 8),
                          Text('Connected'),
                        ],
                      )
                    : TextButton.icon(
                        icon: Icon(Icons.wifi_off, color: Colors.red),
                        label: Text('Connect'),
                        onPressed: () async {
                          try {
                            await connectionService.connect('192.168.18.226');
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Connected to server')),
                            );
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Failed to connect: $e')),
                            );
                          }
                        },
                      ),
              );
            },
          ),
        ],
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
                            hintText: 'Search files, folders... djfgjh',
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
                        value:
                            totalStorage == 0 ? 0 : usedStorage / totalStorage,
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
              // Add the Storage Files section before Sources
              _buildStorageFilesSection(),

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
              const SizedBox(height: 20),
              // Add Connected Devices section
              _buildConnectedDevicesSection(),
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

  // Add import for connection service
  // import 'package:datavault/services/connection_service.dart';
  // import 'package:provider/provider.dart';

  // Add this widget to show connected devices
  Widget _buildConnectedDevicesSection() {
    return Consumer<ConnectionService>(
      builder: (context, connectionService, child) {
        return Container(
          padding: const EdgeInsets.all(16),
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
                    'Connected Devices',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  connectionService.isConnected 
                    ? TextButton.icon(
                        icon: Icon(Icons.refresh),
                        label: Text('Refresh'),
                        onPressed: () {
                          connectionService.channel?.sink.add(
                            jsonEncode({"type": "get_connected_devices"})
                          );
                        },
                      )
                    : TextButton.icon(
                        icon: Icon(Icons.wifi),
                        label: Text('Connect'),
                        onPressed: () async {
                          try {
                            await connectionService.connect('192.168.18.226');
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Connected to server'))
                            );
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Failed to connect: $e'))
                            );
                          }
                        },
                      ),
                ],
              ),
              SizedBox(height: 16),
              
              connectionService.isConnected
                ? connectionService.connectedClients.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: Column(
                          children: [
                            Icon(Icons.devices, size: 48, color: Colors.grey),
                            SizedBox(height: 16),
                            Text('No devices found nearby'),
                          ],
                        ),
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      physics: NeverScrollableScrollPhysics(),
                      itemCount: connectionService.connectedClients.length,
                      separatorBuilder: (context, index) => Divider(height: 1),
                      itemBuilder: (context, index) {
                        final device = connectionService.connectedClients[index];
                        
                        // Don't show own device
                        if (device['id'] == connectionService.deviceId) {
                          return SizedBox.shrink();
                        }
                        
                        return ListTile(
                          leading: Icon(Icons.devices_other, color: Colors.blue),
                          title: Text(device['name'] ?? 'Unknown Device'),
                          subtitle: Text('Device ID: ${device['id']}'),
                          trailing: ElevatedButton.icon(
                            icon: Icon(Icons.folder_open, size: 16),
                            label: Text('Browse'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                            ),
                            onPressed: () {
                              _showRemoteFileBrowser(context, device['id'], device['name']);
                            },
                          ),
                        );
                      },
                    )
                : Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Column(
                        children: [
                          Icon(Icons.wifi_off, size: 48, color: Colors.grey),
                          SizedBox(height: 16),
                          Text('Not connected to network'),
                          SizedBox(height: 16),
                          ElevatedButton.icon(
                            icon: Icon(Icons.wifi),
                            label: Text('Connect'),
                            onPressed: () async {
                              try {
                                await connectionService.connect('192.168.18.226');
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Connected to server'))
                                );
                              } catch (e) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Failed to connect: $e'))
                                );
                              }
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
    );
  }

  // Add this method to show remote file browser
  void _showRemoteFileBrowser(BuildContext context, String deviceId, String deviceName) {
    final connectionService = Provider.of<ConnectionService>(context, listen: false);
    
    // Declare the subscription variable first
    StreamSubscription? subscription;
    
    // Then assign it separately
    subscription = connectionService.broadcastStream?.listen((message) {
      if (message is String) {
        try {
          final data = jsonDecode(message);
          
          if (data['type'] == 'file_list_response' && 
              data['requesterId'] == connectionService.deviceId &&
              data['sourceId'] == deviceId) {
            
            // Close loading dialog
            Navigator.of(context, rootNavigator: true).pop();
            
            // Navigate to RemoteFilesScreen
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => RemoteFilesScreen(
                  deviceId: deviceId,
                  deviceName: deviceName,
                  initialFiles: List<Map<String, dynamic>>.from(
                    data['files'].map((file) => Map<String, dynamic>.from(file))
                  ),
                  initialPath: data['sourcePath'] ?? '',
                ),
              ),
            );
            
            // Now you can cancel the subscription after first response
            subscription?.cancel();
          }
        } catch (e) {
          print('Error processing message: $e');
        }
      }
    });
    
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text('Requesting Files'),
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('Loading files from $deviceName...'),
          ],
        ),
      ),
    );
    
    // Set timeout for dialog
    Future.delayed(Duration(seconds: 10), () {
      // Check if dialog is still showing
      if (ModalRoute.of(context)?.isCurrent != true) {
        Navigator.of(context, rootNavigator: true).pop();
        subscription?.cancel();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Request timed out. Please try again.'))
        );
      }
    });
    
    // Request file list
    connectionService.requestRemoteFileList(deviceId);
  }
}

class PhotosScreen extends StatelessWidget {
  const PhotosScreen({super.key});

  Future<List<FileSystemEntity>> _getPhotoFiles() async {
    final storagePath = await StorageManager.getDefaultStoragePath();
    final receivedDir = Directory('$storagePath/Received');
    final List<FileSystemEntity> files = [];

    // Helper to collect files from a directory
    Future<void> collectFiles(Directory dir) async {
      if (await dir.exists()) {
        files.addAll(
          dir.listSync(recursive: true, followLinks: false).where((entity) {
            final path = entity.path.toLowerCase();
            return entity is File &&
                (path.endsWith('.jpg') ||
                    path.endsWith('.jpeg') ||
                    path.endsWith('.png') ||
                    path.endsWith('.gif') ||
                    path.endsWith('.bmp') ||
                    path.endsWith('.webp'));
          }),
        );
      }
    }

    await collectFiles(Directory(storagePath));
    await collectFiles(receivedDir);

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
                  openFileByPath(file.path); // <-- open the file
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
    final storagePath = await StorageManager.getDefaultStoragePath();
    final receivedDir = Directory('$storagePath/Received');
    final List<FileSystemEntity> files = [];

    // Helper to collect files from a directory
    Future<void> collectFiles(Directory dir) async {
      if (await dir.exists()) {
        files.addAll(
          dir.listSync(recursive: true, followLinks: false).where((entity) {
            final path = entity.path.toLowerCase();
            return entity is File &&
                (path.endsWith('.mp4') ||
                    path.endsWith('.avi') ||
                    path.endsWith('.mov') ||
                    path.endsWith('.mkv') ||
                    path.endsWith('.flv') ||
                    path.endsWith('.wmv'));
          }),
        );
      }
    }

    await collectFiles(Directory(storagePath));
    await collectFiles(receivedDir);

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
                  openFileByPath(file.path);
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
    final storagePath = await StorageManager.getDefaultStoragePath();
    final receivedDir = Directory('$storagePath/Received');
    final List<FileSystemEntity> files = [];

    Future<void> collectFiles(Directory dir) async {
      if (await dir.exists()) {
        files.addAll(
          dir.listSync(recursive: true, followLinks: false).where((entity) {
            final path = entity.path.toLowerCase();
            return entity is File &&
                (path.endsWith('.mp3') ||
                    path.endsWith('.wav') ||
                    path.endsWith('.aac') ||
                    path.endsWith('.ogg') ||
                    path.endsWith('.flac') ||
                    path.endsWith('.m4a'));
          }),
        );
      }
    }

    await collectFiles(Directory(storagePath));
    await collectFiles(receivedDir);

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
                  openFileByPath(file.path);
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
    final storagePath = await StorageManager.getDefaultStoragePath();
    final receivedDir = Directory('$storagePath/Received');
    final List<FileSystemEntity> files = [];

    Future<void> collectFiles(Directory dir) async {
      if (await dir.exists()) {
        files.addAll(
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
          }),
        );
      }
    }

    await collectFiles(Directory(storagePath));
    await collectFiles(receivedDir);

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
                  openFileByPath(file.path);
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
    final storagePath = await StorageManager.getDefaultStoragePath();
    final receivedDir = Directory('$storagePath/Received');
    final List<FileSystemEntity> files = [];

    Future<void> collectFiles(Directory dir) async {
      if (await dir.exists()) {
        files.addAll(
          dir.listSync(recursive: true, followLinks: false).where((entity) {
            final path = entity.path.toLowerCase();
            return entity is File && path.endsWith('.apk');
          }),
        );
      }
    }

    await collectFiles(Directory(storagePath));
    await collectFiles(receivedDir);

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
                  openFileByPath(file.path);
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
    final storagePath = await StorageManager.getDefaultStoragePath();
    final receivedDir = Directory('$storagePath/Received');
    final List<FileSystemEntity> files = [];

    Future<void> collectFiles(Directory dir) async {
      if (await dir.exists()) {
        files.addAll(
          dir.listSync(recursive: true, followLinks: false).where((entity) {
            final path = entity.path.toLowerCase();
            return entity is File &&
                (path.endsWith('.zip') ||
                    path.endsWith('.rar') ||
                    path.endsWith('.tar') ||
                    path.endsWith('.gz') ||
                    path.endsWith('.7z'));
          }),
        );
      }
    }

    await collectFiles(Directory(storagePath));
    await collectFiles(receivedDir);

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
                  openFileByPath(file.path);
                },
              );
            },
          );
        },
      ),
    );
  }
}

void openFileByPath(String path) {
  OpenFile.open(path);
}

// Add this screen to show all files in a directory
class StorageFilesScreen extends StatefulWidget {
  final String initialPath;

  const StorageFilesScreen({Key? key, required this.initialPath})
    : super(key: key);

  @override
  State<StorageFilesScreen> createState() => _StorageFilesScreenState();
}

class _StorageFilesScreenState extends State<StorageFilesScreen> {
  List<FileSystemEntity> _files = [];
  String? _currentPath;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFiles(widget.initialPath);
  }

  Future<void> _loadFiles(String path) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final directory = Directory(path);
      if (await directory.exists()) {
        final files = await directory.list().toList();
        setState(() {
          _currentPath = path;
          _files = files;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error loading files: $e')));
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Reuse the _getFileIcon and _formatFileSize methods from _FileManagerPageState

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Storage Files'),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: () => _loadFiles(_currentPath!),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              _currentPath ?? '',
              style: TextStyle(fontFamily: 'monospace'),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            child:
                _isLoading
                    ? Center(child: CircularProgressIndicator())
                    : _files.isEmpty
                    ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.folder_open, size: 48, color: Colors.grey),
                          SizedBox(height: 16),
                          Text('No files found in this location'),
                        ],
                      ),
                    )
                    : ListView.separated(
                      itemCount: _files.length,
                      separatorBuilder: (context, index) => Divider(height: 1),
                      itemBuilder: (context, index) {
                        // Implement the same file item UI as in the dashboard
                        // but with full functionality
                      },
                    ),
          ),
        ],
      ),
    );
  }
}