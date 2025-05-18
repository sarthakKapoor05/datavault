import 'package:flutter/material.dart';
import 'package:datavault/services/connection_service.dart';
import 'package:provider/provider.dart';
import 'package:path/path.dart' as path;
import 'package:intl/intl.dart';
import 'dart:async';
import 'dart:convert';  // For jsonDecode function
import 'dart:io';       // For File and Directory classes
import 'package:open_file/open_file.dart';
import 'package:datavault/utils/storage_manager.dart';

class RemoteFilesScreen extends StatefulWidget {
  final String deviceId;
  final String deviceName;
  final List<Map<String, dynamic>> initialFiles;
  final String initialPath;

  const RemoteFilesScreen({
    Key? key,
    required this.deviceId,
    required this.deviceName,
    required this.initialFiles,
    required this.initialPath,
  }) : super(key: key);

  @override
  _RemoteFilesScreenState createState() => _RemoteFilesScreenState();
}

class _RemoteFilesScreenState extends State<RemoteFilesScreen> {
  late List<Map<String, dynamic>> _files;
  late String _currentPath;
  bool _isLoading = false;
  List<String> _pathHistory = [];
  Map<String, bool> _downloadingFiles = {};
  StreamSubscription? _streamSubscription;

  @override
  void initState() {
    super.initState();
    _files = widget.initialFiles;
    _currentPath = widget.initialPath;
    if (_currentPath.isNotEmpty) {
      _pathHistory.add('');  // Root directory
    }
    
    // Listen for file list responses
    _setupFileListListener();
  }

  void _setupFileListListener() {
    final connectionService = Provider.of<ConnectionService>(context, listen: false);
    
    _streamSubscription = connectionService.broadcastStream?.listen((message) {
      if (message is String) {
        try {
          final data = jsonDecode(message);
          
          if (data['type'] == 'file_list_response' && 
              data['requesterId'] == connectionService.deviceId) {
            setState(() {
              _files = List<Map<String, dynamic>>.from(
                data['files'].map((file) => Map<String, dynamic>.from(file))
              );
              _isLoading = false;
            });
            
            // Close loading dialog if open
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            }
          }
          
          // Handle file metadata (for downloading)
          if (data['type'] == 'file_metadata' && 
              data['targetId'] == connectionService.deviceId) {
            // File is coming to us
            setState(() {
              _downloadingFiles[data['filename']] = true;
            });
          }
        } catch (e) {
          print('Error processing message: $e');
        }
      } else if (message is List<int> && _downloadingFiles.isNotEmpty) {
        // Handle binary file data
        _handleIncomingFile(message);
      }
    });
  }

  Future<void> _handleIncomingFile(List<int> fileData) async {
    try {
      // Find the filename being downloaded
      final fileName = _downloadingFiles.keys.first;
      
      // Save the file
      final storagePath = await StorageManager.getDefaultStoragePath();
      final downloadsDir = Directory('$storagePath/Remote');
      
      if (!await downloadsDir.exists()) {
        await downloadsDir.create(recursive: true);
      }
      
      final filePath = path.join(downloadsDir.path, fileName);
      final file = File(filePath);
      await file.writeAsBytes(fileData);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('File downloaded: $fileName'),
          action: SnackBarAction(
            label: 'Open',
            onPressed: () => OpenFile.open(filePath),
          ),
        ),
      );
      
      setState(() {
        _downloadingFiles.remove(fileName);
      });
    } catch (e) {
      print('Error saving file: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving file: $e')),
      );
      
      setState(() {
        _downloadingFiles.clear();
      });
    }
  }

  void _navigateToDirectory(String dirPath) {
    setState(() {
      _isLoading = true;
      _pathHistory.add(_currentPath);
      _currentPath = dirPath;
    });
    
    final connectionService = Provider.of<ConnectionService>(context, listen: false);
    connectionService.requestRemoteFileList(widget.deviceId, dirPath);
  }

  void _navigateUp() {
    if (_pathHistory.isNotEmpty) {
      final previousPath = _pathHistory.removeLast();
      setState(() {
        _isLoading = true;
        _currentPath = previousPath;
      });
      
      final connectionService = Provider.of<ConnectionService>(context, listen: false);
      connectionService.requestRemoteFileList(widget.deviceId, previousPath);
    }
  }

  void _requestFile(String filePath, String fileName) {
    setState(() {
      _downloadingFiles[fileName] = true;
    });
    
    final connectionService = Provider.of<ConnectionService>(context, listen: false);
    connectionService.requestRemoteFile(widget.deviceId, filePath);
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Requesting file: $fileName')),
    );
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.deviceName}\'s Files'),
        actions: [
          if (_pathHistory.isNotEmpty)
            IconButton(
              icon: Icon(Icons.arrow_upward),
              onPressed: _navigateUp,
              tooltip: 'Go Up',
            ),
        ],
      ),
      body: Column(
        children: [
          // Path display
          Container(
            padding: EdgeInsets.all(8),
            color: Theme.of(context).colorScheme.primary,
            width: double.infinity,
            child: Text(
              _currentPath.isEmpty ? '/ (Root)' : _currentPath,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 14,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          
          // File list
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
                        Text('No files in this directory'),
                      ],
                    ),
                  )
                : ListView.separated(
                    itemCount: _files.length,
                    separatorBuilder: (context, index) => Divider(height: 1),
                    itemBuilder: (context, index) {
                      final file = _files[index];
                      final isDirectory = file['isDirectory'] == true;
                      final fileName = file['name'];
                      
                      return ListTile(
                        leading: Icon(
                          isDirectory ? Icons.folder : _getFileIcon(fileName),
                          color: isDirectory ? Colors.amber : Colors.blue,
                        ),
                        title: Text(fileName, overflow: TextOverflow.ellipsis),
                        subtitle: Text(
                          isDirectory 
                              ? 'Directory' 
                              : '${_formatFileSize(file['size'])} • ${DateFormat('MMM d, yyyy').format(DateTime.parse(file['modified']))}'
                        ),
                        trailing: isDirectory 
                            ? Icon(Icons.chevron_right)
                            : _downloadingFiles[fileName] == true
                                ? SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : ElevatedButton.icon(
                                    icon: Icon(Icons.download, size: 16),
                                    label: Text('Get', style: TextStyle(fontSize: 12)),
                                    style: ElevatedButton.styleFrom(
                                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                                      minimumSize: Size(0, 0),
                                    ),
                                    onPressed: () => _requestFile(file['path'], fileName),
                                  ),
                        onTap: isDirectory 
                            ? () => _navigateToDirectory(file['path'])
                            : null,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _streamSubscription?.cancel();
    super.dispose();
  }

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
}