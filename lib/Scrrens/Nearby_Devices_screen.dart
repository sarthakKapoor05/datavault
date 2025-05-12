import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:datavault/Scrrens/file_transfer_screen.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:multicast_dns/multicast_dns.dart';
import 'package:path_provider/path_provider.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart'; // Add this package

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
      // Close existing connection if any
      if (_channel != null) {
        await _channel?.sink.close();
      }

      // Connect to local WebSocket server on port 8080
      final wsUrl = Uri.parse('ws://192.168.18.27:8080');
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
          "deviceName": "Tecno",
          "deviceId": _deviceId, // Include the stored deviceId if available
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
              action: SnackBarAction(
                label: 'Retry',
                onPressed: startScanning,
              ),
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
              action: SnackBarAction(
                label: 'Retry',
                onPressed: startScanning,
              ),
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

  final List<Map<String, String>> recentDevices = [
    {'name': 'Brandy', 'id': 'CP#25656835'},
    {'name': 'James', 'id': 'CP#25656835'},
    {'name': 'Anderson', 'id': 'CP#25656835'},
    {'name': 'sarthaak', 'id': 'CP#05656835'},
    {'name': 'bb', 'id': 'CP#25656805'},
    {'name': 'c', 'id': 'CP#25656805'},
    {'name': 'c', 'id': 'CP#25656805'},
    {'name': 'c', 'id': 'CP#25656805'},
    {'name': 'c', 'id': 'CP#25656805'},
    {'name': 'c', 'id': 'CP#25656805'},
    {'name': 'c', 'id': 'CP#25656805'},
    {'name': 'c', 'id': 'CP#25656805'},
    {'name': 'c', 'id': 'CP#25656805'},
    {'name': 'c', 'id': 'CP#25656805'},
    {'name': 'c', 'id': 'CP#25656805'},
    {'name': 'c', 'id': 'CP#25656805'},
    {'name': 'c', 'id': 'CP#25656805'},
    {'name': 'c', 'id': 'CP#25656805'},
    {'name': 'c', 'id': 'CP#25656805'},
    {'name': 'c', 'id': 'CP#25656805'},
    {'name': 'c', 'id': 'CP#25656805'},
    {'name': 'c', 'id': 'CP#25656805'},
    {'name': 'c', 'id': 'CP#25656805'},
    {'name': 'c', 'id': 'CP#25656805'},
    {'name': 'c', 'id': 'CP#25656805'},
  ];

  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 5),
      vsync: this,
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
  Future<void> _handleIncomingFile(List<int> fileData) async {
    try {
      // Get sender/client info from _expectedFile
      final senderId = _expectedFile?['fromId'] ?? 'unknown_sender';
      final fileName = _expectedFile?['filename'] ?? 'file.bin';

      // Get the temp directory
      final tempDir = await getTemporaryDirectory();

      // Create a subfolder for the sender/client
      final senderDir = Directory('${tempDir.path}/$senderId');
      if (!await senderDir.exists()) {
        await senderDir.create(recursive: true);
      }

      // Save the file in the sender's folder
      final file = File('${senderDir.path}/$fileName');
      await file.writeAsBytes(fileData);

      // Show success notification
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('File received from $senderId: $fileName')),
      );

      // Clear the expected file metadata
      setState(() {
        _expectedFile = null;
      });
    } catch (e) {
      print('Error saving received file: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to save file: $e')));
    }
  }

  // Add this method to send a file to another client
  Future<void> sendFileToClient(String targetId) async {
    FilePickerResult? result = await FilePicker.platform.pickFiles();

    if (result != null && result.files.single.path != null) {
      try {
        File file = File(result.files.single.path!);
        final fileBytes = await file.readAsBytes();
        final fileName = result.files.single.name;
        final fileSize = fileBytes.length;

        // Show sending notification
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Sending file: $fileName')));

        // Send metadata with targetId
        _channel!.sink.add(
          jsonEncode({
            "type": "file_metadata",
            "filename": fileName,
            "size": fileSize,
            "contentType": "application/octet-stream",
            "targetId": targetId,
          }),
        );

        // Listen for ready_for_file event from server
        bool fileSent = false;
        _channel!.stream.listen((message) {
          if (!fileSent && message is String) {
            final data = jsonDecode(message);
            if (data['type'] == 'ready_for_file') {
              // Send the actual file data
              _channel!.sink.add(fileBytes);
              fileSent = true;

              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text('File sent successfully')));
            }
          }
        });
      } catch (e) {
        print('Error sending file: $e');
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to send file: $e')));
      }
    }
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
            // Add connection status indicator bar
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
            // Retry connection button
            if (!_isConnected)
              Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Center(
                  child: ElevatedButton.icon(
                    icon: Icon(Icons.refresh),
                    label: Text("Retry Connection"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF50C2C9),
                      foregroundColor: Colors.white,
                    ),
                    onPressed: startScanning,
                  ),
                ),
              ),
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'Nearby Devices',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF50C2C9),
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  ...List.generate(4, (index) {
                    double radius = (index + 1) * 50;
                    return AnimatedBuilder(
                      animation: _controller,
                      builder: (context, child) {
                        double scale =
                            1.0 +
                            sin((_controller.value * 2 * pi) + index) * 0.05;
                        return Transform.scale(
                          scale: scale,
                          child: Container(
                            width: radius * 2,
                            height: radius * 2,
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: Theme.of(
                                  context,
                                ).colorScheme.secondary.withOpacity(0.3),
                                width: 1.5,
                              ),
                              shape: BoxShape.circle,
                            ),
                          ),
                        );
                      },
                    );
                  }),
                  GestureDetector(
                    onTap: () {
                      print('button pressed');
                      startScanning();
                    },
                    child: Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: _isConnected ? Colors.green : Color(0xFF50C2C9),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _isConnected ? Icons.wifi : Icons.sync,
                        color: Colors.white,
                        size: 30,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Display connected clients section
            if (_connectedClients.isNotEmpty)
              Expanded(
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
                    SizedBox(height: 8),
                    Flexible(
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _connectedClients.length,
                        itemBuilder: (context, index) {
                          return _connectedDeviceCard(_connectedClients[index]);
                        },
                      ),
                    ),
                  ],
                ),
              ),
            // Recent devices section
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'Recent',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  // Expanded(
                  //   child: ListView.builder(
                  //     scrollDirection: Axis.horizontal,
                  //     itemCount: recentDevices.length,
                  //     itemBuilder: (context, index) {
                  //       return _recentDeviceCard(recentDevices[index]);
                  //     },
                  //   ),
                  // ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Card for connected devices
  Widget _connectedDeviceCard(Map<String, dynamic> device) {
    // Don't show our own device in the list
    if (_deviceId != null && device['deviceId'] == _deviceId) {
      return SizedBox.shrink(); // Hide our own device
    }

    return Container(
      width: 330,
      height: 260, // Made taller for the additional button
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
        mainAxisSize: MainAxisSize.max,
        children: [
          Icon(Icons.devices, size: 30, color: Colors.green),
          const SizedBox(height: 8),
          Text(
            device['name'] ?? 'Unknown',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          Text(
            device['id'] ?? 'Unknown ID',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: Theme.of(context).colorScheme.secondary),
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: () async {
              // If already connected, disconnect first
              if (_isConnected && _channel != null) {
                await _channel!.sink.close();
                setState(() {
                  _isConnected = false;
                  _channel = null;
                });
              }

              // Reconnect
              final wsUrl = Uri.parse('ws://192.168.18.226:8080');
              _channel = WebSocketChannel.connect(wsUrl);

              // Recreate broadcast stream
              _broadcastStream = _channel!.stream.asBroadcastStream();

              setState(() {
                _isConnected = true;
              });

              // Register this device again (optional, but recommended)
              final prefs = await SharedPreferences.getInstance();
              final deviceName = prefs.getString('device_name') ?? "G 16";
              _channel!.sink.add(
                jsonEncode({
                  "type": "register_device",
                  "deviceName": deviceName,
                  "deviceId": _deviceId,
                }),
              );

              // Optionally request the current list of devices again
              _channel!.sink.add(jsonEncode({"type": "get_connected_devices"}));

              // Navigate to FileTransferScreen
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder:
                      (context) => FileTransferScreen(
                        deviceId: device['id'],
                        channel: _channel!,
                        broadcastStream: _broadcastStream,
                      ),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFF50C2C9),
              padding: EdgeInsets.symmetric(horizontal: 20),
            ),
            child: Text(
              'Connect',
              style: TextStyle(color: Theme.of(context).colorScheme.secondary),
            ),
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: () => sendFileToClient(device['id']),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber,
              padding: EdgeInsets.symmetric(horizontal: 20),
            ),
            child: Text(
              'Send File',
              style: TextStyle(color: Theme.of(context).colorScheme.secondary),
            ),
          ),
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
}
