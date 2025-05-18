import 'package:datavault/Responsive/Responsive%20DashBoard/desktop_dashboard.dart';
import 'package:datavault/Responsive/Responsive%20DashBoard/mobile_dashboard.dart';
import 'package:datavault/Responsive/Responsive%20DashBoard/tablet_dashboard.dart';
import 'package:datavault/Responsive/Responsive%20Setting/desktop_setting.dart';
import 'package:datavault/Responsive/Responsive%20Setting/tablet_setting.dart';
import 'package:datavault/Responsive/responsive_layout.dart';
import 'package:datavault/Responsive/Responsive%20Setting/mobile_settings.dart';
import 'package:datavault/Scrrens/Nearby_Devices_screen.dart';
import 'package:flutter/material.dart';

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  int _currentIndex = 0;

  // Screens for navigation
  final screens = [
    ResponsiveLayout(
      mobileScaffold: DesktopDashboard(),
      tabletScaffold: TabletDashboard(),
      desktopScaffold: DesktopDashboard(),
    ),
    ShareScreen(),
    ResponsiveLayout(
      mobileScaffold: MobileSettings(),
      tabletScaffold: TabletSetting(),
      desktopScaffold: DesktopSetting(),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body:
          _currentIndex < screens.length ? screens[_currentIndex] : screens[0],
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.shifting, // Set type to shifting
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: [
          _buildAnimatedBottomNavigationBarItem(
            icon: Icons.folder,
            label: 'Dashboard',
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
          _buildAnimatedBottomNavigationBarItem(
            icon: Icons.ios_share_sharp,
            label: 'Share',
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
          _buildAnimatedBottomNavigationBarItem(
            icon: Icons.settings_suggest_rounded,
            label: 'Settings',
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
        ],
        selectedItemColor:
            Theme.of(context).colorScheme.secondary, // Color for selected item
        unselectedItemColor: Colors.grey, // Color for unselected items
      ),
    );
  }

  BottomNavigationBarItem _buildAnimatedBottomNavigationBarItem({
    required IconData icon,
    required String label,
    required Color backgroundColor,
  }) {
    return BottomNavigationBarItem(
      icon: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        transitionBuilder: (child, animation) {
          return ScaleTransition(scale: animation, child: child);
        },
        child: Icon(icon, key: ValueKey<int>(_currentIndex)),
      ),
      label: label,
      backgroundColor: backgroundColor,
    );
  }
}
