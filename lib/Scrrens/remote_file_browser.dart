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

  const RemoteFileBrowserScreen({
    Key? key,
    required this.deviceId,
    required this.deviceName,
    this.initialPath = '',
  }) : super(key: key);

  @override
  _RemoteFileBrowserScreenState createState() => _RemoteFileBrowserScreenState();
}

class _RemoteFileBrowserScreenState extends State<RemoteFileBrowserScreen> {
  String _currentPath = '';
  List<Map<String, dynamic>> _files = [];
  bool _isLoading = true;
  String? _errorMessage;
  List<String> _pathHistory = [];
  List<String> _breadcrumbs = [];

  @override
  void initState() {
    super.initState();
    _currentPath = widget.initialPath;
    _updateBreadcrumbs();
    _loadFiles();
  }

  void _updateBreadcrumbs() {
    if (_currentPath.isEmpty) {
      setState(() {
        _breadcrumbs = ['Root'];
      });
      return;
    }

    final parts = _currentPath.split('/').where((part) => part.isNotEmpty).toList();
    setState(() {
      _breadcrumbs = ['Root', ...parts];
    });
  }

  Future<void> _loadFiles() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final connectionService = Provider.of<ConnectionService>(context, listen: false);
    
    try {
      await connectionService.requestDirectoryListing(
        widget.deviceId, 
        _currentPath,
        onSuccess: (files) {
          setState(() {
            _files = files;
            _isLoading = false;
          });
        },
        onError: (error) {
          setState(() {
            _errorMessage = error;
            _isLoading = false;
          });
        },
      );
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load files: $e';
        _isLoading = false;
      });
    }
  }

  void _navigateToDirectory(String dirName) {
    // Save current path to history for back navigation
    _pathHistory.add(_currentPath);
    
    // Navigate to new path
    final newPath = _currentPath.isEmpty 
        ? dirName 
        : '$_currentPath/$dirName';
    
    setState(() {
      _currentPath = newPath;
    });
    
    _updateBreadcrumbs();
    _loadFiles();
  }
  
  void _navigateToBreadcrumb(int index) {
    if (index == 0) {
      // Root directory
      _pathHistory.add(_currentPath);
      setState(() {
        _currentPath = '';
      });
      _updateBreadcrumbs();
      _loadFiles();
      return;
    }
    
    // Construct path up to the selected breadcrumb
    final parts = _currentPath.split('/').where((part) => part.isNotEmpty).toList();
    if (index - 1 < parts.length) {
      _pathHistory.add(_currentPath);
      final newPath = parts.sublist(0, index).join('/');
      setState(() {
        _currentPath = newPath;
      });
      _updateBreadcrumbs();
      _loadFiles();
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
    _updateBreadcrumbs();
    _loadFiles();
  }

  void _downloadFile(Map<String, dynamic> file) {
    final connectionService = Provider.of<ConnectionService>(
      context,
      listen: false,
    );

    final filePath = _currentPath.isEmpty 
        ? file['name'] 
        : '$_currentPath/${file['name']}';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Requesting file ${file['name']}...')),
    );

    connectionService.requestFile(
      widget.deviceId,
      filePath,
      onSuccess: (savedFile) {
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
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: _goBack,
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadFiles,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          // Breadcrumb navigation
          Container(
            height: 48,
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (int i = 0; i < _breadcrumbs.length; i++)
                  Row(
                    children: [
                      InkWell(
                        onTap: () => _navigateToBreadcrumb(i),
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                          child: Text(
                            _breadcrumbs[i],
                            style: TextStyle(
                              color: i == _breadcrumbs.length - 1
                                  ? Theme.of(context).primaryColor
                                  : Colors.blue,
                              fontWeight: i == _breadcrumbs.length - 1
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                        ),
                      ),
                      if (i < _breadcrumbs.length - 1)
                        Icon(Icons.chevron_right, size: 16),
                    ],
                  ),
              ],
            ),
          ),
          
          Divider(height: 1),
          
          // File listing
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator())
                : _errorMessage != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.error_outline, size: 48, color: Colors.red),
                              SizedBox(height: 16),
                              Text(
                                _errorMessage!,
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.red),
                              ),
                              SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: _loadFiles,
                                child: Text('Retry'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : _files.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.folder_off, size: 48, color: Colors.grey),
                                  SizedBox(height: 16),
                                  Text('No files found in this location'),
                                ],
                              ),
                            ),
                          )
                        : _buildFilesList(),
          ),
        ],
      ),
    );
  }
  
  Widget _buildFilesList() {
    // Sort files: directories first, then alphabetically
    final sortedFiles = List<Map<String, dynamic>>.from(_files);
    sortedFiles.sort((a, b) {
      final aIsDir = a['isDirectory'] == true;
      final bIsDir = b['isDirectory'] == true;
      if (aIsDir && !bIsDir) return -1;
      if (!aIsDir && bIsDir) return 1;
      return (a['name'] ?? '').toString().compareTo((b['name'] ?? '').toString());
    });

    return ListView.separated(
      itemCount: sortedFiles.length,
      separatorBuilder: (context, index) => Divider(height: 1),
      itemBuilder: (context, index) {
        final file = sortedFiles[index];
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
          trailing: isDir
              ? Icon(Icons.chevron_right)
              : IconButton(
                  icon: Icon(Icons.download),
                  tooltip: 'Download',
                  onPressed: () => _downloadFile(file),
                ),
          onTap: isDir
              ? () => _navigateToDirectory(fileName)
              : () => _downloadFile(file),
        );
      },
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
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
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
