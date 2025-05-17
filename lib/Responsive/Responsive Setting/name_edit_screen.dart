import 'package:flutter/material.dart';

class NameEditScreen extends StatefulWidget {
  final String currentName;

  const NameEditScreen({super.key, required this.currentName});

  @override
  State<NameEditScreen> createState() => _NameEditScreenState();
}

class _NameEditScreenState extends State<NameEditScreen> {
  late TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.currentName);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final charCount = _nameController.text.length;

    return Scaffold(
      appBar: AppBar(
        title: Text('Device name'),
        actions: [
          IconButton(
            icon: Icon(Icons.check),
            onPressed: () {
              Navigator.pop(context, _nameController.text.trim());
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nameController,
              maxLength: 25,
              cursorColor: Color(
                0xFF50C2C9,
              ), // Add cursor color to match app theme
              decoration: InputDecoration(
                labelText: 'Device name',
                hintText: 'Enter your device name',
                border: OutlineInputBorder(),
                suffixIcon: Icon(
                  Icons
                      .edit_outlined, // Changed from tag_faces to edit_outlined
                  color: Color(0xFF50C2C9), // Match app theme color
                ),
                // Add focused border color to match cursor
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFF50C2C9)),
                ),
                // Add focused label color to match cursor
                labelStyle: TextStyle(color: Colors.grey),
                floatingLabelStyle: TextStyle(color: Color(0xFF50C2C9)),
              ),
              onChanged: (_) {
                setState(() {});
              },
            ),
            SizedBox(height: 8),
            Text(
              'People will see this name if you interact with them and they don\'t have you saved as a contact.',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }
}
