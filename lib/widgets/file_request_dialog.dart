import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:datavault/services/connection_service.dart';
import 'package:datavault/services/event_bus_service.dart';

class FileRequestDialog extends StatefulWidget {
  @override
  _FileRequestDialogState createState() => _FileRequestDialogState();
}

class _FileRequestDialogState extends State<FileRequestDialog> {
  StreamSubscription? _subscription;

  @override
  void initState() {
    super.initState();
    // Delay setup to ensure context is available
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setupSubscription();
    });
  }

  void _setupSubscription() {
    _subscription = eventBus.on<FileRequestEvent>().listen((event) {
      // Critical: Check if still mounted before showing dialog
      if (mounted) {
        _showFileRequestDialog(
          event.requesterId,
          event.requesterName,
          event.filename,
        );
      }
    });
  }

  void _showFileRequestDialog(String requesterId, String requesterName, String filename) {
    // Get the context using GlobalKey
    final context = this.context;
    
    // Check if context is valid
    if (!mounted) return;
    
    // Get a reference to the ConnectionService
    final connectionService = Provider.of<ConnectionService>(context, listen: false);
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text('File Request'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$requesterName wants to download:'),
              SizedBox(height: 8),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  filename,
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              SizedBox(height: 16),
              Text('Allow this download?'),
            ],
          ),
          actions: [
            TextButton(
              child: Text('Deny'),
              onPressed: () {
                Navigator.of(dialogContext).pop();
                connectionService.denyFileRequest(requesterId, filename);
              },
            ),
            ElevatedButton(
              child: Text('Allow'),
              onPressed: () {
                Navigator.of(dialogContext).pop();
                connectionService.sendRequestedFile(requesterId, filename);
              },
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    // Cancel the subscription when widget is disposed
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // This widget doesn't actually render anything visible
    // It just sets up the event listener
    return SizedBox.shrink();
  }
}