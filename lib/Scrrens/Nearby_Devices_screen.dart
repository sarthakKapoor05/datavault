import 'dart:math';
import 'package:flutter/material.dart';
import 'package:multicast_dns/multicast_dns.dart';

class ShareScreen extends StatefulWidget {
  @override
  _ShareScreenState createState() => _ShareScreenState();
}

class _ShareScreenState extends State<ShareScreen>
    with SingleTickerProviderStateMixin {
  static const String name = '_dartobservatory._tcp.local';
  final MDnsClient client = MDnsClient();
  // Start the client with default options.

  void startScanning() async {
    await client.start();
    // Start scanning for services
    await for (final PtrResourceRecord ptr in client.lookup<PtrResourceRecord>(
      ResourceRecordQuery.serverPointer(name),
    )) {
      // Use the domainName from the PTR record to get the SRV record,
      // which will have the port and local hostname.
      // Note that duplicate messages may come through, especially if any
      // other mDNS queries are running elsewhere on the machine.
      await for (final SrvResourceRecord srv in client
          .lookup<SrvResourceRecord>(
            ResourceRecordQuery.service(ptr.domainName),
          )) {
        // Domain name will be something like "io.flutter.example@some-iphone.local._dartobservatory._tcp.local"
        final String bundleId =
            ptr.domainName; //.substring(0, ptr.domainName.indexOf('@'));
        print(
          'Dart observatory instance found at '
          '${srv.target}:${srv.port} for "$bundleId".',
        );
      }
    }
  }

  // void stopScanning = () async {
  //   await client.stop();
  // }

  final List<Map<String, String>> recentDevices = [
    {'name': 'Brandy', 'id': 'CP#25656835'},
    {'name': 'James', 'id': 'CP#25656835'},
    {'name': 'Anderson', 'id': 'CP#25656835'},
  ];

  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 5),
      vsync: this,
    )..repeat(); // Continuous waving
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

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
                    return AnimatedBuilder(
                      animation: _controller,
                      builder: (context, child) {
                        double scale =
                            1.0 +
                            sin((_controller.value * 2 * pi) + index) * 0.05;
                        return Transform.scale(
                          scale: scale,
                          child: Container(
                            width: radius * 2,
                            height: radius * 2,
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: Colors.white.withOpacity(0.2),
                                width: 1.5,
                              ),
                              shape: BoxShape.circle,
                            ),
                          ),
                        );
                      },
                    );
                  }),
                  GestureDetector(
                    onTap: () {
                      startScanning();
                    },
                    child: Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: Color(0xFF50C2C9),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.sync, color: Colors.white, size: 30),
                    ),
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
            child: const Text(
              'Connect',
              style: TextStyle(color: Color.fromARGB(255, 255, 255, 255)),
            ),
          ),
        ],
      ),
    );
  }
}
