import 'dart:async';
import 'dart:convert';
import 'package:datavault/services/connection_service.dart';
import 'package:datavault/utils/storage_manager.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:open_file/open_file.dart';
import 'package:path/path.dart' as path;
import 'dart:io';

import 'package:provider/provider.dart';

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
    this.initialPath = '',
  }) : super(key: key);

  @override
  _RemoteFilesScreenState createState() => _RemoteFilesScreenState();
}

class _RemoteFilesScreenState extends State<RemoteFilesScreen> {
  late List<Map<String, dynamic>> _files;
  late String _currentPath;
  bool _isLoading = false;
  List<String> _navigationHistory = [];
  List<String> _breadcrumbs = [];

  @override
  void initState() {
    super.initState();
    _files = widget.initialFiles;
    _currentPath = widget.initialPath;
    _updateBreadcrumbs();
  }

  void _updateBreadcrumbs() {
    if (_currentPath.isEmpty) {
      setState(() {
        _breadcrumbs = ['Root'];
      });
    } else {
      final parts = _currentPath.split('/');
      setState(() {
        _breadcrumbs = ['Root', ...parts];
      });
    }
  }

  void _navigateToPath(String path) {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    // Request remote file list
    final connectionService = Provider.of<ConnectionService>(
      context,
      listen: false,
    );

    // Add current path to history before changing
    if (_currentPath.isNotEmpty) {
      _navigationHistory.add(_currentPath);
    }

    connectionService.requestRemoteFileList(widget.deviceId, path);

    // Listen for response
    StreamSubscription? subscription;
    subscription = connectionService.broadcastStream?.listen((message) {
      if (message is String) {
        try {
          final data = jsonDecode(message);
          if (data['type'] == 'file_list_response' &&
              data['requesterId'] == connectionService.deviceId &&
              data['sourceId'] == widget.deviceId) {
            // Cancel subscription
            subscription?.cancel();

            setState(() {
              _files = List<Map<String, dynamic>>.from(
                data['files'].map((file) => Map<String, dynamic>.from(file)),
              );
              _currentPath = path;
              _isLoading = false;
              _updateBreadcrumbs();
            });
          }
        } catch (e) {
          print('Error: $e');
          setState(() {
            _isLoading = false;
          });
        }
      }
    });

    // Set timeout
    Future.delayed(Duration(seconds: 10), () {
      if (_isLoading) {
        subscription?.cancel();
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Request timed out. Please try again.')),
        );
      }
    });
  }

  void _goBack() {
    if (_navigationHistory.isEmpty) {
      Navigator.pop(context);
      return;
    }

    final previousPath = _navigationHistory.removeLast();
    _navigateToPath(previousPath);
  }

  void _navigateToBreadcrumb(int index) {
    if (index == 0) {
      // Root
      _navigateToPath('');
      return;
    }

    // Reconstruct path up to the selected breadcrumb
    final parts = _currentPath.split('/');
    final targetPath = parts.take(index).join('/');
    _navigateToPath(targetPath);
  }

  void _downloadFile(Map<String, dynamic> file) {
    final connectionService = Provider.of<ConnectionService>(
      context,
      listen: false,
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Requesting file ${file['name']}...')),
    );

    connectionService.requestFile(
      widget.deviceId,
      path.join(_currentPath, file['name']),
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
        leading: IconButton(icon: Icon(Icons.arrow_back), onPressed: _goBack),
      ),
      body: Column(
        children: [
          // Breadcrumb navigation
          Container(
            height: 50,
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _breadcrumbs.length,
              separatorBuilder:
                  (context, index) =>
                      Icon(Icons.chevron_right, size: 18, color: Colors.grey),
              itemBuilder: (context, index) {
                return Center(
                  child: InkWell(
                    onTap: () => _navigateToBreadcrumb(index),
                    child: Text(
                      _breadcrumbs[index],
                      style: TextStyle(
                        color:
                            index == _breadcrumbs.length - 1
                                ? Theme.of(context).primaryColor
                                : Colors.blue,
                        fontWeight:
                            index == _breadcrumbs.length - 1
                                ? FontWeight.bold
                                : FontWeight.normal,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          Divider(),

          // Files list
          Expanded(
            child:
                _isLoading
                    ? Center(child: CircularProgressIndicator())
                    : (_files.isEmpty
                        ? Center(child: Text('No files in this directory'))
                        : ListView.builder(
                          itemCount: _files.length,
                          itemBuilder: (context, index) {
                            final file = _files[index];
                            final isDir = file['isDirectory'] ?? false;

                            return ListTile(
                              leading: Icon(
                                isDir
                                    ? Icons.folder
                                    : _getFileIcon(file['name']),
                                color: isDir ? Colors.amber : Colors.blue,
                              ),
                              title: Text(file['name']),
                              subtitle: Text(
                                isDir
                                    ? 'Directory'
                                    : '${_formatFileSize(file['size'] ?? 0)} • ${_formatDate(file['modified'])}',
                              ),
                              trailing:
                                  isDir
                                      ? null
                                      : IconButton(
                                        icon: Icon(Icons.download),
                                        onPressed: () => _downloadFile(file),
                                      ),
                              onTap:
                                  isDir
                                      ? () => _navigateToPath(
                                        _currentPath.isEmpty
                                            ? file['name']
                                            : '$_currentPath/${file['name']}',
                                      )
                                      : null,
                            );
                          },
                        )),
          ),
        ],
      ),
    );
  }

  // Helper functions
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
    } else if (['zip', 'rar', '7z', 'tar', 'gz'].contains(ext)) {
      return Icons.folder_zip;
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
