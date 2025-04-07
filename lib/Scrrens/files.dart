import 'package:datavault/Scrrens/folders.dart';
import 'package:flutter/material.dart';

class Files extends StatelessWidget {
  const Files({super.key});

  final double usedStorage = 5.3; // GB
  final double totalStorage = 128.0; // GB

  final List<Map<String, dynamic>> categories = const [
    {'name': 'Images', 'icon': Icons.image, 'color': Colors.orange},
    {'name': 'Videos', 'icon': Icons.videocam, 'color': Colors.red},
    {
      'name': 'Documents',
      'icon': Icons.insert_drive_file,
      'color': Colors.blue,
    },
    {'name': 'Audio', 'icon': Icons.audiotrack, 'color': Colors.green},
    {'name': 'APK', 'icon': Icons.android, 'color': Colors.purple},
  ];

  final List<Map<String, dynamic>> sources = const [
    {'name': 'Downloads', 'icon': Icons.download},
    {'name': 'Bluetooth', 'icon': Icons.bluetooth},
    {'name': 'Received Files', 'icon': Icons.file_present},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Files',
          style: TextStyle(
            fontSize: 25,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.blueGrey[600],
      ),
      backgroundColor: const Color.fromARGB(255, 255, 255, 255),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 0),
          child: ListView(
            children: [
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const FolderListScreen(),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[900],
                    borderRadius: BorderRadius.circular(0),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Device storage',
                        style: TextStyle(color: Colors.white70),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${usedStorage.toStringAsFixed(1)} GB / ${totalStorage.toStringAsFixed(1)} GB',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: usedStorage / totalStorage,
                        backgroundColor: Colors.grey[700],
                        color: Colors.green,
                        minHeight: 8,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 30), // Increased spacing here
              Wrap(
                spacing: 16,
                runSpacing: 16,
                children:
                    categories.map((category) {
                      return _buildCategoryCard(context, category);
                    }).toList(),
              ),
              const SizedBox(height: 30),
              const Text(
                'Sources',
                style: TextStyle(
                  color: Colors.black87,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Column(
                children:
                    sources.map((source) {
                      return _buildSourceTile(source);
                    }).toList(),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.blueGrey[600],
        child: const Icon(Icons.add, size: 30, color: Colors.white),
        onPressed: () {},
      ),
    );
  }

  Widget _buildCategoryCard(
    BuildContext context,
    Map<String, dynamic> category,
  ) {
    return Container(
      width: 110, // Increased width here
      height: 110,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: category['color'].withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: category['color'], width: 1.5),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(category['icon'], color: category['color'], size: 30),
          const SizedBox(height: 10),
          Text(
            category['name'],
            textAlign: TextAlign.center,
            style: TextStyle(
              color: category['color'],
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSourceTile(Map<String, dynamic> source) {
    return ListTile(
      leading: Icon(source['icon'], color: Colors.blueGrey[600]),
      title: Text(source['name']),
      trailing: const Icon(Icons.chevron_right),
      onTap: () {
        // TODO: Add navigation or functionality
      },
    );
  }
}
