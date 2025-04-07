import 'package:datavault/Scrrens/folders.dart';
import 'package:flutter/material.dart';

class Dashboard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: FileManagerPage(),
    );
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
    {'title': 'Downloads', 'icon': Icons.download, 'color': Colors.blue},
    // {'title': 'Bluetooth', 'icon': Icons.bluetooth, 'color': Colors.blueAccent},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(
          'Files',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.black,
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: ListView(
            children: [
              // ✅ Wrapped in GestureDetector to navigate
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => FolderListScreen(),
                    ), // ✅ Navigation Added
                  );
                },
                child: Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[900],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Device storage',
                        style: TextStyle(color: Colors.white70),
                      ),
                      SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${usedStorage.toStringAsFixed(1)} GB / ${totalStorage.toStringAsFixed(1)} GB',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
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

              SizedBox(height: 20),

              // File Categories
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children:
                    categories.map((category) {
                      return _buildCategoryCard(context, category);
                    }).toList(),
              ),

              SizedBox(height: 20),

              // Sources Section
              Text(
                'Sources',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 10),
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
    );
  }

  Widget _buildCategoryCard(
    BuildContext context,
    Map<String, dynamic> category,
  ) {
    return Container(
      width: (MediaQuery.of(context).size.width / 2) - 24,
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(category['icon'], color: category['color'], size: 32),
          SizedBox(height: 8),
          Text(category['title'], style: TextStyle(color: Colors.white)),
          SizedBox(height: 4),
          Text(
            category['count'].toString(),
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildSourceTile(Map<String, dynamic> source) {
    return ListTile(
      leading: Icon(source['icon'], color: source['color'], size: 32),
      title: Text(source['title'], style: TextStyle(color: Colors.white)),
      onTap: () {},
      contentPadding: EdgeInsets.symmetric(vertical: 4),
    );
  }
}
