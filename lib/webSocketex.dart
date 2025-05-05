import 'package:flutter/material.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class WebSocketExample extends StatefulWidget {
  @override
  _WebSocketExampleState createState() => _WebSocketExampleState();
}

class _WebSocketExampleState extends State<WebSocketExample> {
  final TextEditingController _controller = TextEditingController();

  final WebSocketChannel channel = IOWebSocketChannel.connect(
    'ws://localhost:8080', // use IP if real device
  );

  String receivedMessage = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[200], // ✅ Light clean background
      appBar: AppBar(
        title: const Text('Flutter WebSocket'),
        backgroundColor: Colors.blueAccent,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            StreamBuilder(
              stream: channel.stream,
              builder: (context, snapshot) {
                if (snapshot.hasData) {
                  receivedMessage = snapshot.data.toString();
                  print(snapshot.data);
                }
                return Container(
                  padding: const EdgeInsets.all(20),
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 8,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      receivedMessage.isNotEmpty
                          ? receivedMessage
                          : 'No message received yet.',
                      style: const TextStyle(fontSize: 18),
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              },
            ),
            TextField(
              controller: _controller,
              decoration: const InputDecoration(
                labelText: 'Send a message',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                if (_controller.text.isNotEmpty) {
                  channel.sink.add(_controller.text);
                  _controller.clear();
                }
              },
              child: const Text('Send'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    channel.sink.close();
    super.dispose();
  }
}
