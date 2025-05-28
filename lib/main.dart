import 'package:flutter/material.dart';
import 'screens/bed_screen.dart';
import 'screens/camera_screen.dart';
import 'screens/music_screen.dart';
import 'screens/temp_screen.dart';
import 'screens/home_screen.dart';
import 'screens/account_screen.dart';
import 'package:circle_bottom_navigation/circle_bottom_navigation.dart';
import 'package:circle_bottom_navigation/widgets/tab_data.dart';
import 'package:provider/provider.dart';
import 'controllers/temp_controller.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => TempController()),
        // 다른 컨트롤러들...
      ],
      child: const SmartBedApp(),
    ),
  );
}
class SmartBedApp extends StatelessWidget {
  const SmartBedApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(

      theme: ThemeData(primarySwatch: Colors.deepPurple),
      home: const MainScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 2;

  final List<Widget> _pages = const [
    BedScreen(),       // 0
    CameraScreen(),    // 1
    HomeScreen(),      // 2 🏠
    MusicScreen(),     // 3
    TempScreen(),      // 4
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('InnoArt'),
        centerTitle: true,
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.account_circle),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AccountScreen()),
              );
            },
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(
                color: Colors.deepPurple,
              ),
              child: Text(
                '메뉴',
                style: TextStyle(color: Colors.white, fontSize: 24),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('설정'),
              onTap: () {},
            ),
            ListTile(
              leading: const Icon(Icons.help_outline),
              title: const Text('도움말'),
              onTap: () {},
            ),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('로그아웃'),
              onTap: () {},
            ),
          ],
        ),
      ),
      body: _pages[_selectedIndex],
      bottomNavigationBar: CircleBottomNavigation(
        initialSelection: _selectedIndex,
        circleColor: Colors.deepPurple,
        activeIconColor: Colors.white,
        inactiveIconColor: Colors.grey.shade400,
        textColor: Colors.deepPurple.shade200,
        barBackgroundColor: Colors.white,
        tabs: [
          TabData(icon: Icons.bed, title: '침대'),
          TabData(icon: Icons.camera_alt, title: '카메라'),
          TabData(icon: Icons.home, title: '홈'),
          TabData(icon: Icons.music_note, title: '음악'),
          TabData(icon: Icons.thermostat, title: '온도'),
        ],
        onTabChangedListener: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
      ),
    );
  }
}

