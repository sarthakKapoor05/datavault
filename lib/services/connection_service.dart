import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  @override
  void dispose() {
    disconnect();
    super.dispose();
  }
}