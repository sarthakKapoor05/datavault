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

  WebSocketChannel? get channel => _channel;
  Stream<dynamic>? get broadcastStream => _broadcastStream;
  bool get isConnected => _isConnected;
  String? get deviceId => _deviceId;
  List<Map<String, dynamic>> get connectedClients => _connectedClients;
  Map<String, Map<String, dynamic>> get deviceFiles => _deviceFiles; // Expose device files

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

            // Handle initial file list request
            if (data['type'] == 'request_initial_file_list') {
              _sendInitialFileList();
            }

            // Handle device files update
            if (data['type'] == 'device_files_update') {
              final deviceId = data['deviceId'];
              final deviceName = data['deviceName'];
              final files = data['files'];
              
              // Store the files listing
              _storeDeviceFiles(deviceId, deviceName, files);
              
              // Notify listeners
              notifyListeners();
            }
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

  Future<void> _sendInitialFileList() async {
    try {
      final storagePath = await StorageManager.getDefaultStoragePath();
      final directory = Directory(storagePath);
      List<Map<String, dynamic>> files = [];
      
      if (await directory.exists()) {
        final entities = await directory.list().toList();
        
        for (var entity in entities) {
          final stat = await entity.stat();
          final name = path.basename(entity.path);
          final isDir = entity is Directory;
          
          files.add({
            'name': name,
            'path': name,
            'isDirectory': isDir,
            'size': isDir ? 0 : stat.size,
            'modified': stat.modified.toIso8601String(),
          });
        }
      }
      
      if (_channel != null) {
        _channel!.sink.add(jsonEncode({
          "type": "initial_file_list_response",
          "files": files,
        }));
      }
    } catch (e) {
      print('Error sending initial file list: $e');
    }
  }

  @override
  void dispose() {
    disconnect();
    super.dispose();
  }
}