import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:open_file/open_file.dart';
import 'package:path/path.dart' as path;

class StorageFilesScreen extends StatefulWidget {
  final String initialPath;

  const StorageFilesScreen({
    Key? key,
    required this.initialPath,
  }) : super(key: key);

  @override
  _StorageFilesScreenState createState() => _StorageFilesScreenState();
}

class _StorageFilesScreenState extends State<StorageFilesScreen> {
  late String _currentPath;
  List<FileSystemEntity> _files = [];
  bool _isLoading = true;
  bool _isGridView = false; // Default to list view

  @override
  void initState() {
    super.initState();
    _currentPath = widget.initialPath;
    _loadFiles();
  }

  Future<void> _loadFiles() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final directory = Directory(_currentPath);
      final files = await directory.list().toList();
      setState(() {
        _files = files;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading files: $e');
      setState(() {
        _files = [];
        _isLoading = false;
      });
    }
  }

  // Function to get file icon based on extension
  IconData _getFileIcon(String filePath) {
    final ext = path.extension(filePath).toLowerCase().replaceFirst('.', '');

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
  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(2)} KB';
    if (bytes < 1024 * 1024 * 1024) 
      return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  // Helper method to check if a file is an image
  bool _isImageFile(String filePath) {
    final ext = path.extension(filePath).toLowerCase();
    return ['.jpg', '.jpeg', '.png', '.gif', '.bmp', '.webp'].contains(ext);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Storage Files'),
        actions: [
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
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadFiles,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          // Current path display
          Container(
            padding: EdgeInsets.all(8),
            width: double.infinity,
            color: Theme.of(context).colorScheme.surface,
            child: Text(
              _currentPath,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                color: Colors.grey[600],
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),

          // Files list/grid
          Expanded(
            child: _isLoading 
                ? Center(child: CircularProgressIndicator())
                : _files.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.folder_open, size: 64, color: Colors.grey),
                            SizedBox(height: 16),
                            Text('No files found in this location'),
                          ],
                        ),
                      )
                    : _isGridView ? _buildGridView() : _buildListView(),
          ),
        ],
      ),
    );
  }

  Widget _buildListView() {
    return ListView.builder(
      itemCount: _files.length,
      itemBuilder: (context, index) {
        final file = _files[index];
        final fileName = path.basename(file.path);
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

              final modified = DateFormat('MMM d, yyyy').format(snapshot.data!.modified);
              final size = isDirectory ? 'Directory' : _formatFileSize(snapshot.data!.size);

              return Text('$modified • $size');
            },
          ),
          onTap: isDirectory
              ? () {
                  setState(() {
                    _currentPath = file.path;
                  });
                  _loadFiles();
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

  Widget _buildGridView() {
    return GridView.builder(
      padding: EdgeInsets.all(8),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 1.0,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: _files.length,
      itemBuilder: (context, index) {
        final file = _files[index];
        final fileName = path.basename(file.path);
        final isDirectory = file is Directory;
        
        return GestureDetector(
          onTap: isDirectory
              ? () {
                  setState(() {
                    _currentPath = file.path;
                  });
                  _loadFiles();
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
                    child: _isImageFile(file.path) && !isDirectory
                        ? ClipRRect(
                            borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                            child: Image.file(
                              File(file.path),
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Icon(
                                  _getFileIcon(file.path),
                                  size: 48,
                                  color: isDirectory ? Colors.amber[700] : Colors.blue[700],
                                );
                              },
                            ),
                          )
                        : Center(
                            child: Icon(
                              isDirectory ? Icons.folder : _getFileIcon(file.path),
                              size: 48,
                              color: isDirectory ? Colors.amber[700] : Colors.blue[700],
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
                                style: TextStyle(fontSize: 11, color: Colors.grey),
                              );
                            }

                            final size = isDirectory ? 'Directory' : _formatFileSize(snapshot.data!.size);

                            return Text(
                              size,
                              style: TextStyle(fontSize: 11, color: Colors.grey),
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
}