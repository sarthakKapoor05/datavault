import 'dart:async';
import 'dart:convert'; // For jsonEncode
import 'dart:io';
import 'package:datavault/Responsive/Responsive%20DashBoard/mobile_dashboard.dart';
import 'package:datavault/Responsive/Responsive%20DashBoard/tablet_dashboard.dart';
import 'package:datavault/Scrrens/Folders/apks_screen.dart';
import 'package:datavault/Scrrens/Folders/archives_screen.dart';
import 'package:datavault/Scrrens/Folders/documents_screen.dart';
import 'package:datavault/Scrrens/downloads_screen.dart';
import 'package:datavault/Scrrens/settings_screen.dart';
import 'package:datavault/Scrrens/remote_files_screen.dart'; // Add this line
import 'package:datavault/Scrrens/storage_files_screen.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:datavault/Scrrens/folders.dart';
import 'package:datavault/Scrrens/received_files_screen.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:datavault/utils/storage_manager.dart'; // Add this import
import 'package:intl/intl.dart'; // Add this import for date formatting
import 'package:datavault/services/connection_service.dart';
import 'package:datavault/services/event_bus_service.dart';
import 'package:provider/provider.dart';

class MobileDashboard extends StatelessWidget {
  const MobileDashboard({super.key});
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
  String? _currentPath; // Add this line to define _currentPath
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

  // Add this field to _FileManagerPageState
  StreamSubscription? _permissionRequestSubscription;

  // Add these variables to your _FileManagerPageState class
  final TextEditingController _searchController = TextEditingController();
  List<FileSystemEntity> _searchResults = [];
  bool _isSearching = false;

  // Add this to track expanded/collapsed state of sections
  Map<String, bool> _expandedSections = {
    'storage': true,
    'categories': true,
    'files': true,
    'sources': true,
    'devices': true,
    'shared': true,
  };

  // Add to the _FileManagerPageState class properties
  bool _isGridView = false; // Default to list view

  @override
  void initState() {
    super.initState();
    _scanAndUpdateCategories();
    _loadStorageFiles();
    _calculateFolderUsage(); // Add this

    // Initialize _currentPath
    StorageManager.getDefaultStoragePath().then((path) {
      setState(() {
        _currentPath = path;
      });
    });

    // Listen for file access permission requests
    _permissionRequestSubscription = eventBus
        .on<FileAccessRequestEvent>()
        .listen((event) {
          _showPermissionRequestDialog(
            context,
            event.requesterId,
            event.requesterName,
          );
        });
  }

  // Calculate the total and used size of the selected storage folder
  Future<void> _calculateFolderUsage() async {
    try {
      final storagePath = await StorageManager.getDefaultStoragePath();
      final maxStorageBytes = await StorageManager.getMaxStorageSize();
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
        usedStorageBytes = totalBytes;
        totalStorageBytes = maxStorageBytes; // Use the configured max size
        usedStorage = totalBytes / (1024 * 1024 * 1024); // Convert to GB
        totalStorage = maxStorageBytes / (1024 * 1024 * 1024); // Convert to GB
      });
    } catch (e) {
      print('Error calculating folder usage: $e');
      setState(() {
        usedStorage = 0;
        totalStorage = 1; // Default to 1 GB
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
        _currentPath = storagePath; // Add this line to set _currentPath
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

  // Method to search files in default storage
  Future<void> _searchFiles(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _isSearching = false;
        _searchResults = [];
      });
      return;
    }

    setState(() {
      _isSearching = true;
    });

    try {
      final storagePath = await StorageManager.getDefaultStoragePath();
      final directory = Directory(storagePath);
      List<FileSystemEntity> results = [];

      if (await directory.exists()) {
        await for (var entity in directory.list(recursive: true)) {
          final fileName = entity.path.split(Platform.pathSeparator).last;
          if (fileName.toLowerCase().contains(query.toLowerCase())) {
            results.add(entity);
          }
        }

        setState(() {
          _searchResults = results;
        });
      }
    } catch (e) {
      print('Error searching files: $e');
    } finally {
      setState(() {
        _isSearching = false;
      });
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
          _buildSectionHeader(
            'Files in Default Storage',
            'files',
            Row(
              children: [
                // Add view toggle button
                IconButton(
                  icon: Icon(_isGridView ? Icons.list : Icons.grid_view),
                  tooltip: _isGridView ? 'List View' : 'Grid View',
                  onPressed: () {
                    setState(() {
                      _isGridView = !_isGridView;
                    });
                  },
                ),
                TextButton.icon(
                  icon: Icon(Icons.settings),
                  label: Text('Change'),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const SettingsScreen(),
                      ),
                    ).then((_) => _loadStorageFiles());
                  },
                ),
                IconButton(
                  icon: Icon(Icons.refresh),
                  onPressed: _loadStorageFiles,
                  tooltip: 'Refresh',
                ),
              ],
            ),
          ),

          if (_expandedSections['files'] ?? true) ...[
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
              _isGridView ? _buildGridView() : _buildListView(),

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
            if (_currentPath != null)
              FutureBuilder<String>(
                future: StorageManager.getDefaultStoragePath(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return SizedBox.shrink();
                  }
                  if (_currentPath != snapshot.data) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Center(
                        child: TextButton.icon(
                          icon: Icon(Icons.arrow_upward),
                          label: Text('Go to Parent Directory'),
                          onPressed: () async {
                            final parentDir = Directory(_currentPath!).parent;
                            final files = await parentDir.list().toList();

                            setState(() {
                              _currentPath = parentDir.path;
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
        ],
      ),
    );
  }

  // Add these new helper methods for different views
  Widget _buildListView() {
    return ListView.separated(
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
                          SnackBar(content: Text('Error opening file: $e')),
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
                        SnackBar(content: Text('Error opening file: $e')),
                      );
                    }
                  },
        );
      },
    );
  }

  // Replace the existing _buildGridView method with this improved version
  Widget _buildGridView() {
    return GridView.builder(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      padding: EdgeInsets.all(8),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 1.0,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: _storageFiles.length > 12 ? 12 : _storageFiles.length,
      itemBuilder: (context, index) {
        final file = _storageFiles[index];
        final fileName = file.path.split(Platform.pathSeparator).last;
        final isDirectory = file is Directory;

        return GestureDetector(
          onTap:
              isDirectory
                  ? () async {
                    // Navigate into the directory
                    final dirPath = file.path;
                    final dir = Directory(dirPath);
                    final files = await dir.list().toList();

                    setState(() {
                      _currentStoragePath = dirPath;
                      _currentPath = dirPath;
                      _storageFiles = files;
                    });
                  }
                  : () async {
                    try {
                      await OpenFile.open(file.path);
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error opening file: $e')),
                      );
                    }
                  },
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 5,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(
                  flex: 3,
                  child: Container(
                    padding: EdgeInsets.all(16),
                    child:
                        _isImageFile(file.path) && !isDirectory
                            ? ClipRRect(
                              borderRadius: BorderRadius.vertical(
                                top: Radius.circular(12),
                              ),
                              child: Image.file(
                                File(file.path),
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Icon(
                                    _getFileIcon(file.path),
                                    size: 48,
                                    color:
                                        isDirectory
                                            ? Colors.amber[700]
                                            : Colors.blue[700],
                                  );
                                },
                              ),
                            )
                            : Center(
                              child: Icon(
                                isDirectory
                                    ? Icons.folder
                                    : _getFileIcon(file.path),
                                size: 48,
                                color:
                                    isDirectory
                                        ? Colors.amber[700]
                                        : Colors.blue[700],
                              ),
                            ),
                  ),
                ),
                Divider(height: 1, thickness: 1),
                Expanded(
                  flex: 2,
                  child: Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          fileName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        SizedBox(height: 4),
                        FutureBuilder<FileStat>(
                          future: file.stat(),
                          builder: (context, snapshot) {
                            if (!snapshot.hasData) {
                              return Text(
                                '...',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey,
                                ),
                              );
                            }

                            final size =
                                isDirectory
                                    ? 'Directory'
                                    : _formatFileSize(snapshot.data!.size);

                            return Text(
                              size,
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey,
                              ),
                              overflow: TextOverflow.ellipsis,
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Helper method to check if a file is an image
  bool _isImageFile(String path) {
    final ext = path.split('.').last.toLowerCase();
    return ['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp'].contains(ext);
  }

  // Add this method to your _FileManagerPageState class
  Widget _buildSectionHeader(
    String title,
    String sectionKey, [
    Widget? trailing,
  ]) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Make title flexible and handle overflow
        Expanded(
          child: Text(
            title,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            overflow: TextOverflow.ellipsis, // Handle long text
          ),
        ),
        // Wrap trailing widgets in a Row with overflow handling
        Row(
          mainAxisSize: MainAxisSize.min, // Take minimum space
          children: [
            if (trailing != null) Flexible(child: trailing),
            IconButton(
              icon: Icon(
                _expandedSections[sectionKey] ?? true
                    ? Icons.keyboard_arrow_up
                    : Icons.keyboard_arrow_down,
                size: 24,
              ),
              onPressed: () => _toggleSectionExpansion(sectionKey),
              tooltip:
                  _expandedSections[sectionKey] ?? true ? 'Collapse' : 'Expand',
              constraints: BoxConstraints(), // Minimize button constraints
              padding: EdgeInsets.zero, // Remove padding
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // Get connection status from service
    final connectionService = Provider.of<ConnectionService>(context);
    final bool isConnected = connectionService.isConnected;

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
                child:
                    connectionService.isConnected
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
                              await connectionService.connect(
                                '192.168.239.23239.23',
                              );
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Connected to server')),
                              );
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Failed to connect: $e'),
                                ),
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
                          controller: _searchController,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.secondary,
                          ),
                          cursorColor: Theme.of(context).colorScheme.secondary,
                          decoration: InputDecoration(
                            hintText: 'Search files in storage...',
                            hintStyle: TextStyle(
                              color: Theme.of(
                                context,
                              ).colorScheme.secondary.withOpacity(0.7),
                            ),
                            border: InputBorder.none,
                          ),
                          onChanged: (value) {
                            _searchFiles(value);
                          },
                        ),
                      ),
                      if (_searchController.text.isNotEmpty)
                        IconButton(
                          icon: Icon(
                            Icons.clear,
                            color: Theme.of(context).colorScheme.secondary,
                          ),
                          onPressed: () {
                            _searchController.clear();
                            _searchFiles("");
                          },
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
                          // Add a settings button to quickly access storage limit settings
                          IconButton(
                            icon: Icon(Icons.settings),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const SettingsScreen(),
                                ),
                              ).then((_) => _calculateFolderUsage());
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value:
                            totalStorage == 0 ? 0 : usedStorage / totalStorage,
                        backgroundColor: Colors.grey[700],
                        color:
                            usedStorage / totalStorage > 0.9
                                ? Colors.red
                                : usedStorage / totalStorage > 0.75
                                ? Colors.orange
                                : Colors.green,
                        minHeight: 8,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      if (usedStorage / totalStorage > 0.9)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Row(
                            children: [
                              Icon(Icons.warning, color: Colors.red, size: 16),
                              SizedBox(width: 8),
                              Text(
                                'Storage almost full',
                                style: TextStyle(
                                  color: Colors.red,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          'Used: ${_formatFileSize(usedStorageBytes)} of ${_formatFileSize(totalStorageBytes)}',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionHeader('Categories', 'categories'),
                  if (_expandedSections['categories'] ?? true)
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: categories.length,
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 200,
                            mainAxisSpacing: 16,
                            crossAxisSpacing: 16,
                            childAspectRatio: 1,
                          ),
                      itemBuilder: (context, index) {
                        return _buildCategoryCard(context, categories[index]);
                      },
                    ),
                ],
              ),

              const SizedBox(height: 20),
              // Add the Storage Files section before Sources
              _buildStorageFilesSection(),

              // const SizedBox(height: 20),
              // Text(
              //   'Sources',
              //   style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              // ),
              // const SizedBox(height: 10),
              // Column(
              //   children:
              //       sources.map((source) => _buildSourceTile(source)).toList(),
              // ),
              // const SizedBox(height: 20),
              // // Add Connected Devices section
              // _buildConnectedDevicesSection(),

              // // Add All Device Files section
              // _buildAllDeviceFilesSection(),
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
      // Optionally add a connection indicator in your UI
      bottomNavigationBar:
          isConnected
              ? Container(
                height: 24,
                color: Colors.green.withOpacity(0.1),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.wifi, size: 14, color: Colors.green),
                    SizedBox(width: 8),
                    Text(
                      'Connected to server',
                      style: TextStyle(fontSize: 12, color: Colors.green),
                    ),
                  ],
                ),
              )
              : null,
    );
  }

  // Method to toggle section expansion
  void _toggleSectionExpansion(String section) {
    setState(() {
      _expandedSections[section] = !(_expandedSections[section] ?? true);
    });
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
        // Only Settings option remains
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const SettingsScreen()),
        );
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
                            jsonEncode({"type": "get_connected_devices"}),
                          );
                        },
                      )
                      : TextButton.icon(
                        icon: Icon(Icons.wifi),
                        label: Text('Connect'),
                        onPressed: () async {
                          try {
                            await connectionService.connect(
                              '192.168.239.23239.23',
                            );
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
                        separatorBuilder:
                            (context, index) => Divider(height: 1),
                        itemBuilder: (context, index) {
                          final device =
                              connectionService.connectedClients[index];

                          // Don't show own device
                          if (device['id'] == connectionService.deviceId) {
                            return SizedBox.shrink();
                          }

                          return ListTile(
                            leading: Icon(
                              Icons.devices_other,
                              color: Colors.blue,
                            ),
                            title: Text(
                              device['name'] ?? 'Unknown Device',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text('Device ID: ${device['id']}'),
                            trailing: ElevatedButton.icon(
                              icon: Icon(Icons.folder_open, size: 16),
                              label: Text('Browse'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                foregroundColor: Colors.white,
                              ),
                              onPressed: () {
                                _showRemoteFileBrowser(
                                  context,
                                  device['id'],
                                  device['name'],
                                );
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
                                await connectionService.connect(
                                  '192.168.239.2318.226',
                                );
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Connected to server'),
                                  ),
                                );
                              } catch (e) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Failed to connect: $e'),
                                  ),
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
      },
    );
  }

  // Add this method to show remote file browser
  void _showRemoteFileBrowser(
    BuildContext context,
    String deviceId,
    String deviceName,
  ) {
    final connectionService = Provider.of<ConnectionService>(
      context,
      listen: false,
    );

    // Check if we already have permission
    if (connectionService.hasPermissionForDevice(deviceId)) {
      // Show loading dialog and proceed with file request
      _requestRemoteFilesList(deviceId, deviceName);
      return;
    }

    // If not, show requesting access dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => AlertDialog(
            title: Text('Requesting Access'),
            content: Row(
              children: [
                CircularProgressIndicator(),
                SizedBox(width: 16),
                Expanded(
                  child: Text('Requesting file access from $deviceName...'),
                ),
              ],
            ),
          ),
    );

    // Request permission
    connectionService.requestFileAccess(deviceId);

    // First declare the subscription variable
    StreamSubscription? subscription;

    // Then assign it in a separate statement
    subscription = eventBus.on<FileAccessGrantedEvent>().listen((event) {
      if (event.deviceId == deviceId) {
        // Permission granted, close dialog and show file browser
        Navigator.of(context, rootNavigator: true).pop();
        _requestRemoteFilesList(deviceId, deviceName);
        subscription?.cancel(); // Now this works correctly
      }
    });

    // Also listen for denial
    StreamSubscription? denialSubscription;
    denialSubscription = eventBus.on<FileAccessDeniedEvent>().listen((event) {
      if (event.deviceId == deviceId) {
        // Permission denied, show message
        Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$deviceName denied file access request')),
        );
        denialSubscription?.cancel(); // Now this works correctly
      }
    });

    // Set timeout
    Future.delayed(Duration(seconds: 15), () {
      subscription?.cancel();
      denialSubscription?.cancel();
      if (Navigator.of(context, rootNavigator: true).canPop()) {
        Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Request timed out. Please try again.')),
        );
      }
    });
  }

  // Helper method to request files after permission is granted
  void _requestRemoteFilesList(String deviceId, String deviceName) {
    final connectionService = Provider.of<ConnectionService>(
      context,
      listen: false,
    );

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
                builder:
                    (context) => RemoteFilesScreen(
                      deviceId: deviceId,
                      deviceName: deviceName,
                      initialFiles: List<Map<String, dynamic>>.from(
                        data['files'].map(
                          (file) => Map<String, dynamic>.from(file),
                        ),
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
      builder:
          (context) => AlertDialog(
            title: Text('Loading Files'),
            content: Row(
              children: [
                CircularProgressIndicator(),
                SizedBox(width: 16),
                Text('Loading files from $deviceName...'),
              ],
            ),
          ),
    );

    // Request file list
    connectionService.requestRemoteFileList(deviceId);
  }

  // Add to desktop_dashboard.dart
  void _showPermissionRequestDialog(
    BuildContext context,
    String requesterId,
    String requesterName,
  ) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => AlertDialog(
            title: Text('File Access Request'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.folder_shared, size: 48, color: Colors.blue),
                SizedBox(height: 16),
                Text(
                  '$requesterName wants to access your files',
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 8),
                Text(
                  'If you approve, they will be able to browse and download your files.',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
            actions: [
              TextButton(
                child: Text('Deny'),
                onPressed: () {
                  // Deny access
                  final connectionService = Provider.of<ConnectionService>(
                    context,
                    listen: false,
                  );
                  connectionService.denyPermissionTo(requesterId);
                  Navigator.pop(context);
                },
              ),
              ElevatedButton(
                child: Text('Allow'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                onPressed: () {
                  // Grant access
                  final connectionService = Provider.of<ConnectionService>(
                    context,
                    listen: false,
                  );
                  connectionService.grantPermissionTo(requesterId);
                  Navigator.pop(context);
                },
              ),
            ],
          ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _permissionRequestSubscription?.cancel();
    super.dispose();
  }

  // Add this to desktop_dashboard.dart
  Widget _buildAllDeviceFilesSection() {
    return Consumer<ConnectionService>(
      builder: (context, connectionService, child) {
        final deviceFiles = connectionService.deviceFiles;

        if (!connectionService.isConnected) {
          return SizedBox.shrink();
        }

        if (deviceFiles.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.only(top: 20),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Text(
                  'Shared Files from Devices',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 16),
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      children: [
                        Icon(Icons.folder_shared, size: 48, color: Colors.grey),
                        SizedBox(height: 16),
                        Text('No shared files available'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        return Container(
          padding: const EdgeInsets.all(16),
          margin: const EdgeInsets.only(top: 20),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Shared Files from Devices',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 16),
              ListView.builder(
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                itemCount: deviceFiles.length,
                itemBuilder: (context, index) {
                  final deviceId = deviceFiles.keys.elementAt(index);
                  final deviceData = deviceFiles[deviceId]!;

                  // Don't show own device
                  if (deviceId == connectionService.deviceId) {
                    return SizedBox.shrink();
                  }

                  return _buildDeviceFilesCard(deviceId, deviceData);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDeviceFilesCard(
    String deviceId,
    Map<String, dynamic> deviceData,
  ) {
    final deviceName = deviceData['name'] ?? 'Unknown Device';
    final files = List<dynamic>.from(deviceData['files'] ?? []);

    // Display only first 5 files to avoid cluttering the UI
    final displayFiles = files.length > 5 ? files.sublist(0, 5) : files;

    return Card(
      margin: EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            leading: Icon(Icons.devices_other, color: Colors.blue),
            title: Text(deviceName),
            subtitle: Text('${files.length} files available'),
            trailing: TextButton.icon(
              icon: Icon(Icons.visibility, size: 16),
              label: Text('View All'),
              onPressed: () => _viewAllDeviceFiles(deviceId, deviceName, files),
            ),
          ),
          if (files.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Center(child: Text('No files available')),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              itemCount: displayFiles.length,
              itemBuilder: (context, index) {
                final file = displayFiles[index];
                final isDir = file['isDirectory'] ?? false;

                return ListTile(
                  dense: true,
                  leading: Icon(
                    isDir ? Icons.folder : _getFileIcon(file['name']),
                    size: 20,
                    color: isDir ? Colors.amber : Colors.blue,
                  ),
                  title: Text(file['name'], overflow: TextOverflow.ellipsis),
                  subtitle:
                      isDir
                          ? Text('Directory')
                          : Text('${_formatFileSize(file['size'] ?? 0)}'),
                  trailing: ElevatedButton.icon(
                    icon: Icon(
                      isDir ? Icons.folder_open : Icons.download,
                      size: 16,
                    ),
                    label: Text(
                      isDir ? 'Open' : 'Get',
                      style: TextStyle(fontSize: 12),
                    ),
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                      minimumSize: Size(0, 0),
                    ),
                    onPressed:
                        () => _handleFileAction(deviceId, deviceName, file),
                  ),
                );
              },
            ),
          if (files.length > 5)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Center(
                child: Text(
                  '+ ${files.length - 5} more files',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // Helper methods
  void _viewAllDeviceFiles(
    String deviceId,
    String deviceName,
    List<dynamic> files,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => RemoteFilesScreen(
              deviceId: deviceId,
              deviceName: deviceName,
              initialFiles: List<Map<String, dynamic>>.from(
                files.map((file) => Map<String, dynamic>.from(file)),
              ),
              initialPath: '',
            ),
      ),
    );
  }

  void _handleFileAction(
    String deviceId,
    String deviceName,
    Map<String, dynamic> file,
  ) {
    final isDir = file['isDirectory'] ?? false;

    if (isDir) {
      // Navigate to directory
      final connectionService = Provider.of<ConnectionService>(
        context,
        listen: false,
      );
      connectionService.requestRemoteFileList(deviceId, file['path']);

      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder:
            (context) => AlertDialog(
              title: Text('Loading'),
              content: Row(
                children: [
                  CircularProgressIndicator(),
                  SizedBox(width: 16),
                  Expanded(child: Text('Opening ${file['name']}...')),
                ],
              ),
            ),
      );

      // First declare the variable
      StreamSubscription? subscription;

      // Then assign it separately
      subscription = connectionService.broadcastStream?.listen((message) {
        if (message is String) {
          try {
            final data = jsonDecode(message);
            if (data['type'] == 'file_list_response' &&
                data['requesterId'] == connectionService.deviceId &&
                data['sourceId'] == deviceId) {
              // Cancel subscription
              subscription?.cancel();

              // Close loading dialog
              Navigator.of(context, rootNavigator: true).pop();

              // Navigate
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder:
                      (context) => RemoteFilesScreen(
                        deviceId: deviceId,
                        deviceName: deviceName,
                        initialFiles: List<Map<String, dynamic>>.from(
                          data['files'].map(
                            (file) => Map<String, dynamic>.from(file),
                          ),
                        ),
                        initialPath: file['path'],
                      ),
                ),
              );
            }
          } catch (e) {
            print('Error: $e');
          }
        }
      });

      // Set timeout
      Future.delayed(Duration(seconds: 5), () {
        subscription?.cancel();
        if (Navigator.of(context, rootNavigator: true).canPop()) {
          Navigator.of(context, rootNavigator: true).pop();
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Request timed out')));
        }
      });
    } else {
      // Download file
      final connectionService = Provider.of<ConnectionService>(
        context,
        listen: false,
      );
      connectionService.requestRemoteFile(deviceId, file['path']);

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Downloading ${file['name']}...')));
    }
  }
}

// Keep these event classes in your file
class FileAccessRequestEvent {
  final String requesterId;
  final String requesterName;

  FileAccessRequestEvent({
    required this.requesterId,
    required this.requesterName,
  });
}

class FileAccessGrantedEvent {
  final String deviceId;

  FileAccessGrantedEvent({required this.deviceId});
}

class FileAccessDeniedEvent {
  final String deviceId;

  FileAccessDeniedEvent({required this.deviceId});
}

class PhotosScreen extends StatelessWidget {
  const PhotosScreen({super.key});

  void openFileByPath(String path) async {
    try {
      final result = await OpenFile.open(path);
      if (result.type != ResultType.done) {
        print('Error opening file: ${result.message}');
      }
    } catch (e) {
      print('Exception while opening file: $e');
    }
  }

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

  void openFileByPath(String path) async {
    try {
      final result = await OpenFile.open(path);
      if (result.type != ResultType.done) {
        print('Error opening file: ${result.message}');
      }
    } catch (e) {
      print('Exception while opening file: $e');
    }
  }

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

  // Add this method to fix the error
  void openFileByPath(String path) async {
    try {
      final result = await OpenFile.open(path);
      if (result.type != ResultType.done) {
        print('Error opening file: ${result.message}');
      }
    } catch (e) {
      print('Exception while opening file: $e');
    }
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
