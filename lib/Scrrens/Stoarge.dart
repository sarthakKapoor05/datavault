import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

class StorageInfoWidget extends StatefulWidget {
  const StorageInfoWidget({super.key});

  @override
  State<StorageInfoWidget> createState() => _StorageInfoWidgetState();
}

class _StorageInfoWidgetState extends State<StorageInfoWidget> {
  int totalSpace = 0;
  int freeSpace = 0;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStorageInfo();
  }

  Future<void> _loadStorageInfo() async {
    try {
      Directory dir = await getApplicationDocumentsDirectory();
      var result = await Process.run('df', ['-k', dir.path]);
      var lines = result.stdout.toString().split('\n');
      if (lines.length > 1) {
        var parts = lines[1].split(RegExp(r'\s+'));
        if (parts.length > 4) {
          setState(() {
            totalSpace = int.parse(parts[1]) * 1024;
            freeSpace = int.parse(parts[3]) * 1024;
            isLoading = false;
          });
        }
      }
    } catch (e) {
      print("Error getting storage info: $e");
      setState(() {
        isLoading = false;
      });
    }
  }

  String _formatBytes(int bytes, [int decimals = 2]) {
    if (bytes <= 0) return "0 B";
    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    var i = (bytes != 0) ? (math.log(bytes) / math.log(1024)).floor() : 0;
    return ((bytes / math.pow(1024, i)).toStringAsFixed(decimals)) +
        ' ' +
        suffixes[i];
  }

  @override
  Widget build(BuildContext context) {
    int usedSpace = totalSpace - freeSpace;
    double usagePercent = (totalSpace != 0) ? usedSpace / totalSpace : 0;

    return isLoading
        ? const Center(child: CircularProgressIndicator())
        : Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Total Storage: ${_formatBytes(totalSpace)}",
              style: const TextStyle(fontSize: 16),
            ),
            Text(
              "Used Storage: ${_formatBytes(usedSpace)}",
              style: const TextStyle(fontSize: 16),
            ),
            Text(
              "Free Storage: ${_formatBytes(freeSpace)}",
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 10),
            LinearProgressIndicator(
              value: usagePercent,
              minHeight: 12,
              backgroundColor: Colors.grey[300],
              color: Colors.blue,
            ),
            const SizedBox(height: 5),
            Text(
              "${(usagePercent * 100).toStringAsFixed(1)}% used",
              style: const TextStyle(fontSize: 14),
            ),
          ],
        );
  }
}
