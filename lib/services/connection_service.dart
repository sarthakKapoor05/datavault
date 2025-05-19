import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:datavault/services/event_bus_service.dart';
import 'package:path/path.dart' as path;
import 'package:datavault/utils/storage_manager.dart';
import 'package:encrypt/encrypt.dart' as encrypt;

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

  // Add these properties to your ConnectionService class

  // Track ongoing transfers
  Map<String, Map<String, dynamic>> _activeTransfers = {};

  // Public getter for active transfers
  Map<String, Map<String, dynamic>> get activeTransfers => _activeTransfers;

  // Track file requests separately from permission requests
  Map<String, List<String>> _pendingFileRequests = {};

  // Public getter for pending file requests
  Map<String, List<String>> get pendingFileRequests => _pendingFileRequests;

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

  // Replace the _setupListeners method with this fixed version

  void _setupListeners() {
    _broadcastStream?.listen(
      (message) {
        try {
          if (message is String) {
            final data = jsonDecode(message);
            
            if (data['type'] == 'device_registered') {
              _saveDeviceId(data['deviceId']);
            }
            
            else if (data['type'] == 'connected_devices') {
              print('get connected devices');
              final devices = data['devices'];
              if (devices is List) {
                _connectedClients = List<Map<String, dynamic>>.from(
                  devices.map((client) => Map<String, dynamic>.from(client)),
                );
                notifyListeners();
              }
            }

            else if (data['type'] == 'request_file') {
              // Extract data
              final requesterId = data['fromId'] ?? data['requesterId'];
              final filename = data['filename'];
              
              // Find requester name
              String requesterName = 'Unknown Device';
              for (var client in _connectedClients) {
                if (client['id'] == requesterId) {
                  requesterName = client['name'] ?? 'Unknown Device';
                  break;
                }
              }
              
              print('📩 File request received from $requesterName for file: $filename');
              
              // Instead of firing an event, automatically send the file
              _autoSendRequestedFile(requesterId, filename);
            }

            else if (data['type'] == 'file_access_response') {
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
            
            // Add handlers for file requests
            else if (data['type'] == 'request_initial_file_list') {
              _sendInitialFileList();
            }
            
            else if (data['type'] == 'device_files_update') {
              final deviceId = data['deviceId'];
              final deviceName = data['deviceName'];
              final files = data['files'];
              
              // Store the files listing
              _storeDeviceFiles(deviceId, deviceName, files);
              
              // Notify listeners
              notifyListeners();
            }
            
            // Critical: Add file metadata handler
            else if (data['type'] == 'file_metadata') {
              print('Received file metadata: ${data['filename']}, size: ${data['size']} bytes from ${data['fromId']}');
              
              // Store or update expected file details
              if (_expectedFile != null) {
                // Check if this is the file we're expecting
                if (_expectedFile!['fromId'] == data['fromId'] || 
                    path.basename(_expectedFile!['filename'] as String) == path.basename(data['filename'])) {
                  
                  _expectedFile!['size'] = data['size'];
                  _expectedFile!['fromId'] = data['fromId']; // Ensure fromId is set correctly
                  
                  // Store the actual filename from the metadata in case the paths differ
                  _expectedFile!['metadata_filename'] = data['filename'];
                  
                  print('Updated expected file metadata - ready to receive file contents');
                } else {
                  print('Received metadata for unexpected file: ${data['filename']}');
                }
              } else {
                print('Received file metadata but no file was requested');
              }
            }
          } 
          else if (message is List<int>) {
            // Handle binary data (file content)
            _handleIncomingFile(message);
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
      print(await directory.exists());
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
          print(name);
          
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
      
      // First check if we already have a pending file request
      if (_expectedFile != null) {
        if (onError != null) {
          onError('Another file transfer is in progress');
        }
        return;
      }
      
      // Store expected file details for tracking
      _expectedFile = {
        'filename': filePath,
        'fromId': deviceId,
        'onSuccess': onSuccess,
        'onError': onError,
        'requestTime': DateTime.now().millisecondsSinceEpoch,
      };
      
      // Add to active transfers
      _activeTransfers[filePath] = {
        'deviceId': deviceId,
        'fileName': path.basename(filePath),
        'progress': 0.0,
        'status': 'requesting',
        'startTime': DateTime.now(),
      };
      
      // Send the request - make sure we're sending what the server expects
      _channel!.sink.add(jsonEncode({
        "type": "request_file",
        "targetId": deviceId,
        "filename": filePath,  // Send the full path as filename
        "requesterId": _deviceId,
      }));
      
      print('File request sent for: $filePath from device $deviceId');
      
      // Set a timeout
      Future.delayed(Duration(seconds: 60), () {
        final now = DateTime.now().millisecondsSinceEpoch;
        final requestTime = _expectedFile?['requestTime'] as int?;
        
        if (_expectedFile != null && 
            _expectedFile!['filename'] == filePath &&
            now - (requestTime ?? 0) >= 59000) {
          print('File request timed out: $filePath');
          if (onError != null) {
            onError('Request timed out after 60 seconds');
          }
          _expectedFile = null;
        }
      });
    } catch (e) {
      print('Error requesting file: $e');
      if (onError != null) {
        onError('Error sending request: $e');
      }
      _expectedFile = null;
    }
  }

  Map<String, dynamic>? _expectedFile;

  // Add this helper method to handle incoming file data
  Future<void> _handleIncomingFile(List<int> fileData) async {
    if (_expectedFile == null) {
      print('⚠️ Received unexpected file data (${fileData.length} bytes)');
      return;
    }
    
    try {
      print('📥 Received binary data: ${fileData.length} bytes');
      
      final senderId = _expectedFile!['fromId'] as String;
      final filePath = _expectedFile!['filename'] as String;
      final fileName = path.basename(filePath);
      final onSuccess = _expectedFile!['onSuccess'] as Function(File)?;
      final onError = _expectedFile!['onError'] as Function(String)?;
      final isEncrypted = _expectedFile!['encrypted'] as bool? ?? true; // Default to true for safety
      
      // Find client name for logging only
      String senderName = 'Unknown Device';
      for (var client in _connectedClients) {
        if (client['id'] == senderId) {
          senderName = client['name'] ?? 'Unknown Device';
          break;
        }
      }
      
      print('💾 Saving file $fileName from $senderName (path: $filePath) to root folder');
      
      // Decrypt data if it's encrypted
      final bytesToSave = isEncrypted ? decryptFileBytes(fileData) : fileData;
      
      // Save file directly to the root storage folder (no subfolder)
      final file = await StorageManager.saveToDefaultStorage(
        fileName,
        Uint8List.fromList(bytesToSave),
        // Remove the subfolder parameter to save in root folder
      );
      
      print('✅ File saved: ${file.path} (${fileData.length} bytes)');
      
      // Update transfer status to 'completed'
      if (_activeTransfers.containsKey(filePath)) {
        _activeTransfers[filePath]!['progress'] = 1.0;
        _activeTransfers[filePath]!['status'] = 'completed';
        
        // Remove from active transfers after a short delay
        Future.delayed(Duration(seconds: 3), () {
          _activeTransfers.remove(filePath);
          notifyListeners();
        });
        
        notifyListeners();
      }
      
      // Call success callback if provided
      if (onSuccess != null) {
        onSuccess(file);
      }
      
      // Reset
      _expectedFile = null;
    } catch (e) {
      print('❌ Error handling incoming file: $e');
      final onError = _expectedFile?['onError'] as Function(String)?;
      if (onError != null) {
        onError('Error saving file: $e');
      }
      _expectedFile = null;
    }
  }

  List<int> decryptFileBytes(List<int> encryptedBytes) {
    // Extract IV from the first 16 bytes
    final receivedIv = encrypt.IV(
      Uint8List.fromList(encryptedBytes.sublist(0, 16)),
    );
    final encryptedData = encryptedBytes.sublist(16);
    final encrypter = encrypt.Encrypter(
      encrypt.AES(_encryptionKey, mode: encrypt.AESMode.cbc),
    );
    final decrypted = encrypter.decryptBytes(
      encrypt.Encrypted(Uint8List.fromList(encryptedData)),
      iv: receivedIv,
    );
    return decrypted;
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

  // Add this debugging method
  void debugPrintExpectedFile() {
    if (_expectedFile == null) {
      print('DEBUG: No expected file');
      return;
    }
    
    print('DEBUG: Expected File Details:');
    print('  - Filename: ${_expectedFile!['filename']}');
    print('  - From Device: ${_expectedFile!['fromId']}');
    print('  - Size: ${_expectedFile!['size'] ?? 'Unknown'}');
    print('  - Request Time: ${DateTime.fromMillisecondsSinceEpoch(_expectedFile!['requestTime'] as int)}');
    
    // Check if any devices match the expected sender
    for (var client in _connectedClients) {
      if (client['id'] == _expectedFile!['fromId']) {
        print('  - Sender Name: ${client['name']}');
        break;
      }
    }
  }

  // Track transfer progress
  void _updateTransferProgress(String filePath, double progress) {
    if (_activeTransfers.containsKey(filePath)) {
      _activeTransfers[filePath]!['progress'] = progress;
      notifyListeners();
    }
  }

  // Add these methods to ConnectionService

  // Send a file to a device that requested it
  Future<void> sendRequestedFile(String deviceId, String filePath) async {
    if (!isConnected || _channel == null) return;
    
    try {
      // First, check if file exists
      final file = File(filePath);
      if (!await file.exists()) {
        print('❌ File not found: $filePath');
        return;
      }
      
      // Read the file
      final bytes = await file.readAsBytes();
      final fileSize = bytes.length;
      
      // First send metadata
      print('📤 Sending file metadata: $filePath (${fileSize} bytes)');
      _channel!.sink.add(jsonEncode({
        "type": "file_metadata",
        "targetId": deviceId,
        "filename": filePath,
        "size": fileSize,
        "fromId": _deviceId,
      }));
      
      // Wait a moment for metadata to be processed
      await Future.delayed(Duration(milliseconds: 500));
      
      // Then send the actual file content
      print('📤 Sending file content: $filePath');
      _channel!.sink.add(bytes);
      
      // Remove from pending requests
      if (_pendingFileRequests.containsKey(deviceId)) {
        _pendingFileRequests[deviceId]!.remove(filePath);
        if (_pendingFileRequests[deviceId]!.isEmpty) {
          _pendingFileRequests.remove(deviceId);
        }
      }
      
      print('✅ File sent: $filePath');
      
      notifyListeners();
    } catch (e) {
      print('❌ Error sending file: $e');
    }
  }

  // Deny file request
  void denyFileRequest(String deviceId, String filePath) {
    if (_pendingFileRequests.containsKey(deviceId)) {
      _pendingFileRequests[deviceId]!.remove(filePath);
      if (_pendingFileRequests[deviceId]!.isEmpty) {
        _pendingFileRequests.remove(deviceId);
      }
      
      // Notify the requester that the file was denied
      if (isConnected && _channel != null) {
        _channel!.sink.add(jsonEncode({
          "type": "file_request_denied",
          "targetId": deviceId,
          "filename": filePath,
          "fromId": _deviceId,
        }));
      }
      
      notifyListeners();
    }
  }

  // Add this method to automatically process file requests
  Future<void> _autoSendRequestedFile(String requesterId, String filePath) async {
    if (!isConnected || _channel == null) return;
    
    try {
      final storagePath = await StorageManager.getDefaultStoragePath();
      final fullPath = path.join(storagePath, filePath);
      final file = File(fullPath);
      
      if (!await file.exists()) {
        print('❌ File not found: $fullPath');
        
        // Notify requester that file wasn't found
        _channel!.sink.add(jsonEncode({
          "type": "file_request_error",
          "targetId": requesterId,
          "filename": filePath,
          "error": "File not found",
          "fromId": _deviceId,
        }));
        
        return;
      }
      
      print('📄 File found, preparing to send: $filePath');
      
      // Read the file
      final fileBytes = await file.readAsBytes();
      
      // Encrypt the file data
      final encryptedBytes = encryptFileBytes(fileBytes);
      final fileSize = encryptedBytes.length;
      
      // First send metadata with encrypted size
      print('📤 Sending file metadata: $filePath (${fileSize} bytes)');
      _channel!.sink.add(jsonEncode({
        "type": "file_metadata",
        "targetId": requesterId,
        "filename": filePath,
        "size": fileSize,
        "fromId": _deviceId,
        "encrypted": true, // Flag to indicate encryption
      }));
      
      // Wait a moment for metadata to be processed
      await Future.delayed(Duration(milliseconds: 500));
      
      // Then send the actual encrypted file content
      print('📤 Sending encrypted file content: $filePath (${fileSize} bytes)');
      _channel!.sink.add(encryptedBytes);
      
      print('✅ File sent successfully: $filePath');
      
      // Optional: Track successful transfers
      _activeTransfers["outgoing-$filePath"] = {
        'deviceId': requesterId,
        'fileName': path.basename(filePath),
        'size': fileSize,
        'progress': 1.0,
        'status': 'sent',
        'startTime': DateTime.now(),
        'encrypted': true,
      };
      
      // Remove tracked transfer after delay
      Future.delayed(Duration(seconds: 5), () {
        _activeTransfers.remove("outgoing-$filePath");
        notifyListeners();
      });
      
      // Create a non-intrusive notification
      _showFileTransferNotification(requesterId, filePath);
      
      notifyListeners();
    } catch (e) {
      print('❌ Error sending requested file: $e');
      
      // Notify requester about the error
      if (_channel != null) {
        _channel!.sink.add(jsonEncode({
          "type": "file_request_error",
          "targetId": requesterId,
          "filename": filePath,
          "error": "Failed to send file: ${e.toString()}",
          "fromId": _deviceId,
        }));
      }
    }
  }

  // Add this to the _autoSendRequestedFile method after initiating the transfer
  // This creates a non-intrusive notification

  void _showFileTransferNotification(String requesterId, String filePath) {
    // Find requester name
    String requesterName = 'Unknown Device';
    for (var client in _connectedClients) {
      if (client['id'] == requesterId) {
        requesterName = client['name'] ?? 'Unknown Device';
        break;
      }
    }

    final fileName = path.basename(filePath);
    
    // Fire an event that can be displayed as a snackbar or overlay
    eventBus.fire(FileTransferStartedEvent(
      deviceId: requesterId,
      deviceName: requesterName,
      fileName: fileName,
      outgoing: true,
    ));
  }
}

  // Add this event class to your event_bus_service.dart
  class FileTransferStartedEvent {
    final String deviceId;
    final String deviceName;
    final String fileName;
    final bool outgoing;

    FileTransferStartedEvent({
      required this.deviceId, 
      required this.deviceName, 
      required this.fileName,
      required this.outgoing,
    });
  }

  // @override
  // void dispose() {
  //   disconnect();
  //   super.dispose();
  // }

  // Add these encryption methods to your ConnectionService class, similar to Nearby_Devices_screen
  // Use a secure key in production!
  final _encryptionKey = encrypt.Key.fromUtf8(
    'my32lengthsupersecretnooneknows!',
  ); // 32 chars

  List<int> encryptFileBytes(List<int> bytes) {
    final iv = encrypt.IV.fromSecureRandom(16); // Random IV for each file
    final encrypter = encrypt.Encrypter(
      encrypt.AES(_encryptionKey, mode: encrypt.AESMode.cbc),
    );
    final encrypted = encrypter.encryptBytes(bytes, iv: iv);
    // Prepend IV to encrypted bytes
    return [...iv.bytes, ...encrypted.bytes];
  }
