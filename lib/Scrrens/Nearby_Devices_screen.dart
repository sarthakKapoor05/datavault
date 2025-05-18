import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:datavault/Scrrens/file_transfer_screen.dart';
import 'package:datavault/Scrrens/remote_file_browser.dart';
import 'package:datavault/utils/storage_manager.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart'; // Add this package
import 'package:open_file/open_file.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'dart:typed_data';
import 'package:datavault/utils/event_bus.dart';
import 'package:path/path.dart' as path;

enum FileTransferMode { idle, sending, receiving }

class ShareScreen extends StatefulWidget {
  @override
  _ShareScreenState createState() => _ShareScreenState();
}

class _ShareScreenState extends State<ShareScreen>
    with SingleTickerProviderStateMixin {
  // Add device identifier
  String? _deviceId;
  String? deviceName;
  bool _isConnected = false;
  WebSocketChannel? _channel;
  Stream<dynamic>? _broadcastStream; // Add this to store the broadcast stream
  List<Map<String, dynamic>> _connectedClients = [];
  Map<String, dynamic>? _expectedFile;

  Timer? _pingTimer;

  void startScanning() async {
    try {
      // Close existing connection if any
      if (_channel != null) {
        await _channel?.sink.close();
      }

      // Connect to local WebSocket server on port 8080
      final wsUrl = Uri.parse('ws://192.168.18.226:8080');
      _channel = WebSocketChannel.connect(wsUrl);

      // Create a broadcast stream that can be listened to multiple times
      _broadcastStream = _channel!.stream.asBroadcastStream();

      setState(() {
        _isConnected = true;
      });
      _startPingTimer(); // Start the ping timer

      // Register this device WITH the stored deviceId
      _channel!.sink.add(
        jsonEncode({
          "type": "register_device",
          "deviceName": deviceName ?? Platform.localHostname,
          "deviceId": _deviceId
          }),
      );

      // Request the current list of devices
      _channel!.sink.add(jsonEncode({"type": "get_connected_devices"}));

      // Listen for messages from the server using our broadcast stream
      _broadcastStream!.listen(
        (message) {
          try {
            if (message is String) {
              final data = jsonDecode(message);

              // Handle device registration confirmation
              if (data['type'] == 'device_registered') {
                // Store the deviceId for future reconnections
                _saveDeviceId(data['deviceId']);
              }

              // Handle connected devices list
              if (data['type'] == 'connected_devices') {
                final devices = data['devices'];
                if (devices is List) {
                  setState(() {
                    _connectedClients = List<Map<String, dynamic>>.from(
                      devices.map(
                        (client) => Map<String, dynamic>.from(client),
                      ),
                    );
                  });
                }
              }

              // Handle file metadata message
              if (data['type'] == 'file_metadata') {
                // Store metadata for the incoming file
                _expectedFile = {
                  'filename': data['filename'],
                  'size': data['size'],
                  'fromId': data['fromId'],
                };

                // Show notification about incoming file
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Receiving file: ${data['filename']}'),
                  ),
                );
              }

              // Handle file list response
              if (data['type'] == 'file_list') {
                _handleFileListResponse(data);
              }

              // Handle file list request
              if (data['type'] == 'request_file_list') {
                _handleFileListRequest(data);
              }
              
              // Handle specific file request
              if (data['type'] == 'request_file') {
                _handleSpecificFileRequest(data);
              }
            }
            // Handle binary data (file content)
            else if (message is List<int> && _expectedFile != null) {
              _handleIncomingFile(message);
            }
          } catch (e) {
            print('Error parsing WebSocket message: $e');
          }
        },
        onError: (error) {
          print('WebSocket error: $error');
          setState(() {
            _isConnected = false;
          });
          // Show reconnection snackbar
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Connection lost. Please reconnect.'),
              action: SnackBarAction(label: 'Retry', onPressed: startScanning),
            ),
          );
        },
        onDone: () {
          print('WebSocket connection closed');
          setState(() {
            _isConnected = false;
          });
          // Show reconnection snackbar
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Connection closed. Please reconnect.'),
              action: SnackBarAction(label: 'Retry', onPressed: startScanning),
            ),
          );
        },
      );
    } catch (e) {
      print('Failed to connect to WebSocket server: $e');
      setState(() {
        _isConnected = false;
      });
    }
  }

  final List<Map<String, String>> recentDevices = [];

  late AnimationController _controller;

  // Add to your _ShareScreenState class
  FileTransferMode _transferMode = FileTransferMode.idle;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 5),
      vsync: this,
    );
    // Load device ID and name on startup
    _loadDeviceId();
    _loadDeviceName();
  }

  @override
  void dispose() {
    _channel?.sink.close();
    _pingTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  // Load device ID from storage
  void _loadDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _deviceId = prefs.getString('deviceId');
    });
  }

  // Save device ID to storage
  void _saveDeviceId(String deviceId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('deviceId', deviceId);
    setState(() {
      _deviceId = deviceId;
    });
  }

  // Load device name from storage
  void _loadDeviceName() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      deviceName = prefs.getString('deviceName') ?? Platform.localHostname;
    });
  }

  // Save device name to storage
  void _saveDeviceName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('deviceName', name);
  }

  // Start the ping timer to keep the connection alive
  void _startPingTimer() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(Duration(seconds: 10), (timer) {
      if (_channel != null && _isConnected) {
        _channel!.sink.add(jsonEncode({"type": "ping"}));
      }
    });
  }

  // Method to pick and send file to the selected device
  // void _pickAndSendFile(String? deviceId) async {
  //   if (deviceId == null) return;

  //   // Request file from the user
  //   final result = await FilePicker.platform.pickFiles(
  //     allowMultiple: false,
  //     type: FileType.any,
  //   );

  //   if (result != null && result.files.isNotEmpty) {
  //     final filePath = result.files.first.path;
  //     final fileName = result.files.first.name;

  //     if (filePath != null) {
  //       // Encrypt the file before sending
  //       final encryptedFile = await _encryptFile(filePath);

  //       // Send the file to the selected device
  //       _sendFile(deviceId, encryptedFile, fileName);
  //     }
  //   }
  // }

  // Method to encrypt the file
  Future<List<int>> _encryptFile(String filePath) async {
    // Generate a random key and IV for encryption
    final key = encrypt.Key.fromLength(32);
    final iv = encrypt.IV.fromLength(16);

    // Read the file data
    final fileData = await File(filePath).readAsBytes();

    // Encrypt the file data
    final encrypter = encrypt.Encrypter(encrypt.AES(key));
    final encryptedData = encrypter.encryptBytes(fileData, iv: iv);

    // TODO: Store the key and IV securely, and send them to the recipient device

    return encryptedData.bytes;
  }

  // Method to send the file to the selected device
  void _sendFile(String deviceId, List<int> fileData, String fileName) {
    if (_channel != null && _isConnected) {
      // Send file metadata first
      _channel!.sink.add(jsonEncode({
        "type": "file_metadata",
        "deviceId": deviceId,
        "filename": fileName,
        "size": fileData.length,
      }));

      // Send the actual file data
      _channel!.sink.add(fileData);
    }
  }

  // Method to handle incoming file data
  void _handleIncomingFile(List<int> fileData) async {
    // TODO: Implement file handling logic (e.g., save to device, decrypt, etc.)
    print('Received file data: ${fileData.length} bytes');

    // For demonstration, we'll just show the file data as a notification
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Received file: ${_expectedFile!['filename']} (${fileData.length} bytes)'),
      ),
    );

    // Reset expected file info
    setState(() {
      _expectedFile = null;
    });
  }

  // Method to handle file list response from the server
  void _handleFileListResponse(Map<String, dynamic> data) {
    final List<dynamic> files = data['files'];
    final String sourceId = data['sourceId'];
    final String sourcePath = data['sourcePath'] ?? '';
    final String sourceName = data['sourceName'] ?? 'Unknown Device';
    
    // Navigate to the remote file browser screen
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RemoteFileBrowserScreen(
          clientId: sourceId,
          clientName: sourceName,
          initialFiles: files.map<Map<String, dynamic>>((file) => 
            Map<String, dynamic>.from(file)
          ).toList(),
          initialPath: sourcePath,
          onRequestPath: (String path) => _requestRemoteFileList(sourceId, path),
          onRequestFile: (String path) => _requestRemoteFile(sourceId, path),
          websocketChannel: _channel!,
        ),
      ),
    );
  }

  // Method to handle file list request from the server
  void _handleFileListRequest(Map<String, dynamic> data) {
    // TODO: Implement file list request handling logic
    print('File list requested by: ${data['fromId']}');
  }

  // Method to handle specific file request from the server
  void _handleSpecificFileRequest(Map<String, dynamic> data) {
    // TODO: Implement specific file request handling logic
    print('Specific file requested: ${data['filename']}');
  }

  // Method to request file list
  Future<void> _requestRemoteFileList(String targetId, [String? path]) async {
    if (_channel == null || !_isConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please connect to the server first')),
      );
      return;
    }
    
    _channel!.sink.add(jsonEncode({
      "type": "list_files",
      "targetId": targetId,
      "path": path
    }));
  }

  // Add your file encryption method
  List<int> encryptFileBytes(List<int> bytes) {
    // You can implement encryption here if needed
    return bytes; // Return unencrypted for now
  }

  // Pick and send a file
  Future<void> _pickAndSendFile(String targetDeviceId) async {
    try {
      final result = await FilePicker.platform.pickFiles();
      if (result != null) {
        final file = File(result.files.single.path!);
        final fileName = file.path.split('/').last;
        
        setState(() {
          _transferMode = FileTransferMode.sending;
        });
        
        // Read file
        final bytes = await file.readAsBytes();
        
        // Encrypt file data
        final encryptedBytes = encryptFileBytes(bytes);
        
        // Send file metadata
        _channel!.sink.add(jsonEncode({
          "type": "file_metadata",
          "filename": fileName,
          "size": encryptedBytes.length,
          "contentType": "application/octet-stream",
          "targetId": targetDeviceId,
          "fromId": _deviceId,
        }));
        
        // Small delay to ensure metadata is processed
        await Future.delayed(Duration(milliseconds: 100));
        
        // Send file content
        _channel!.sink.add(encryptedBytes);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('File sent: $fileName')),
        );
        
        setState(() {
          _transferMode = FileTransferMode.idle;
        });
      }
    } catch (e) {
      print('Error picking or sending file: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sending file: $e')),
      );
      setState(() {
        _transferMode = FileTransferMode.idle;
      });
    }
  }

  // Add this method to request a specific file from remote device
  Future<void> _requestRemoteFile(String targetId, String filePath) async {
    if (_channel == null || !_isConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please connect to the server first')),
      );
      return;
    }
    
    // Extract filename from path
    final fileName = path.basename(filePath);
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Requesting file: $fileName')),
    );
    
    setState(() {
      _transferMode = FileTransferMode.receiving;
    });
    
    _channel!.sink.add(jsonEncode({
      "type": "request_file",
      "targetId": targetId,
      "path": filePath,
      "filename": fileName,
      "requesterId": _deviceId
    }));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: AppBar(
        title: Text('Nearby Devices'),
        actions: [
          // Connection status indicator
          Container(
            padding: EdgeInsets.all(8),
            child: _isConnected
                ? Row(
                    children: [
                      Icon(Icons.wifi, color: Colors.green),
                      SizedBox(width: 4),
                      Text('Connected', style: TextStyle(color: Colors.green)),
                    ],
                  )
                : TextButton.icon(
                    icon: Icon(Icons.wifi_off, color: Colors.red),
                    label: Text('Connect', style: TextStyle(color: Colors.red)),
                    onPressed: startScanning,
                  ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Device name section
            Container(
              padding: EdgeInsets.all(16),
              color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
              child: Row(
                children: [
                  Icon(Icons.devices, size: 24),
                  SizedBox(width: 16),
                  Expanded(
                    child: InkWell(
                      onTap: _showChangeDeviceNameDialog,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Your Device Name',
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context).colorScheme.secondary.withOpacity(0.8),
                            ),
                          ),
                          SizedBox(height: 4),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  deviceName ?? Platform.localHostname,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Icon(Icons.edit, size: 16),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Transfer status indicator (when active)
            if (_transferMode != FileTransferMode.idle)
              Container(
                padding: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                color: _transferMode == FileTransferMode.sending
                    ? Colors.blue.withOpacity(0.2)
                    : Colors.green.withOpacity(0.2),
                child: Row(
                  children: [
                    Icon(
                      _transferMode == FileTransferMode.sending
                          ? Icons.upload
                          : Icons.download,
                      size: 16,
                      color: _transferMode == FileTransferMode.sending
                          ? Colors.blue
                          : Colors.green,
                    ),
                    SizedBox(width: 8),
                    Text(
                      _transferMode == FileTransferMode.sending
                          ? 'Sending file...'
                          : 'Receiving file...',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _transferMode == FileTransferMode.sending
                            ? Colors.blue
                            : Colors.green,
                      ),
                    ),
                    Spacer(),
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: _transferMode == FileTransferMode.sending
                            ? Colors.blue
                            : Colors.green,
                      ),
                    ),
                  ],
                ),
              ),

            // Connected devices section
            Expanded(
              child: _isConnected
                  ? _connectedClients.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.devices_other, size: 64, color: Colors.grey),
                              SizedBox(height: 16),
                              Text(
                                'No devices found nearby',
                                style: TextStyle(fontSize: 16, color: Colors.grey),
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Make sure other devices are connected to the same network',
                                style: TextStyle(fontSize: 12, color: Colors.grey),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        )
                      : ListView(
                          padding: EdgeInsets.all(16),
                          children: [
                            Text(
                              'Nearby Devices',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 8),
                            ...List.generate(
                              _connectedClients.length,
                              (index) => _connectedDeviceCard(_connectedClients[index]),
                            ),
                          ],
                        )
                  : Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.wifi_off, size: 64, color: Colors.grey),
                          SizedBox(height: 16),
                          Text(
                            'Not connected',
                            style: TextStyle(fontSize: 18, color: Colors.grey),
                          ),
                          SizedBox(height: 24),
                          ElevatedButton.icon(
                            icon: Icon(Icons.wifi),
                            label: Text('Connect to Network'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Color(0xFF50C2C9),
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            ),
                            onPressed: startScanning,
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: _isConnected
          ? FloatingActionButton(
              onPressed: _showDeviceSelector,
              backgroundColor: Color(0xFF50C2C9),
              child: Icon(Icons.send),
              tooltip: 'Send File',
            )
          : null,
    );
  }

  // Method to show device selection dialog
  void _showDeviceSelector() {
    if (_connectedClients.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No devices available to send files to')),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.background,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Select a device to send file to',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          Divider(height: 1),
          Expanded(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _connectedClients.length,
              itemBuilder: (context, index) {
                final client = _connectedClients[index];
                if (client['deviceId'] == _deviceId) {
                  return SizedBox.shrink(); // Don't show own device
                }
                return ListTile(
                  leading: Icon(Icons.devices, color: Colors.blue),
                  title: Text(client['deviceName'] ?? 'Unknown Device'),
                  subtitle: Text(client['deviceId'] ?? ''),
                  onTap: () {
                    Navigator.pop(context);
                    _pickAndSendFile(client['deviceId']);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // Add this method to build connected device cards
  Widget _connectedDeviceCard(Map<String, dynamic> device) {
    // Don't show our own device in the list
    if (_deviceId != null && device['deviceId'] == _deviceId) {
      return SizedBox.shrink(); // Hide our own device
    }

    return Card(
      margin: EdgeInsets.symmetric(vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.devices, size: 24, color: Colors.blue),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        device['deviceName'] ?? 'Unknown Device',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'ID: ${device['deviceId']?.substring(0, 8) ?? 'Unknown'}...',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                ElevatedButton.icon(
                  icon: Icon(Icons.upload, size: 16),
                  label: Text('Send File'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF50C2C9),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () => _pickAndSendFile(device['deviceId']),
                ),
                ElevatedButton.icon(
                  icon: Icon(Icons.folder_open, size: 16),
                  label: Text('Browse Files'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () => _requestRemoteFileList(device['deviceId']),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Show dialog to change device name
  void _showChangeDeviceNameDialog() {
    final nameController = TextEditingController(text: deviceName);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Change Device Name'),
        content: TextField(
          controller: nameController,
          decoration: InputDecoration(
            labelText: 'Device Name',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            child: Text('Cancel'),
            onPressed: () => Navigator.pop(context),
          ),
          ElevatedButton(
            child: Text('Save'),
            onPressed: () {
              final newName = nameController.text.trim();
              if (newName.isNotEmpty) {
                setState(() {
                  deviceName = newName;
                });
                // Broadcast device name change
                eventBus.fire(DeviceNameChangedEvent(newName));
                // Save to preferences
                _saveDeviceName(newName);
                // Update on server
                if (_channel != null && _isConnected) {
                  _channel!.sink.add(jsonEncode({
                    "type": "update_device_name",
                    "deviceId": _deviceId,
                    "deviceName": newName,
                  }));
                }
              }
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }
}
