import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';
import 'package:mime/mime.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';

class ReceivedFile {
  final String filename;
  final String contentType;
  final int totalSize;
  final Map<int, Uint8List> chunks = {};
  bool isComplete = false;
  String? localPath;

  ReceivedFile({
    required this.filename,
    required this.contentType,
    required this.totalSize,
  });

  int get receivedSize {
    return chunks.values.fold(0, (sum, chunk) => sum + chunk.length);
  }

  double get progress {
    return receivedSize / totalSize;
  }

  Future<String> saveToFile() async {
    final sortedOffsets = chunks.keys.toList()..sort();
    final completeData = Uint8List(totalSize);
    int position = 0;
    for (final offset in sortedOffsets) {
      final chunk = chunks[offset]!;
      completeData.setRange(position, position + chunk.length, chunk);
      position += chunk.length;
    }
    final directory = await getTemporaryDirectory();
    final filePath = '${directory.path}/$filename';
    final file = File(filePath);
    await file.writeAsBytes(completeData);
    localPath = filePath;
    return filePath;
  }
}

class FileTransferScreen extends StatefulWidget {
  final String deviceId;
  final WebSocketChannel channel;
  final Stream<dynamic>? broadcastStream; // Add this parameter

  const FileTransferScreen({
    super.key,
    required this.deviceId,
    required this.channel,
    this.broadcastStream, // Accept broadcast stream
  });

  @override
  State<FileTransferScreen> createState() => _FileTransferScreenState();
}

class _FileTransferScreenState extends State<FileTransferScreen> {
  final TextEditingController _controller = TextEditingController();

  PlatformFile? selectedFile;
  String? mimeType;
  bool isFileSending = false;

  Map<String, ReceivedFile> receivedFiles = {};
  ReceivedFile? _incomingFileMeta;
  List<dynamic> messageHistory = [];

  @override
  void initState() {
    super.initState();
    // Use the broadcast stream if available, otherwise don't listen
    if (widget.broadcastStream != null) {
      widget.broadcastStream!.listen(
        (message) async {
          if (message is Uint8List) {
            if (_incomingFileMeta != null) {
              final fileMeta = _incomingFileMeta!;
              final directory = await getTemporaryDirectory();
              final filePath = '${directory.path}/${fileMeta.filename}';
              final file = File(filePath);
              await file.writeAsBytes(message);
              setState(() {
                receivedFiles[fileMeta.filename] =
                    ReceivedFile(
                      filename: fileMeta.filename,
                      contentType: fileMeta.contentType,
                      totalSize: fileMeta.totalSize,
                    )
                    ..isComplete = true
                    ..localPath = filePath;
                _incomingFileMeta = null;
              });
            }
          } else {
            try {
              final Map<String, dynamic> data = jsonDecode(message.toString());
              if (data['type'] == 'file_metadata') {
                _incomingFileMeta = ReceivedFile(
                  filename: data['filename'],
                  contentType: data['contentType'] ?? 'application/octet-stream',
                  totalSize: data['size'],
                );
                setState(() {});
              } else if (data['type'] == 'file_notification') {
                setState(() {
                  messageHistory.add('New file available: ${data['filename']}');
                });
                widget.channel.sink.add(
                  jsonEncode({
                    "type": "request_file",
                    "filename": data['filename'],
                  }),
                );
              } else if (data['type'] == 'file_received') {
                setState(() {
                  messageHistory.add('File uploaded: ${data['filename']}');
                });
              } else if (data['type'] == 'message') {
                setState(() {
                  messageHistory.add(data['text']);
                });
              } else {
                setState(() {
                  messageHistory.add(data);
                });
              }
            } catch (_) {
              setState(() {
                messageHistory.add(message.toString());
              });
            }
          }
        },
        onDone: () {},
        onError: (_) {},
      );
    }
  }

  Future<void> sendFileMetadata() async {
    if (selectedFile == null) return;
    setState(() => isFileSending = true);
    try {
      final fileMetadata = {
        "type": "file_metadata",
        "filename": selectedFile!.name,
        "size": selectedFile!.size,
        "contentType": mimeType ?? 'application/octet-stream',
      };
      widget.channel.sink.add(jsonEncode(fileMetadata));
      await Future.delayed(Duration(milliseconds: 100));
      final file = File(selectedFile!.path!);
      final bytes = await file.readAsBytes();
      widget.channel.sink.add(bytes);
      setState(() {
        messageHistory.add('Sent file: ${selectedFile!.name}');
        selectedFile = null;
        mimeType = null;
      });
    } catch (e) {
      setState(() {
        messageHistory.add('Error sending file: $e');
      });
    }
    setState(() => isFileSending = false);
  }

  Future<void> pickFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      allowMultiple: false,
    );
    if (result != null) {
      final file = result.files.first;
      final String? detectedMimeType = lookupMimeType(
        file.path ?? '',
        headerBytes: file.bytes?.take(16).toList(),
      );
      setState(() {
        selectedFile = file;
        mimeType = detectedMimeType ?? 'application/octet-stream';
      });
    }
  }

  String _formatFileSize(int size) {
    if (size < 1024) return '$size B';
    if (size < 1048576) return '${(size / 1024).toStringAsFixed(1)} KB';
    return '${(size / 1048576).toStringAsFixed(1)} MB';
  }

  Widget _buildFileCard(ReceivedFile file) {
    IconData fileIcon;
    if (file.contentType.startsWith('image/')) {
      fileIcon = Icons.image;
    } else if (file.contentType.startsWith('video/')) {
      fileIcon = Icons.video_file;
    } else if (file.contentType.startsWith('audio/')) {
      fileIcon = Icons.audio_file;
    } else if (file.contentType.startsWith('application/pdf')) {
      fileIcon = Icons.picture_as_pdf;
    } else {
      fileIcon = Icons.insert_drive_file;
    }
    return Card(
      margin: EdgeInsets.symmetric(vertical: 4),
      elevation: 2,
      child: ListTile(
        leading: Icon(fileIcon, size: 36, color: Colors.blue.shade700),
        title: Text(
          file.filename,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          file.contentType,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
        ),
        trailing:
            file.isComplete && file.localPath != null
                ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(Icons.open_in_new, color: Colors.blue),
                      tooltip: 'Open',
                      onPressed: () => OpenFile.open(file.localPath!),
                    ),
                    IconButton(
                      icon: Icon(Icons.download, color: Colors.green),
                      tooltip: 'Download',
                      onPressed:
                          () => _downloadFile(file.localPath!, file.filename),
                    ),
                  ],
                )
                : null,
      ),
    );
  }

  Widget _buildTextMessage(String message) {
    return Card(
      margin: EdgeInsets.symmetric(vertical: 4),
      color: Colors.blue.shade50,
      child: Padding(padding: const EdgeInsets.all(12.0), child: Text(message)),
    );
  }

  Widget _buildJsonMessage(Map message) {
    return Card(
      margin: EdgeInsets.symmetric(vertical: 4),
      color: Colors.purple.shade50,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Text(jsonEncode(message)),
      ),
    );
  }

  Future<void> _downloadFile(String path, String filename) async {
    try {
      final directory = await getDownloadsDirectory();
      if (directory == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Downloads directory not found.')),
        );
        return;
      }
      final newPath = '${directory.path}/$filename';
      final file = File(path);
      await file.copy(newPath);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('File saved to $newPath')));
      await OpenFile.open(newPath);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to download file: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('File Transfer: ${widget.deviceId}'),
        backgroundColor: Colors.blueAccent,
      ),
      backgroundColor: Colors.grey[200],
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Chat/messages section
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 8.0, bottom: 8.0),
                    child: Text(
                      'Messages',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(12),
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
                      child:
                          messageHistory.isEmpty
                              ? Center(
                                child: Text(
                                  'No messages received yet',
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontSize: 16,
                                  ),
                                ),
                              )
                              : ListView.builder(
                                itemCount: messageHistory.length,
                                reverse: true,
                                itemBuilder: (context, index) {
                                  final reverseIndex =
                                      messageHistory.length - 1 - index;
                                  final message = messageHistory[reverseIndex];
                                  if (message is Map) {
                                    return _buildJsonMessage(message);
                                  } else {
                                    return _buildTextMessage(
                                      message.toString(),
                                    );
                                  }
                                },
                              ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Files section
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 8.0, bottom: 8.0),
                    child: Text(
                      'Files',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Expanded(
                    child:
                        receivedFiles.isEmpty
                            ? Center(
                              child: Text(
                                'No files received yet',
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 16,
                                ),
                              ),
                            )
                            : ListView.builder(
                              itemCount: receivedFiles.length,
                              itemBuilder: (context, index) {
                                final file = receivedFiles.values.elementAt(
                                  index,
                                );
                                return _buildFileCard(file);
                              },
                            ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // User input section
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      labelText: 'Send a message',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: Icon(Icons.attach_file),
                  onPressed: pickFile,
                  color: Colors.blueAccent,
                ),
                ElevatedButton(
                  onPressed: () {
                    if (_controller.text.isNotEmpty) {
                      widget.channel.sink.add(_controller.text);
                      _controller.clear();
                    }
                  },
                  child: const Text('Send'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
            // File upload section (when a file is selected)
            if (selectedFile != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Selected file:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '${selectedFile!.name} (${_formatFileSize(selectedFile!.size)})',
                      style: TextStyle(fontSize: 16),
                    ),
                    if (mimeType != null)
                      Text(
                        'Type: $mimeType',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () {
                            setState(() {
                              selectedFile = null;
                              mimeType = null;
                            });
                          },
                          child: Text('Cancel'),
                        ),
                        SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: isFileSending ? null : sendFileMetadata,
                          child:
                              isFileSending
                                  ? Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2,
                                        ),
                                      ),
                                      SizedBox(width: 8),
                                      Text('Sending...'),
                                    ],
                                  )
                                  : Text('Send File'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blueAccent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
