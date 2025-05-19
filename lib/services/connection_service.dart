import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:datavault/services/event_bus_service.dart';
import 'package:path/path.dart' as path;
import 'package:datavault/utils/storage_manager.dart';

class ConnectionService with ChangeNotifier {
  static final ConnectionService _instance = ConnectionService._internal();
  factory ConnectionService() => _instance;

  ConnectionService._internal();

  WebSocketChannel? _channel;
  Stream<dynamic>? _broadcastStream;
  bool _isConnected = false;
  String? _deviceId;
  String? deviceName;
  List<Map<String, dynamic>> _connectedClients = [];
  Timer? _pingTimer;

  // Add to ConnectionService class
  Map<String, bool> _grantedPermissions = {};
  Map<String, String> _pendingPermissionRequests = {};

  // Add device files mapping
  Map<String, Map<String, dynamic>> _deviceFiles = {}; // Store device file listings
  Map<String, Map<String, dynamic>> get deviceFiles => _deviceFiles; // Expose device files

  // Add this method to track directory structure

  // Store cached directory listings for quicker navigation
  final Map<String, Map<String, List<Map<String, dynamic>>>> _cachedDirectories = {};

  WebSocketChannel? get channel => _channel;
  Stream<dynamic>? get broadcastStream => _broadcastStream;
  bool get isConnected => _isConnected;
  String? get deviceId => _deviceId;
  List<Map<String, dynamic>> get connectedClients => _connectedClients;

  Future<void> connect(String serverAddress) async {
    if (_isConnected) return;
    
    try {
      // Close existing connection if any
      await _channel?.sink.close();
      
      // Connect to WebSocket server
      final wsUrl = Uri.parse('ws://$serverAddress:8080');
      _channel = WebSocketChannel.connect(wsUrl);
      
      // Create a broadcast stream
      _broadcastStream = _channel!.stream.asBroadcastStream();
      
      // Load device ID and name
      await _loadDeviceInfo();
      
      // Register this device
      _channel!.sink.add(jsonEncode({
        "type": "register_device",
        "deviceName": deviceName ?? "DataVault User",
        "deviceId": _deviceId,
      }));
      
      // Request connected devices list
      _channel!.sink.add(jsonEncode({"type": "get_connected_devices"}));
      
      // Setup listeners
      _setupListeners();
      
      // Start ping timer
      _startPingTimer();
      
      _isConnected = true;
      notifyListeners();
    } catch (e) {
      print('Connection error: $e');
      _isConnected = false;
      notifyListeners();
      rethrow;
    }
  }

  void disconnect() {
    _pingTimer?.cancel();
    _channel?.sink.close();
    _isConnected = false;
    notifyListeners();
  }

  void _setupListeners() {
    _broadcastStream?.listen(
      (message) {
        try {
          if (message is String) {
            final data = jsonDecode(message);
            
            if (data['type'] == 'device_registered') {
              _saveDeviceId(data['deviceId']);
            }
            
            if (data['type'] == 'connected_devices') {
              final devices = data['devices'];
              if (devices is List) {
                _connectedClients = List<Map<String, dynamic>>.from(
                  devices.map((client) => Map<String, dynamic>.from(client)),
                );
                notifyListeners();
              }
            }

            if (data['type'] == 'file_access_request') {
              final requesterId = data['requesterId'];
              final requesterName = data['requesterName'];
              
              _pendingPermissionRequests[requesterId] = requesterName;
              
              // Notify listeners so UI can show permission dialog
              notifyListeners();
              
              // Also broadcast an event for this
              eventBus.fire(FileAccessRequestEvent(
                requesterId: requesterId,
                requesterName: requesterName
              ));
            }

            if (data['type'] == 'file_access_response') {
              final granted = data['granted'] == true;
              final targetId = data['targetId'];
              
              if (granted) {
                _grantedPermissions[targetId] = true;
                // Now we can proceed with file listing
                eventBus.fire(FileAccessGrantedEvent(deviceId: targetId));
              } else {
                _grantedPermissions[targetId] = false;
                eventBus.fire(FileAccessDeniedEvent(deviceId: targetId));
              }
              
              notifyListeners();
            }

            _channel!.stream.listen((message) {
              if (message is String) {
                try {
                  final data = jsonDecode(message);
                  
                  // Add the code here
                  if (data['type'] == 'request_initial_file_list') {
                    _sendInitialFileList();
                  }
                  
                  if (data['type'] == 'device_files_update') {
                    final deviceId = data['deviceId'];
                    final deviceName = data['deviceName'];
                    final files = data['files'];
                    
                    // Store the files listing
                    _storeDeviceFiles(deviceId, deviceName, files);
                    
                    // Notify listeners
                    notifyListeners();
                  }
                } catch (e) {
                  // Error handling
                }
              } else if (message is List<int>) {
                // Handle binary data (file content)
                _handleIncomingFile(message);
              }
            });
          }
        } catch (e) {
          print('Error processing message: $e');
        }
      },
      onError: (error) {
        print('WebSocket error: $error');
        _isConnected = false;
        notifyListeners();
      },
      onDone: () {
        print('WebSocket connection closed');
        _isConnected = false;
        notifyListeners();
      },
    );
  }

  void _startPingTimer() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(Duration(seconds: 15), (timer) {
      if (_channel != null) {
        try {
          _channel!.sink.add(jsonEncode({"type": "ping"}));
        } catch (e) {
          _isConnected = false;
          _pingTimer?.cancel();
          notifyListeners();
        }
      }
    });
  }

  Future<void> _loadDeviceInfo() async {
    final prefs = await SharedPreferences.getInstance();
    _deviceId = prefs.getString('device_id');
    deviceName = prefs.getString('device_name') ?? "DataVault User";
  }

  Future<void> _saveDeviceId(String id) async {
    _deviceId = id;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('device_id', id);
    notifyListeners();
  }

  Future<void> updateDeviceName(String name) async {
    deviceName = name;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('device_name', name);
    
    if (_isConnected && _channel != null) {
      _channel!.sink.add(jsonEncode({
        "type": "update_device_name",
        "deviceId": _deviceId,
        "deviceName": name,
      }));
    }
    
    notifyListeners();
  }

  Future<void> requestRemoteFileList(String deviceId, [String? path]) async {
    if (!_isConnected || _channel == null) {
      throw Exception('Not connected to server');
    }
    
    _channel!.sink.add(jsonEncode({
      "type": "list_files",
      "targetId": deviceId,
      "path": path ?? '',
      "requesterId": _deviceId,
    }));
  }

  Future<void> requestRemoteFile(String deviceId, String filePath) async {
    if (!_isConnected || _channel == null) {
      throw Exception('Not connected to server');
    }
    
    final fileName = filePath.split('/').last;
    
    _channel!.sink.add(jsonEncode({
      "type": "request_file",
      "targetId": deviceId,
      "path": filePath,
      "filename": fileName,
      "requesterId": _deviceId,
    }));
  }

  // Check if a device has permission
  bool hasPermissionForDevice(String deviceId) {
    return _grantedPermissions[deviceId] == true;
  }

  // Request permission to access files
  Future<void> requestFileAccess(String deviceId) async {
    if (!_isConnected || _channel == null) {
      throw Exception('Not connected to server');
    }
    
    _channel!.sink.add(jsonEncode({
      "type": "request_file_access",
      "targetId": deviceId,
      "requesterId": _deviceId,
    }));
    
    // Track this pending request
    _pendingPermissionRequests[deviceId] = 'pending';
    notifyListeners();
  }

  // Grant permission to a device
  void grantPermissionTo(String deviceId) {
    if (!_isConnected || _channel == null) return;
    
    _channel!.sink.add(jsonEncode({
      "type": "file_access_response",
      "requesterId": deviceId,
      "granted": true
    }));
  }

  // Deny permission to a device
  void denyPermissionTo(String deviceId) {
    if (!_isConnected || _channel == null) return;
    
    _channel!.sink.add(jsonEncode({
      "type": "file_access_response",
      "requesterId": deviceId,
      "granted": false
    }));
    
    // Remove from pending requests
    _pendingPermissionRequests.remove(deviceId);
    notifyListeners();
  }

  void _storeDeviceFiles(String deviceId, String deviceName, List<dynamic> files) {
    _deviceFiles[deviceId] = {
      'name': deviceName,
      'files': files,
    };
  }

  // Replace the _sendInitialFileList method with this enhanced version

  Future<void> _sendInitialFileList() async {
    try {
      final storagePath = await StorageManager.getDefaultStoragePath();
      final directory = Directory(storagePath);
      List<Map<String, dynamic>> files = [];
      
      if (await directory.exists()) {
        await _collectFilesRecursively(directory, files, storagePath);
      }
      
      if (_channel != null) {
        print('Sending initial file list with ${files.length} items');
        _channel!.sink.add(jsonEncode({
          "type": "initial_file_list_response",
          "files": files,
        }));
      }
    } catch (e) {
      print('Error sending initial file list: $e');
    }
  }

  // Add this helper method to scan folders recursively
  Future<void> _collectFilesRecursively(
    Directory directory, 
    List<Map<String, dynamic>> files,
    String basePath,
    [String relativePath = '']
  ) async {
    if (!await directory.exists()) return;
    
    try {
      final entities = await directory.list().toList();
      
      for (var entity in entities) {
        try {
          final stat = await entity.stat();
          final name = path.basename(entity.path);
          final isDir = entity is Directory;
          
          // Calculate path relative to storage root
          final filePath = relativePath.isEmpty ? name : '$relativePath/$name';
          
          files.add({
            'name': name,
            'path': filePath,
            'isDirectory': isDir,
            'size': isDir ? 0 : stat.size,
            'modified': stat.modified.toIso8601String(),
          });
          
          // Recursively process subdirectories
          if (isDir) {
            await _collectFilesRecursively(
              Directory(entity.path),
              files,
              basePath,
              filePath,
            );
          }
        } catch (e) {
          print('Error processing file $entity during scan: $e');
        }
      }
    } catch (e) {
      print('Error listing directory $directory: $e');
    }
  }

  // Request a file from a remote device
  Future<void> requestFile(
    String deviceId, 
    String filePath, 
    {Function(File)? onSuccess, Function(String)? onError}
  ) async {
    if (!isConnected || _channel == null) {
      if (onError != null) {
        onError('Not connected to server');
      }
      return;
    }

    try {
      print('Requesting file from $deviceId: $filePath');
      _channel!.sink.add(jsonEncode({
        "type": "request_file",
        "targetId": deviceId,
        "filename": filePath
      }));
      
      // Store expected file details for tracking
      _expectedFile = {
        'filename': filePath,
        'fromId': deviceId,
        'onSuccess': onSuccess,
        'onError': onError,
      };
      
      // Set a timeout
      Future.delayed(Duration(seconds: 30), () {
        if (_expectedFile != null && _expectedFile!['filename'] == filePath) {
          print('File request timed out: $filePath');
          if (onError != null) {
            onError('Request timed out after 30 seconds');
          }
          _expectedFile = null;
        }
      });
    } catch (e) {
      print('Error requesting file: $e');
      if (onError != null) {
        onError('Error sending request: $e');
      }
    }
  }

  Map<String, dynamic>? _expectedFile;

  // Add this helper method to handle incoming file data
  Future<void> _handleIncomingFile(List<int> fileData) async {
    try {
      if (_expectedFile == null) {
        print('Received unexpected file data');
        return;
      }
      
      final senderId = _expectedFile!['fromId'] as String;
      final fileName = _expectedFile!['filename'] as String;
      final onSuccess = _expectedFile!['onSuccess'] as Function(File)?;
      final onError = _expectedFile!['onError'] as Function(String)?;
      
      // Find client name
      String senderName = 'Unknown Device';
      final senderDevice = _connectedClients.firstWhere(
        (client) => client['id'] == senderId,
        orElse: () => {'name': 'Unknown Device'},
      );
      senderName = senderDevice['name'] ?? 'Unknown Device';
      
      // Use sender name for subfolder
      String safeSenderName = senderName.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
      
      // Save file
      final file = await StorageManager.saveToDefaultStorage(
        path.basename(fileName),  // Use only the filename part
        Uint8List.fromList(fileData),
        subfolder: safeSenderName,
      );
      
      print('File saved: ${file.path}');
      
      // Call success callback if provided
      if (onSuccess != null) {
        onSuccess(file);
      }
      
      // Reset
      _expectedFile = null;
    } catch (e) {
      print('Error handling incoming file: $e');
      final onError = _expectedFile?['onError'] as Function(String)?;
      if (onError != null) {
        onError('Error saving file: $e');
      }
      _expectedFile = null;
    }
  }

  // Add this method to your ConnectionService class

  Future<List<Map<String, dynamic>>> requestDirectoryListing(
    String deviceId, 
    String path, 
    {bool recursive = false, 
     Function(List<Map<String, dynamic>>)? onSuccess, Function(String)? onError}
  ) async {
    if (!isConnected || _channel == null) {
      if (onError != null) {
        onError('Not connected to server');
      }
      throw Exception('Not connected to server');
    }

    // Check the cache first
    if (_cachedDirectories.containsKey(deviceId) && 
        _cachedDirectories[deviceId]!.containsKey(path)) {
      final cachedFiles = _cachedDirectories[deviceId]![path]!;
      if (onSuccess != null) {
        onSuccess(cachedFiles);
      }
      return cachedFiles;
    }

    try {
      print('Requesting directory listing from $deviceId for path: $path');
      
      final completer = Completer<List<Map<String, dynamic>>>();
      StreamSubscription? subscription;
      
      subscription = _broadcastStream?.listen((message) {
        if (message is String) {
          try {
            final data = jsonDecode(message);
            if (data['type'] == 'file_list_response' && 
                data['sourceId'] == deviceId &&
                data['requesterId'] == _deviceId &&
                data['path'] == path) {
              
              // Cancel subscription
              subscription?.cancel();
              
              // Parse the files
              final files = List<Map<String, dynamic>>.from(
                data['files']?.map((file) => Map<String, dynamic>.from(file)) ?? []
              );
              
              // Cache the result
              if (!_cachedDirectories.containsKey(deviceId)) {
                _cachedDirectories[deviceId] = {};
              }
              _cachedDirectories[deviceId]![path] = files;
              
              if (onSuccess != null) {
                onSuccess(files);
              }
              
              completer.complete(files);
            }
          } catch (e) {
            print('Error parsing directory listing: $e');
            if (!completer.isCompleted) {
              completer.completeError('Failed to parse response');
            }
          }
        }
      });
      
      // Send the request
      _channel!.sink.add(jsonEncode({
        "type": "request_directory_listing",
        "targetId": deviceId,
        "path": path,
        "requesterId": _deviceId,
        "recursive": recursive,
      }));
      
      // Set a timeout
      Timer(Duration(seconds: 10), () {
        if (!completer.isCompleted) {
          subscription?.cancel();
          if (onError != null) {
            onError('Request timed out');
          }
          completer.completeError('Request timed out');
        }
      });
      
      return completer.future;
    } catch (e) {
      print('Error requesting directory listing: $e');
      if (onError != null) {
        onError('Error: $e');
      }
      rethrow;
    }
  }

  // Method to clear cached directories (e.g., when refreshing)
  void clearDirectoryCache([String? deviceId, String? path]) {
    if (deviceId == null) {
      _cachedDirectories.clear();
    } else if (path == null) {
      _cachedDirectories.remove(deviceId);
    } else if (_cachedDirectories.containsKey(deviceId)) {
      _cachedDirectories[deviceId]?.remove(path);
    }
  }

  @override
  void dispose() {
    disconnect();
    super.dispose();
  }
}