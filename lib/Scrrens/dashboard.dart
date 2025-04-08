import 'package:datavault/Scrrens/apks_screen.dart';
import 'package:datavault/Scrrens/archives_screen.dart';
import 'package:datavault/Scrrens/audio_screen.dart';
import 'package:datavault/Scrrens/documents_screen.dart';
import 'package:datavault/Scrrens/downloads_screen.dart';
import 'package:datavault/Scrrens/photos_screen.dart';
import 'package:datavault/Scrrens/videos_screen.dart';
import 'package:flutter/material.dart';
import 'package:datavault/Scrrens/folders.dart';
import 'package:datavault/Scrrens/received_files_screen.dart';

class Dashboard extends StatelessWidget {
  const Dashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return FileManagerPage();
  }
}

class FileManagerPage extends StatefulWidget {
  @override
  _FileManagerPageState createState() => _FileManagerPageState();
}

class _FileManagerPageState extends State<FileManagerPage> {
  final double usedStorage = 28;
  final double totalStorage = 128.0;

  final List<Map<String, dynamic>> categories = [
    {
      'title': 'Photos',
      'count': 200,
      'icon': Icons.photo,
      'color': Colors.blue,
    },
    {
      'title': 'Videos',
      'count': 100,
      'icon': Icons.video_collection,
      'color': Colors.purple,
    },
    {
      'title': 'Audio',
      'count': 255,
      'icon': Icons.music_note,
      'color': Colors.orange,
    },
    {
      'title': 'Documents',
      'count': 90,
      'icon': Icons.insert_drive_file,
      'color': Colors.lightBlue,
    },
    {'title': 'APKs', 'count': 5, 'icon': Icons.android, 'color': Colors.green},
    {
      'title': 'Archives',
      'count': 11,
      'icon': Icons.archive,
      'color': Colors.brown,
    },
  ];

  final List<Map<String, dynamic>> sources = [
    {
      'title': 'Received Files',
      'icon': Icons.file_present,
      'color': Colors.blue,
    },
    {'title': 'Downloads', 'icon': Icons.download, 'color': Colors.blue},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text(
          'Files',
          style: TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.black,
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: ListView(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.grey[900],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.search, color: Colors.white70),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        readOnly: true,
                        style: const TextStyle(color: Colors.white),
                        cursorColor: Colors.white70,
                        decoration: const InputDecoration(
                          hintText: 'Search files, folders...',
                          hintStyle: TextStyle(color: Colors.white70),
                          border: InputBorder.none,
                        ),
                        onChanged: (value) {
                          // 🔍 You can implement real-time filtering here if needed
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
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
                    borderRadius: BorderRadius.circular(12),
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
              const SizedBox(height: 20),
              Wrap(
                spacing: 8,
                runSpacing: 12,
                children:
                    categories
                        .map(
                          (category) => _buildCategoryCard(context, category),
                        )
                        .toList(),
              ),
              const SizedBox(height: 20),
              const Text(
                'Sources',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Column(
                children:
                    sources.map((source) => _buildSourceTile(source)).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryCard(
    BuildContext context,
    Map<String, dynamic> category,
  ) {
    return GestureDetector(
      onTap: () {
        if (category['title'] == 'Photos') {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const PhotosScreen()),
          );
        } else if (category['title'] == 'Videos') {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const VideosScreen()),
          );
        } else if (category['title'] == 'Audio') {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AudioScreen()),
          );
        } else if (category['title'] == 'Documents') {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const DocumentsScreen()),
          );
        } else if (category['title'] == 'APKs') {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const ApksScreen()),
          );
        } else if (category['title'] == 'Archives') {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const ArchivesScreen()),
          );
        }
      },
      child: Container(
        width: (MediaQuery.of(context).size.width / 3) - 20,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(category['icon'], color: category['color'], size: 26),
            const SizedBox(height: 8),
            Text(
              category['title'],
              style: const TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 4),
            Text(
              category['count'].toString(),
              style: const TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSourceTile(Map<String, dynamic> source) {
    return ListTile(
      leading: Icon(source['icon'], color: source['color'], size: 32),
      title: Text(source['title'], style: const TextStyle(color: Colors.white)),
      onTap: () {
        if (source['title'] == 'Received Files') {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const ReceivedFilesScreen(),
            ),
          );
        } else if (source['title'] == 'Downloads') {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const DownloadsScreen()),
          );
        }
      },
      contentPadding: const EdgeInsets.symmetric(vertical: 4),
    );
  }
}
