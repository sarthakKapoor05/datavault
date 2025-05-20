import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:datavault/services/connection_service.dart';
import 'package:datavault/utils/storage_manager.dart';
import 'package:path/path.dart' as path;
import 'package:open_file/open_file.dart';
import 'package:intl/intl.dart';

class RemoteFileBrowserScreen extends StatefulWidget {
  final String deviceId;
  final String deviceName;
  final String initialPath;
  final bool useTreeView;

  const RemoteFileBrowserScreen({
    Key? key,
    required this.deviceId,
    required this.deviceName,
    this.initialPath = '',
    this.useTreeView = false,
  }) : super(key: key);

  @override
  _RemoteFileBrowserScreenState createState() =>
      _RemoteFileBrowserScreenState();
}

class _RemoteFileBrowserScreenState extends State<RemoteFileBrowserScreen> {
  String _currentPath = '';
  List<Map<String, dynamic>> _files = [];
  Map<String, Map<String, dynamic>> _fileTree = {};
  Map<String, bool> _expandedFolders = {};
  bool _isLoading = true;
  String? _errorMessage;
  List<String> _pathHistory = [];
  bool _useTreeView = false;

  @override
  void initState() {
    super.initState();
    _currentPath = widget.initialPath;
    _useTreeView = widget.useTreeView;
    if (_useTreeView) {
      _loadCompleteFileTree();
    } else {
      _loadCurrentDirectory();
    }
  }

  Future<void> _loadCompleteFileTree() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final connectionService = Provider.of<ConnectionService>(
      context,
      listen: false,
    );

    try {
      final files = await connectionService.requestDirectoryListing(
        widget.deviceId,
        '', // Root directory
        recursive: true, // Request all files recursively
      );

      setState(() {
        _files = files;
        _buildFileTree(files);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load files: $e';
        _isLoading = false;
      });
    }
  }

  void _buildFileTree(List<Map<String, dynamic>> files) {
    // Group files by parent directory
    final tree = <String, List<Map<String, dynamic>>>{};

    for (final file in files) {
      final parentPath = file['parentPath'] ?? '';

      if (!tree.containsKey(parentPath)) {
        tree[parentPath] = [];
      }

      tree[parentPath]!.add(file);
    }

    setState(() {
      _fileTree = Map.fromEntries(
        tree.entries.map(
          (entry) =>
              MapEntry(entry.key, {'files': entry.value, 'expanded': false}),
        ),
      );

      // Expand root by default
      if (_fileTree.containsKey('')) {
        _fileTree['']!['expanded'] = true;
      }
    });
  }

  Future<void> _loadCurrentDirectory() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final connectionService = Provider.of<ConnectionService>(
      context,
      listen: false,
    );

    try {
      final files = await connectionService.requestDirectoryListing(
        widget.deviceId,
        _currentPath,
      );

      setState(() {
        _files = files;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load files: $e';
        _isLoading = false;
      });
    }
  }

  void _navigateToDirectory(String dirName) {
    if (_useTreeView) {
      // In tree view, we just toggle folder expansion
      setState(() {
        final path = _currentPath.isEmpty ? dirName : '$_currentPath/$dirName';
        _expandedFolders[path] = !(_expandedFolders[path] ?? false);
      });
    } else {
      // Standard navigation
      _pathHistory.add(_currentPath);
      final newPath = _currentPath.isEmpty ? dirName : '$_currentPath/$dirName';
      setState(() {
        _currentPath = newPath;
      });
      _loadCurrentDirectory();
    }
  }

  void _goBack() {
    if (_pathHistory.isEmpty) {
      Navigator.of(context).pop();
      return;
    }

    final previousPath = _pathHistory.removeLast();
    setState(() {
      _currentPath = previousPath;
    });
    _loadCurrentDirectory();
  }

  void _toggleViewMode() {
    setState(() {
      _useTreeView = !_useTreeView;
    });

    if (_useTreeView) {
      _loadCompleteFileTree();
    } else {
      _loadCurrentDirectory();
    }
  }

  void _downloadFile(Map<String, dynamic> file) {
    // Show file details dialog first
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('File Details'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ListTile(
                  leading: Icon(_getFileIcon(file['name']), color: Colors.blue),
                  title: Text(
                    file['name'],
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  contentPadding: EdgeInsets.zero,
                ),
                Divider(),
                _buildDetailRow('Type', _getFileType(file['name'])),
                _buildDetailRow('Size', _formatFileSize(file['size'] ?? 0)),
                _buildDetailRow(
                  'Modified',
                  _formatDate(file['modified'] ?? ''),
                ),
                _buildDetailRow('Path', file['path'] ?? ''),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _startFileDownload(file);
                },
                child: Text('Download'),
              ),
            ],
          ),
    );
  }
  
Widget _buildDetailRow(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$title:',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(child: Text(value, style: TextStyle(color: Colors.black87))),
        ],
      ),
    );
  }

String _getFileType(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();

    final typeMap = {
      'jpg': 'JPEG Image',
      'jpeg': 'JPEG Image',
      'png': 'PNG Image',
      'gif': 'GIF Image',
      'bmp': 'Bitmap Image',
      'webp': 'WebP Image',
      'mp4': 'MP4 Video',
      'avi': 'AVI Video',
      'mov': 'QuickTime Video',
      'wmv': 'Windows Media Video',
      'flv': 'Flash Video',
      'mkv': 'Matroska Video',
      'mp3': 'MP3 Audio',
      'wav': 'WAV Audio',
      'ogg': 'OGG Audio',
      'flac': 'FLAC Audio',
      'm4a': 'M4A Audio',
      'pdf': 'PDF Document',
      'doc': 'Word Document',
      'docx': 'Word Document',
      'txt': 'Text File',
      'rtf': 'Rich Text File',
      'xls': 'Excel Spreadsheet',
      'xlsx': 'Excel Spreadsheet',
      'csv': 'CSV File',
      'zip': 'ZIP Archive',
      'rar': 'RAR Archive',
      '7z': '7-Zip Archive',
      'tar': 'TAR Archive',
      'gz': 'GZip Archive',
      'apk': 'Android Package',
    };

    return typeMap[ext] ?? 'File';
  }
void _startFileDownload(Map<String, dynamic> file) {
    final connectionService = Provider.of<ConnectionService>(
      context,
      listen: false,
    );

    final filePath = file['path'];
    final fileName = file['name'];

    // Show progress indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => AlertDialog(
            title: Text('Downloading'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                LinearProgressIndicator(),
                SizedBox(height: 16),
                Text('Downloading $fileName'),
              ],
            ),
          ),
    );

    connectionService.requestFile(
      widget.deviceId,
      filePath,
      onSuccess: (savedFile) {
        // Close progress dialog
        Navigator.pop(context);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('File ${file['name']} downloaded'),
            action: SnackBarAction(
              label: 'Open',
              onPressed: () async {
                await OpenFile.open(savedFile.path);
              },
            ),
          ),
        );
      },
      onError: (error) {
        // Close progress dialog
        Navigator.pop(context);

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $error')));
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("${widget.deviceName}'s Files"),
        leading: IconButton(icon: Icon(Icons.arrow_back), onPressed: _goBack),
        actions: [
          IconButton(
            icon: Icon(_useTreeView ? Icons.list : Icons.account_tree),
            tooltip: _useTreeView ? 'List View' : 'Tree View',
            onPressed: _toggleViewMode,
          ),
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed:
                _useTreeView ? _loadCompleteFileTree : _loadCurrentDirectory,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body:
          _isLoading
              ? Center(child: CircularProgressIndicator())
              : _errorMessage != null
              ? _buildErrorWidget()
              : _useTreeView
              ? _buildTreeView()
              : _buildListView(),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.red),
            SizedBox(height: 16),
            Text(_errorMessage!, textAlign: TextAlign.center),
            SizedBox(height: 24),
            ElevatedButton(
              onPressed:
                  _useTreeView ? _loadCompleteFileTree : _loadCurrentDirectory,
              child: Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListView() {
    if (_files.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.folder_off, size: 64, color: Colors.grey[400]),
            SizedBox(height: 16),
            Text('This folder is empty', style: TextStyle(fontSize: 16)),
          ],
        ),
      );
    }

    // Build breadcrumb navigation
    final List<Widget> breadcrumbs = [
      InkWell(
        onTap: () {
          if (_currentPath.isNotEmpty) {
            _pathHistory.add(_currentPath);
            setState(() {
              _currentPath = '';
            });
            _loadCurrentDirectory();
          }
        },
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          child: Text(
            'Root',
            style: TextStyle(
              color:
                  _currentPath.isEmpty
                      ? Theme.of(context).primaryColor
                      : Colors.blue,
              fontWeight:
                  _currentPath.isEmpty ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    ];

    if (_currentPath.isNotEmpty) {
      final parts = _currentPath.split('/');
      String currentPath = '';

      for (int i = 0; i < parts.length; i++) {
        final part = parts[i];
        currentPath = currentPath.isEmpty ? part : '$currentPath/$part';
        final localPath = currentPath; // Capture for closure

        breadcrumbs.add(
          Icon(Icons.chevron_right, size: 16, color: Colors.grey),
        );

        breadcrumbs.add(
          InkWell(
            onTap: () {
              if (currentPath != _currentPath) {
                _pathHistory.add(_currentPath);
                setState(() {
                  _currentPath = localPath;
                });
                _loadCurrentDirectory();
              }
            },
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 12, horizontal: 8),
              child: Text(
                part,
                style: TextStyle(
                  color:
                      currentPath == _currentPath
                          ? Theme.of(context).primaryColor
                          : Colors.blue,
                  fontWeight:
                      currentPath == _currentPath
                          ? FontWeight.bold
                          : FontWeight.normal,
                ),
              ),
            ),
          ),
        );
      }
    }

    return Column(
      children: [
        // Breadcrumb navigation bar
        Container(
          height: 48,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: breadcrumbs),
          ),
        ),

        Divider(height: 1),

        // File listing
        Expanded(
          child: ListView.separated(
            itemCount: _files.length,
            separatorBuilder: (context, index) => Divider(height: 1),
            itemBuilder: (context, index) {
              final file = _files[index];
              final isDir = file['isDirectory'] == true;
              final fileName = file['name'] ?? 'Unknown';

              return ListTile(
                leading: Icon(
                  isDir ? Icons.folder : _getFileIcon(fileName),
                  color: isDir ? Colors.amber : Colors.blue,
                ),
                title: Text(
                  fileName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  isDir
                      ? 'Directory'
                      : '${_formatFileSize(file['size'] ?? 0)} • ${_formatDate(file['modified'])}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing:
                    isDir
                        ? Icon(Icons.chevron_right)
                        : IconButton(
                          icon: Icon(Icons.download),
                          tooltip: 'Download',
                          onPressed: () => _downloadFile(file),
                        ),
                onTap:
                    isDir
                        ? () => _navigateToDirectory(fileName)
                        : () => _downloadFile(file),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTreeView() {
    return ListView.builder(
      padding: EdgeInsets.all(8),
      itemCount: _fileTree.containsKey('') ? _fileTree['']!['files'].length : 0,
      itemBuilder: (context, index) {
        final files = (_fileTree['']!['files'] as List<Map<String, dynamic>>);
        return _buildFileTreeItem(files[index], 0);
      },
    );
  }

  Widget _buildFileTreeItem(Map<String, dynamic> item, int depth) {
    final isDir = item['isDirectory'] == true;
    final path = item['path'] as String;
    final name = item['name'] as String;
    final expanded = _expandedFolders[path] ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap:
              isDir
                  ? () {
                    setState(() {
                      _expandedFolders[path] = !expanded;
                    });
                  }
                  : () => _downloadFile(item),
          child: Padding(
            padding: EdgeInsets.only(left: depth * 24.0, top: 8, bottom: 8),
            child: Row(
              children: [
                Icon(
                  isDir
                      ? (expanded ? Icons.folder_open : Icons.folder)
                      : _getFileIcon(name),
                  color: isDir ? Colors.amber : Colors.blue,
                  size: 22,
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight:
                              isDir ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      if (!isDir)
                        Text(
                          _formatFileSize(item['size'] ?? 0),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                    ],
                  ),
                ),
                if (!isDir)
                  IconButton(
                    icon: Icon(Icons.download, size: 20),
                    onPressed: () => _downloadFile(item),
                  ),
              ],
            ),
          ),
        ),

        // Show children if this is an expanded directory
        if (isDir && expanded && _fileTree.containsKey(path))
          ..._buildChildrenItems(path, depth + 1),
      ],
    );
  }

  List<Widget> _buildChildrenItems(String parentPath, int depth) {
    final children = _fileTree[parentPath]?['files'] ?? [];
    return List<Widget>.from(
      children.map((child) => _buildFileTreeItem(child, depth)),
    );
  }

  IconData _getFileIcon(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();

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
    } else if (['zip', 'rar', '7z', 'tar', 'gz'].contains(ext)) {
      return Icons.folder_zip;
    } else if (['apk'].contains(ext)) {
      return Icons.android;
    } else {
      return Icons.insert_drive_file;
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024)
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('MMM d, yyyy').format(date);
    } catch (e) {
      return '';
    }
  }
}
