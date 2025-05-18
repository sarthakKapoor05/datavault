import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:datavault/utils/storage_manager.dart'; // Fixed import path

class RemoteFileBrowserScreen extends StatefulWidget {
  final String clientId;
  final String clientName;
  final List<Map<String, dynamic>> initialFiles;
  final String initialPath;
  final Function(String) onRequestPath;
  final Function(String) onRequestFile;
  final WebSocketChannel websocketChannel;

  const RemoteFileBrowserScreen({
    Key? key,
    required this.clientId,
    required this.clientName,
    required this.initialFiles,
    required this.initialPath,
    required this.onRequestPath,
    required this.onRequestFile,
    required this.websocketChannel,
  }) : super(key: key);

  @override
  _RemoteFileBrowserScreenState createState() => _RemoteFileBrowserScreenState();
}

class _RemoteFileBrowserScreenState extends State<RemoteFileBrowserScreen> {
  late List<Map<String, dynamic>> _files;
  late String _currentPath;
  bool _isLoading = false;
  List<String> _pathHistory = [];

  @override
  void initState() {
    super.initState();
    _files = widget.initialFiles;
    _currentPath = widget.initialPath;
    if (_currentPath.isNotEmpty) {
      _pathHistory.add('');  // Root
    }
  }

  void _navigateToDirectory(String dirPath) {
    setState(() {
      _isLoading = true;
      _pathHistory.add(_currentPath);
    });
    
    widget.onRequestPath(dirPath);
  }

  void _navigateUp() {
    if (_pathHistory.isNotEmpty) {
      final previousPath = _pathHistory.removeLast();
      setState(() {
        _isLoading = true;
      });
      widget.onRequestPath(previousPath);
    }
  }

  void _requestFile(String filePath) {
    widget.onRequestFile(filePath);
    Navigator.pop(context);  // Return to previous screen
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
        title: Text('${widget.clientName}\'s Files'),
        elevation: 0,
        actions: [
          if (_pathHistory.isNotEmpty)
            IconButton(
              icon: Icon(Icons.arrow_upward),
              onPressed: _navigateUp,
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
                color: Theme.of(context).colorScheme.secondary,
                fontFamily: 'monospace',
                fontSize: 14,
              ),
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
                      
                      return ListTile(
                        leading: Icon(
                          isDirectory ? Icons.folder : Icons.insert_drive_file,
                          color: isDirectory ? Colors.amber : Colors.blue,
                        ),
                        title: Text(file['name']),
                        subtitle: Text(
                          isDirectory 
                              ? 'Directory' 
                              : '${_formatFileSize(file['size'])} • ${DateFormat('MMM d, yyyy').format(DateTime.parse(file['modified']))}'
                        ),
                        trailing: isDirectory 
                            ? Icon(Icons.chevron_right)
                            : ElevatedButton.icon(
                                icon: Icon(Icons.download, size: 16),
                                label: Text('Get', style: TextStyle(fontSize: 12)),
                                style: ElevatedButton.styleFrom(
                                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                                  minimumSize: Size(0, 0),
                                ),
                                onPressed: () => _requestFile(file['path']),
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
}