import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class SendMessagePage extends StatefulWidget {
  const SendMessagePage({super.key});

  @override
  State<SendMessagePage> createState() => _SendMessagePageState();
}

class _SendMessagePageState extends State<SendMessagePage> {
  final TextEditingController textEditingController = TextEditingController();
  final WebSocketChannel myChannel = WebSocketChannel.connect(
    Uri.parse('ws://echo.websocket.org'), 
  ); // Replace with your WebSocket URL

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Send Message'),
        backgroundColor: Colors.blueGrey,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Form(
              child: TextField(
                controller: textEditingController,
                decoration: const InputDecoration(
                  labelText: 'Enter your message',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(height: 16),
            StreamBuilder(
              stream: myChannel.stream,
              builder: (context, snapshot) {
                if (snapshot.hasData) {
                  return Text('Received: ${snapshot.data}');
                } else if (snapshot.hasError) {
                  return Text('Error: ${snapshot.error}');
                } else {
                  return const Text('Waiting for messages...');
                }
              },
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: sendMessage,
        backgroundColor: Colors.blueGrey,
        child: const Icon(Icons.send),
      ),
    );
  }

  void sendMessage() {
    if (textEditingController.text.isNotEmpty) {
      myChannel.sink.add(
        textEditingController.text,
      ); // Send message via WebSocket
      textEditingController.clear();
    }
  }

  @override
  void dispose() {
    myChannel.sink.close(); // Close WebSocket connection
    textEditingController.dispose(); // Dispose of the text controller
    super.dispose();
  }
}
