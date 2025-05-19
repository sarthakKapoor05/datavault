import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:datavault/Scrrens/file_transfer_screen.dart';
import 'package:datavault/Scrrens/remote_files_screen.dart';
import 'package:datavault/Scrrens/settings_screen.dart';
import 'package:datavault/utils/storage_manager.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart'; // Add this package
import 'package:open_file/open_file.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'dart:typed_data';
import 'package:datavault/services/connection_service.dart';
import 'package:provider/provider.dart';
import 'package:path/path.dart' as path;
import 'package:intl/intl.dart';

enum FileTransferMode { idle, sending, receiving }

class ShareScreen extends StatefulWidget {
  @override
  _ShareScreenState createState() => _ShareScreenState();
}

class _ShareScreenState extends State<ShareScreen>
    with SingleTickerProviderStateMixin {
  // Add device identifier
  String? _deviceId;
  bool _isConnected = false;
  WebSocketChannel? _channel;
  Stream<dynamic>? _broadcastStream; // Add this to store the broadcast stream
  List<Map<String, dynamic>> _connectedClients = [];
  Map<String, dynamic>? _expectedFile;

  Timer? _pingTimer;

  void startScanning() async {
    try {
      final connectionService = Provider.of<ConnectionService>(
        context,
        listen: false,
      );
      await connectionService.connect('192.168.0.196');

      setState(() {
        _isConnected = connectionService.isConnected;
      });

      // Get broadcast stream from service
      _broadcastStream = connectionService.broadcastStream;
      _channel = connectionService.channel;

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

              // Add this to the _broadcastStream!.listen() handler in startScanning() method
              if (data['type'] == 'request_initial_file_list') {
                _sendInitialFileList();
              }

              // Also handle incoming device file updates
              if (data['type'] == 'device_files_update') {
                final deviceId = data['deviceId'];
                final deviceName = data['deviceName'];
                final files = data['files'];

                // Store the files for display
                setState(() {
                  // Find the device in connected clients or add it
                  bool found = false;
                  for (int i = 0; i < _connectedClients.length; i++) {
                    if (_connectedClients[i]['id'] == deviceId) {
                      _connectedClients[i]['files'] = files;
                      found = true;
                      break;
                    }
                  }

                  // If device wasn't in the list yet, this ensures we have its files
                  if (!found && deviceId != null && deviceName != null) {
                    _connectedClients.add({
                      'id': deviceId,
                      'name': deviceName,
                      'files': files,
                    });
                  }
                });
              }

              // Add this to your WebSocket message listener in startScanning method
              if (data['type'] == 'directory_listing_request') {
                final path = data['path'] ?? '';
                final requesterId = data['requesterId'];
                final recursive = data['recursive'] ?? false;

                if (requesterId != null) {
                  _handleDirectoryListingRequest(path, requesterId, recursive);
                }
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
      vsync: this, // "vsix" was misspelled - corrected to "vsync"
    )..repeat(); // Continuous waving

    // Load device ID at startup
    _loadDeviceId();
  }

  // Load stored device ID
  Future<void> _loadDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _deviceId = prefs.getString('device_id');
    });
  }

  // Save device ID for future sessions
  Future<void> _saveDeviceId(String deviceId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('device_id', deviceId);
    setState(() {
      _deviceId = deviceId;
    });
  }

  // Handle incoming file data
  // Update the _handleIncomingFile method to check storage limits
  Future<void> _handleIncomingFile(List<int> fileData) async {
    try {
      // Update transfer mode
      setState(() {
        _transferMode = FileTransferMode.receiving;
      });

      // Get sender/client info from _expectedFile
      final senderId = _expectedFile?['fromId'] ?? 'unknown_sender';
      final fileName = _expectedFile?['filename'] ?? 'file.bin';
      final fileSize = _expectedFile?['size'] ?? fileData.length;

      // Find client name from the connected clients list using the sender ID
      String senderName = 'Unknown Device';
      for (var client in _connectedClients) {
        if (client['id'] == senderId) {
          senderName = client['name'] ?? 'Unknown Device';
          break;
        }
      }

      // Check if the storage limit would be exceeded by this file
      final storageInfo = await _checkStorageLimits(fileSize);
      
      if (!storageInfo['isSpaceAvailable']) {
        // Show storage full alert
        _showStorageFullDialog(senderName, fileName, fileSize, storageInfo);
        
        // Reject the file transfer
        if (_channel != null) {
          _channel!.sink.add(jsonEncode({
            "type": "file_transfer_rejected",
            "reason": "storage_full",
            "targetId": senderId,
            "filename": fileName
          }));
        }
        
        // Reset transfer mode
        setState(() {
          _expectedFile = null;
          _transferMode = FileTransferMode.idle;
        });
        
        return;
      }

      // Use the default storage location from StorageManager with sender name instead of ID
      final decryptedBytes = decryptFileBytes(fileData);
      print('file data: $fileName');
      final file = await StorageManager.saveToDefaultStorage(
        fileName,
        Uint8List.fromList(decryptedBytes),
      );

      // Show success notification
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('File received from $senderName: $fileName'),
          action: SnackBarAction(
            label: 'Open',
            onPressed: () async {
              await OpenFile.open(file.path);
            },
          ),
        ),
      );

      // Clear the expected file metadata
      setState(() {
        _expectedFile = null;
        // Reset transfer mode after a delay
        Future.delayed(Duration(seconds: 2), () {
          if (mounted) {
            setState(() {
              _transferMode = FileTransferMode.idle;
            });
          }
        });
      });
    } catch (e) {
      print('Error saving received file: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to save file: $e')));

      setState(() {
        _transferMode = FileTransferMode.idle;
      });
    }
  }

  // Add this method to send a file to another client
  Future<void> sendFileToClient(String targetId) async {
    // Don't allow sending files to our own device
    if (_deviceId != null && targetId == _deviceId) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Cannot send files to your own device')),
      );
      return;
    }
    
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      allowMultiple: true, // Allow multiple file selection
    );

    if (result != null) {
      // Update UI to show progress
      setState(() {
        _transferMode = FileTransferMode.sending;
      });

      // Send each file
      for (var file in result.files) {
        if (file.path != null) {
          try {
            await _sendSingleFile(file, targetId);
          } catch (e) {
            print('Error sending file: $e');
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Failed to send ${file.name}: $e')),
            );
          }
        }
      }

      // Return to idle mode after sending
      setState(() {
        _transferMode = FileTransferMode.idle;
      });
    }
  }

  Future<void> _sendSingleFile(PlatformFile fileInfo, String targetId) async {
    File file = File(fileInfo.path!);
    final fileBytes = await file.readAsBytes();
    final encryptedBytes = encryptFileBytes(fileBytes);

    final fileName = fileInfo.name;

    // Send metadata with encrypted size
    _channel!.sink.add(
      jsonEncode({
        "type": "file_metadata",
        "filename": fileName,
        "size": encryptedBytes.length,
        "contentType": "application/octet-stream",
        "targetId": targetId,
      }),
    );

    // Wait for ready_for_file event from server
    Completer<void> sendCompleter = Completer<void>();

    StreamSubscription? subscription;
    subscription = _broadcastStream?.listen((message) {
      if (message is String) {
        final data = jsonDecode(message);
        if (data['type'] == 'ready_for_file') {
          // Send the actual encrypted file data
          _channel!.sink.add(encryptedBytes); // <--- FIXED

          Future.delayed(Duration(milliseconds: 500), () {
            if (!sendCompleter.isCompleted) {
              sendCompleter.complete();
            }
          });

          subscription?.cancel();
        }
      }
    });

    Future.delayed(Duration(seconds: 10), () {
      if (!sendCompleter.isCompleted) {
        sendCompleter.completeError('Timeout waiting for server response');
        subscription?.cancel();
      }
    });

    await sendCompleter.future;
  }

  // Start ping timer to keep connection alive and detect disconnection
  void _startPingTimer() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(Duration(seconds: 15), (timer) {
      if (_channel != null) {
        try {
          // Send a ping
          _channel!.sink.add(jsonEncode({"type": "ping"}));
        } catch (e) {
          // If ping fails, update connection status
          setState(() {
            _isConnected = false;
          });
          _pingTimer?.cancel();
        }
      }
    });
  }

  @override
  void dispose() {
    _pingTimer?.cancel();
    _controller.dispose();
    _channel?.sink.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      body: SafeArea(
        child: Column(
          children: [
            // Connection status indicator bar
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(vertical: 6, horizontal: 16),
              color: _isConnected ? Colors.green.shade700 : Colors.red.shade700,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _isConnected ? Icons.wifi : Icons.wifi_off,
                    color: Colors.white,
                    size: 16,
                  ),
                  SizedBox(width: 8),
                  Text(
                    _isConnected ? 'Connected to Server' : 'Disconnected',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            // Transfer mode indicator (only show when not idle)
            if (_transferMode != FileTransferMode.idle)
              Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(vertical: 4, horizontal: 16),
                color:
                    _transferMode == FileTransferMode.sending
                        ? Colors.amber.shade700
                        : Colors.green.shade700,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _transferMode == FileTransferMode.sending
                          ? Icons.upload
                          : Icons.download,
                      color: Colors.white,
                      size: 16,
                    ),
                    SizedBox(width: 8),
                    Text(
                      _transferMode == FileTransferMode.sending
                          ? 'Sending Mode'
                          : 'Receiving Mode',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Spacer(),
                    TextButton(
                      child: Text(
                        'Cancel',
                        style: TextStyle(color: Colors.white),
                      ),
                      onPressed: () {
                        setState(() {
                          _transferMode = FileTransferMode.idle;
                        });
                      },
                    ),
                  ],
                ),
              ),

            // Always show the Shared Files section - move it above the device scanning animation
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'Shared Files',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF50C2C9),
                ),
              ),
            ),
            
            // Show shared files from all clients in a scrollable container
            _isConnected && _connectedClients.isNotEmpty 
                ? Expanded(
                    child: ListView.builder(
                      itemCount: _connectedClients.length,
                      itemBuilder: (context, index) {
                        final client = _connectedClients[index];
                        
                        // Skip our own device
                        if (_deviceId != null && client['id'] == _deviceId) {
                          return SizedBox.shrink();
                        }
                        
                        // Get files from this client
                        final deviceName = client['name'] ?? 'Unknown Device';
                        final files = List<Map<String, dynamic>>.from(
                          client['files'] ?? [],
                        );
                        
                        if (files.isEmpty) {
                          return Card(
                            margin: EdgeInsets.only(bottom: 16, left: 16, right: 16),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Files from $deviceName',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  SizedBox(height: 16),
                                  Center(
                                    child: Padding(
                                      padding: const EdgeInsets.all(16.0),
                                      child: Text('No shared files available'),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }
                        
                        return Card(
                          margin: EdgeInsets.only(bottom: 16, left: 16, right: 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ListTile(
                                title: Text(
                                  'Files from $deviceName',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                trailing: TextButton(
                                  child: Text('View All'),
                                  onPressed: () {
                                    // Navigate to RemoteFilesScreen to see all files
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => RemoteFilesScreen(
                                          deviceId: client['id'],
                                          deviceName: deviceName,
                                          initialFiles: [],
                                          initialPath: '',
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                              ListView.builder(
                                shrinkWrap: true,
                                physics: NeverScrollableScrollPhysics(),
                                padding: EdgeInsets.symmetric(horizontal: 8),
                                itemCount: files.length > 5 ? 5 : files.length,
                                itemBuilder: (context, i) {
                                  final file = files[i];
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
                                          : '${_formatFileSize(file['size'] ?? 0)}',
                                    ),
                                    trailing: ElevatedButton(
                                      child: Text(
                                        isDir ? 'Browse' : 'Get File',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.white,  // White text for better contrast
                                        ),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: isDir ? Colors.amber[600] : Colors.blue[600], // Darker shades for better contrast
                                        foregroundColor: Colors.white,
                                        elevation: 2,
                                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                        minimumSize: Size(80, 32),
                                      ),
                                      onPressed: () {
                                        if (isDir) {
                                          // Navigate to the directory browser
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) => RemoteFilesScreen(
                                                deviceId: client['id'],
                                                deviceName: deviceName,
                                                initialFiles: [],
                                                initialPath: file['path'],
                                              ),
                                            ),
                                          );
                                        } else {
                                          // Download file
                                          _requestFileFromDevice(
                                            client['id'],
                                            file['path'],
                                          );
                                        }
                                      },
                                    ),
                                  );
                                },
                              ),
                              if (files.length > 5)
                                Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Center(
                                    child: TextButton(
                                      child: Text('Show more (${files.length - 5} more items)'),
                                      onPressed: () {
                                        // Navigate to RemoteFilesScreen to see all files
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => RemoteFilesScreen(
                                              deviceId: client['id'],
                                              deviceName: deviceName,
                                              initialFiles: files,
                                              initialPath: '',
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
                  )
                // Show "No connected devices" message when not connected or no clients
                : Expanded(
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.devices_other,
                            size: 64,
                            color: Colors.grey,
                          ),
                          SizedBox(height: 16),
                          Text(
                            _isConnected 
                                ? 'No connected devices found'
                                : 'Connect to see shared files',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey,
                            ),
                          ),
                          SizedBox(height: 16),
                          ElevatedButton.icon(
                            icon: Icon(Icons.refresh, color: Colors.white),
                            label: Text(
                              _isConnected ? 'Refresh' : 'Connect',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Color(0xFF3DABB5), // Slightly darker teal for better contrast
                              foregroundColor: Colors.white,
                              elevation: 2,
                              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            ),
                            onPressed: startScanning,
                          ),
                        ],
                      ),
                    ),
                  ),
            
            // Nearby Devices section
            Container(
              padding: EdgeInsets.all(16),
              alignment: Alignment.centerLeft,
              child: const Text(
                'Nearby Devices',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF50C2C9),
                ),
              ),
            ),
            
            // Your scanning animation
            Container(
              height: 120, // Reduced height from 200
              padding: EdgeInsets.symmetric(vertical: 10), // Add padding
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Reduce the number of circles to 3 instead of 4
                  ...List.generate(3, (index) {
                    double radius = (index + 1) * 30; // Smaller radius values
                    return AnimatedBuilder(
                      animation: _controller,
                      builder: (context, child) {
                        double scale = 1.0 + sin((_controller.value * 2 * pi) + index) * 0.05;
                        return Transform.scale(
                          scale: scale,
                          child: Container(
                            width: radius * 2,
                            height: radius * 2,
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: Theme.of(context).colorScheme.secondary.withOpacity(0.3),
                                width: 1.5,
                              ),
                              shape: BoxShape.circle,
                            ),
                          ),
                        );
                      },
                    );
                  }),
                  // Make a more compact connection button
                  GestureDetector(
                    onTap: () {
                      print('button pressed');
                      startScanning();
                    },
                    child: Container(
                      width: 50, // Reduced from 60
                      height: 50, // Reduced from 60
                      decoration: BoxDecoration(
                        color: _isConnected ? Colors.green : Color(0xFF50C2C9),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 4,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _isConnected ? Icons.wifi : Icons.sync,
                            color: Colors.white,
                            size: 24, // Reduced from 30
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Add status text below the button
                  Positioned(
                    bottom: 0,
                    child: Text(
                      _isConnected ? 'Connected' : 'Tap to connect',
                      style: TextStyle(
                        fontSize: 12,
                        color: _isConnected ? Colors.green : Colors.grey[600],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // Display connected clients section
            if (_connectedClients.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8.0, bottom: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'Connected Clients',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF50C2C9),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 160, // Reduce height to fit better in the layout
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        itemCount: _connectedClients.length,
                        itemBuilder: (context, index) {
                          return _connectedDeviceCard(_connectedClients[index]);
                        },
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  // Navigate to file transfer screen
  void navigateToFileTransfer(String deviceId) async {
    if (_channel == null || !_isConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please connect to the server first')),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => FileTransferScreen(
              deviceId: deviceId,
              channel: _channel!,
              broadcastStream: _broadcastStream,
            ),
      ),
    );
  }

  // Card for connected devices
  // Update the _connectedDeviceCard method to fix overflow issues
  Widget _connectedDeviceCard(Map<String, dynamic> device) {
    // Don't show our own device in the list
    final isOwnDevice = _deviceId != null && 
        (device['deviceId'] == _deviceId || device['id'] == _deviceId);
    
    if (isOwnDevice) {
      return SizedBox.shrink();
    }

    return Container(
      width: 180, // Reduced width from 330
      height: 180, // Reduced height to fit content better
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Theme.of(context).colorScheme.primary,
        boxShadow: [
          BoxShadow(color: Colors.black26, blurRadius: 5, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _transferMode == FileTransferMode.sending
                ? Icons.upload
                : Icons.devices,
            size: 28, // Reduced from 30
            color: _transferMode == FileTransferMode.sending
                ? Colors.amber
                : Colors.white,
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Text(
              device['name'] ?? 'Unknown',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white,
                fontSize: 14, // Reduced from default
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Text(
              device['id'] ?? 'Unknown ID',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.secondary,
                fontSize: 11, // Reduced size
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Show different buttons based on the transfer mode
          if (_transferMode == FileTransferMode.idle) ...[
            // Only show Send button with improved contrast
            ElevatedButton.icon(
              icon: Icon(Icons.upload, size: 14, color: Colors.black87),
              label: Text('Send', 
                style: TextStyle(
                  fontSize: 12, 
                  fontWeight: FontWeight.bold,
                  color: Colors.black87, // Darker text for better contrast on amber
                )
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber[400], // Brighter amber for better visibility
                foregroundColor: Colors.black87,
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                minimumSize: Size(100, 36),
                elevation: 2, // Add slight elevation for better visual distinction
              ),
              onPressed: () {
                setState(() {
                  _transferMode = FileTransferMode.sending;
                });
              },
            ),
          ],

          // Send mode UI
          if (_transferMode == FileTransferMode.sending) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Text(
                'Select files',
                style: TextStyle(
                  color: Colors.amber[300], // Brighter shade for better contrast
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            SizedBox(height: 8),
            SizedBox(
              height: 36,
              child: ElevatedButton(
                child: Text('Browse', 
                  style: TextStyle(
                    fontSize: 12, 
                    fontWeight: FontWeight.w500,
                    color: Colors.black87, // Dark text on amber background
                  )
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber[400], // Brighter amber
                  foregroundColor: Colors.black87,
                  elevation: 2,
                ),
                onPressed: () => sendFileToClient(device['id']),
              ),
            ),
            SizedBox(height: 4),
            SizedBox(
              height: 30,
              child: TextButton(
                child: Text('Cancel', 
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.red[300], // More visible cancel button
                    fontWeight: FontWeight.w500,
                  )
                ),
                onPressed: () {
                  setState(() {
                    _transferMode = FileTransferMode.idle;
                  });
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _recentDeviceCard(Map<String, String> device) {
    return Container(
      width: 130,
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Theme.of(context).colorScheme.primary,
        boxShadow: [
          BoxShadow(color: Colors.black26, blurRadius: 5, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.devices,
            size: 30,
            color: Theme.of(context).colorScheme.secondary,
          ),
          const SizedBox(height: 8),
          Text(
            device['name']!,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          Text(
            device['id']!,
            style: TextStyle(color: Theme.of(context).colorScheme.secondary),
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: () {},
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFF50C2C9),
              padding: EdgeInsets.symmetric(horizontal: 20),
            ),
            child: Text(
              'Connect',
              style: TextStyle(color: Theme.of(context).colorScheme.secondary),
            ),
          ),
        ],
      ),
    );
  }

  // New method to send file list from storage
  Future<void> _sendInitialFileList() async {
    try {
      final storagePath = await StorageManager.getDefaultStoragePath();
      final directory = Directory(storagePath);
      List<Map<String, dynamic>> files = [];

      if (await directory.exists()) {
        final entities = await directory.list().toList();

        for (var entity in entities) {
          try {
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
          } catch (e) {
            print('Error processing file $entity: $e');
          }
        }
      }

      // Send the file list to the server
      if (_channel != null) {
        print('Sending initial file list: ${files.length} items');
        _channel!.sink.add(
          jsonEncode({"type": "initial_file_list_response", "files": files}),
        );
      }
    } catch (e) {
      print('Error sending initial file list: $e');
    }
  }

  // Add file icon helper
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

  // Add file size formatter
  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024)
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  // Add method to request file from another device
  void _requestFileFromDevice(String deviceId, String filePath) {
    // Don't allow requesting files from our own device
    if (_deviceId != null && deviceId == _deviceId) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Cannot request files from your own device')),
      );
      return;
    }
    
    // Get the filename from the path
    final fileName = path.basename(filePath);

    // Get the file details from the list
    Map<String, dynamic>? fileDetails;
    for (final device in _connectedClients) {
      if (device['id'] == deviceId && device['files'] != null) {
        for (final file in device['files']) {
          if (file['path'] == filePath) {
            fileDetails = Map<String, dynamic>.from(file);
            break;
          }
        }
      }
    }

    if (fileDetails == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('File details not found')));
      return;
    }

    // Format the date for better readability
    String formattedDate = "";
    if (fileDetails['modified'] != null) {
      try {
        final DateTime modifiedDate = DateTime.parse(fileDetails['modified'].toString());
        formattedDate = DateFormat('MMM d, yyyy h:mm a').format(modifiedDate);
      } catch (e) {
        formattedDate = fileDetails['modified'].toString();
      }
    }

    // Show file details dialog with improved contrast
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        titlePadding: EdgeInsets.zero,
        title: Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Color(0xFF50C2C9),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(4),
              topRight: Radius.circular(4),
            ),
          ),
          child: Row(
            children: [
              Icon(_getFileIcon(fileName), color: Colors.white, size: 24),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'File Details',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                children: [
                  Icon(_getFileIcon(fileName), color: Color(0xFF3D88C3), size: 36),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          fileName,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.black87,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 4),
                        Text(
                          _formatFileSize(fileDetails?['size'] ?? 0),
                          style: TextStyle(
                            color: Colors.black54,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 16),
            _buildDetailRow(
              'Path',
              filePath,
              iconData: Icons.folder_outlined,
              iconColor: Colors.amber[700] ?? Colors.amber, // Provide fallback color
            ),
            if (formattedDate.isNotEmpty)
              _buildDetailRow(
                'Modified',
                formattedDate,
                iconData: Icons.access_time,
                iconColor: Colors.green[700] ?? Colors.green, // Provide fallback color
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: Colors.grey[700],
            ),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // Start the download
              _startDownload(deviceId, filePath, fileName);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFF50C2C9),
              foregroundColor: Colors.white,
              elevation: 2,
            ),
            child: Text('Download'),
          ),
        ],
      ),
    );
  }

  // Updated _buildDetailRow method with null safety
  Widget _buildDetailRow(String title, String value, {IconData? iconData, required Color iconColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (iconData != null) ...[
            Icon(iconData, size: 18, color: iconColor),
            SizedBox(width: 8),
          ],
          SizedBox(
            width: 70,
            child: Text(
              '$title:',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: Colors.black87,
                height: 1.3,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 3,
            ),
          ),
        ],
      ),
    );
  }

  // Add this method to your _ShareScreenState class

  Future<void> _handleDirectoryListingRequest(
    String requestedPath,
    String requesterId,
    bool recursive,
  ) async {
    try {
      final storagePath = await StorageManager.getDefaultStoragePath();
      List<Map<String, dynamic>> files = [];

      // Sanitize requested path
      final safePath = requestedPath.replaceAll('..', '').replaceAll('\\', '/');

      // Construct the full path to the requested directory
      final fullPath = path.join(storagePath, safePath);
      final directory = Directory(fullPath);

      if (await directory.exists()) {
        // Recursive mode fetches all files and maintains proper paths
        if (recursive) {
          await _collectFilesRecursively(
            directory,
            files,
            storagePath,
            safePath,
          );
        } else {
          // Regular mode just gets immediate files
          final entities = await directory.list().toList();

          for (var entity in entities) {
            try {
              final stat = await entity.stat();
              final name = path.basename(entity.path);
              final isDir = entity is Directory;

              files.add({
                'name': name,
                'path': safePath.isEmpty ? name : '$safePath/$name',
                'isDirectory': isDir,
                'size': isDir ? 0 : stat.size,
                'modified': stat.modified.toIso8601String(),
              });
            } catch (e) {
              print('Error processing file $entity: $e');
            }
          }
        }

        // Sort files: directories first, then alphabetically
        files.sort((a, b) {
          if (a['isDirectory'] == true && b['isDirectory'] != true) return -1;
          if (a['isDirectory'] != true && b['isDirectory'] == true) return 1;
          return (a['name'] as String).compareTo(b['name'] as String);
        });
      }

      // Send response back to server
      if (_channel != null) {
        _channel!.sink.add(
          jsonEncode({
            "type": "file_list_response",
            "path": safePath,
            "files": files,
            "requesterId": requesterId,
          }),
        );
      }
    } catch (e) {
      print('Error handling directory listing request: $e');
      if (_channel != null) {
        _channel!.sink.add(
          jsonEncode({
            "type": "file_list_response",
            "path": requestedPath,
            "files": [],
            "error": e.toString(),
            "requesterId": requesterId,
          }),
        );
      }
    }
  }

  // Helper method to collect files recursively
  Future<void> _collectFilesRecursively(
    Directory directory,
    List<Map<String, dynamic>> files,
    String basePath,
    String currentRelativePath,
  ) async {
    if (!await directory.exists()) return;

    try {
      final entities = await directory.list().toList();

      for (var entity in entities) {
        try {
          final stat = await entity.stat();
          final name = path.basename(entity.path);
          final isDir = entity is Directory;
          final relativePath =
              currentRelativePath.isEmpty ? name : '$currentRelativePath/$name';

          files.add({
            'name': name,
            'path': relativePath,
            'fullPath': entity.path,
            'isDirectory': isDir,
            'size': isDir ? 0 : stat.size,
            'modified': stat.modified.toIso8601String(),
            'parentPath': currentRelativePath,
          });

          // Recursively process subdirectories
          if (isDir) {
            await _collectFilesRecursively(
              Directory(entity.path),
              files,
              basePath,
              relativePath,
            );
          }
        } catch (e) {
          print('Error processing file $entity during recursive scan: $e');
        }
      }
    } catch (e) {
      print('Error listing directory $directory: $e');
    }
  }

  // Add method to check storage limits
  Future<Map<String, dynamic>> _checkStorageLimits(int incomingFileSize) async {
    try {
      // Get the current storage path
      final storagePath = await StorageManager.getDefaultStoragePath();
      final storageDir = Directory(storagePath);
      
      // Get the max storage size limit
      final maxStorageSize = await StorageManager.getMaxStorageSize();
      
      // Calculate current usage
      int currentUsage = 0;
      if (await storageDir.exists()) {
        final entities = await storageDir.list(recursive: true).toList();
        for (final entity in entities) {
          if (entity is File) {
            final stat = await entity.stat();
            currentUsage += stat.size;
          }
        }
      }
      
      // Check if adding this file would exceed the limit
      final isSpaceAvailable = (currentUsage + incomingFileSize) <= maxStorageSize;
      final remainingSpace = maxStorageSize - currentUsage;
      
      return {
        'isSpaceAvailable': isSpaceAvailable,
        'currentUsage': currentUsage,
        'maxStorageSize': maxStorageSize,
        'remainingSpace': remainingSpace,
        'requiredSpace': incomingFileSize
      };
    } catch (e) {
      print('Error checking storage limits: $e');
      // In case of error, default to allowing the transfer
      return {
        'isSpaceAvailable': true,
        'error': e.toString()
      };
    }
  }

  // Add method to show storage full dialog
  void _showStorageFullDialog(String senderName, String fileName, int fileSize, Map<String, dynamic> storageInfo) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.storage, color: Colors.red),
            SizedBox(width: 10),
            Expanded(child: Text('Storage Full')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Cannot receive file from $senderName due to insufficient storage space.',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            Text('File: $fileName'),
            Text('Size: ${_formatFileSize(fileSize)}'),
            SizedBox(height: 16),
            _buildStorageProgressBar(
              storageInfo['currentUsage'],
              storageInfo['maxStorageSize'],
            ),
            SizedBox(height: 8),
            Text('Currently used: ${_formatFileSize(storageInfo['currentUsage'])}'),
            Text('Remaining space: ${_formatFileSize(storageInfo['remainingSpace'])}'),
            Text('Required space: ${_formatFileSize(storageInfo['requiredSpace'])}'),
            SizedBox(height: 16),
            Text(
              'Please free up some space or increase your storage limit in Settings.',
              style: TextStyle(fontStyle: FontStyle.italic),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // Open settings screen to adjust storage limit
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => SettingsScreen()),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFF50C2C9),
            ),
            child: Text('Go to Settings'),
          ),
        ],
      ),
    );
  }

  // Add helper method to build storage progress bar
  Widget _buildStorageProgressBar(int used, int total) {
    final double percentage = total > 0 ? used / total : 0;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Storage Usage: ${(percentage * 100).toStringAsFixed(1)}%',
          style: TextStyle(fontWeight: FontWeight.w500),
        ),
        SizedBox(height: 4),
        LinearProgressIndicator(
          value: percentage,
          backgroundColor: Colors.grey[300],
          valueColor: AlwaysStoppedAnimation<Color>(
            percentage > 0.9 ? Colors.red : 
            percentage > 0.7 ? Colors.orange : 
            Colors.green,
          ),
          minHeight: 8,
          borderRadius: BorderRadius.circular(4),
        ),
      ],
    );
  }

  // Add this method to your _ShareScreenState class
  Future<void> _startDownload(String deviceId, String filePath, String fileName) async {
    try {
      setState(() {
        _transferMode = FileTransferMode.receiving;
      });
      
      // Show a snackbar to indicate download started
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Text('Requesting file: $fileName from device'),
              ),
            ],
          ),
          duration: Duration(seconds: 5),
        ),
      );
      
      // Send request to server
      if (_channel != null) {
        _channel!.sink.add(jsonEncode({
          "type": "request_file",
          "targetId": deviceId,
          "filename": filePath,
        }));
        
        // File data will be received through the broadcast stream listener
        // that already exists, which calls _handleIncomingFile
      }
    } catch (e) {
      print('Error requesting file: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error requesting file: $e')),
      );
      setState(() {
        _transferMode = FileTransferMode.idle;
      });
    }
  }
}

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
