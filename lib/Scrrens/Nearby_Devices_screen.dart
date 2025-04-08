import 'package:flutter/material.dart';

class ShareScreen extends StatelessWidget {
  final List<Map<String, String>> recentDevices = [
    {'name': 'Brandy', 'id': 'CP#25656835'},
    {'name': 'James', 'id': 'CP#25656835'},
    {'name': 'Anderson', 'id': 'CP#25656825'},
    {'name': 'Sarthak', 'id': 'CP#25656135'},
    {'name': 'xyz', 'id': 'CP#25656815'},
    {'name': 'Iron man', 'id': 'CP#25616835'},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
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
                    return Container(
                      width: radius * 2,
                      height: radius * 2,
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: Colors.white.withOpacity(0.2),
                          width: 1.5,
                        ),
                        shape: BoxShape.circle,
                      ),
                    );
                  }),
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: Color(0xFF50C2C9),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.sync, color: Colors.white, size: 30),
                  ),
                ],
              ),
            ),
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
                        color: Colors.white,
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

  Widget _recentDeviceCard(Map<String, String> device) {
    return Container(
      width: 130,
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Color(0xFF1C1C1C),
        boxShadow: [
          BoxShadow(color: Colors.black26, blurRadius: 5, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.devices, size: 30, color: Colors.white),
          const SizedBox(height: 8),
          Text(
            device['name']!,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          Text(device['id']!, style: TextStyle(color: Colors.grey.shade400)),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: () {},
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFF50C2C9),
              padding: EdgeInsets.symmetric(horizontal: 20),
            ),
            child: const Text('Connect', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
