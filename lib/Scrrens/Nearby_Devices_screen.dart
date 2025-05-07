import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:multicast_dns/multicast_dns.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'dart:convert';

class ShareScreen extends StatefulWidget {
  @override
  _ShareScreenState createState() => _ShareScreenState();
}

class _ShareScreenState extends State<ShareScreen>
    with SingleTickerProviderStateMixin {
  // WebSocket connection instance
  WebSocketChannel? _channel;
  bool _isConnected = false;
  List<Map<String, dynamic>> _connectedClients = [];

  void startScanning() async {
    try {
      // Close existing connection if any
      if (_channel != null) {
        await _channel?.sink.close();
      }
      
      // Connect to local WebSocket server on port 8080
      final wsUrl = Uri.parse('ws://localhost:8080');
      _channel = WebSocketChannel.connect(wsUrl);
      
      setState(() {
        _isConnected = true;
      });
      
      // Listen for messages from the server
      _channel!.stream.listen((message) {
        // Parse the incoming message (assuming JSON format for client list)
        try {
          final data = jsonDecode(message);
          
          if (data is List) {
            setState(() {
              _connectedClients = List<Map<String, dynamic>>.from(
                data.map((client) => Map<String, dynamic>.from(client))
              );
            });
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
      },
      onDone: () {
        print('WebSocket connection closed');
        setState(() {
          _isConnected = false;
        });
      });
      
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
  ];

  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 5),
      vsync: this,
    )..repeat(); // Continuous waving
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      body: SafeArea(
        child: Column(
          children: [
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
                        size: 30
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
                    Expanded(
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
                  Expanded(
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: recentDevices.length,
                      itemBuilder: (context, index) {
                        return _recentDeviceCard(recentDevices[index]);
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

  // Card for connected devices
  Widget _connectedDeviceCard(Map<String, dynamic> device) {
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
            color: Colors.green,
          ),
          const SizedBox(height: 8),
          Text(
            device['name'] ?? 'Unknown',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          Text(
            device['id'] ?? 'Unknown ID',
            style: TextStyle(color: Theme.of(context).colorScheme.secondary),
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: () {
              // Handle connection to this specific client
              // You might want to send a message to the server indicating a connection request
              if (_channel != null) {
                _channel!.sink.add(jsonEncode({
                  'action': 'connect',
                  'targetId': device['id']
                }));
              }
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
