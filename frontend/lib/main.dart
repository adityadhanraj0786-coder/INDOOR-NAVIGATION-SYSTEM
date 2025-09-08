// ignore_for_file: use_build_context_synchronously

import 'dart:io';
import 'maps.dart';
import 'profile.dart';
import 'navigation.dart';
import 'package:flutter/material.dart';
import 'package:animated_splash_screen/animated_splash_screen.dart';
import 'package:page_transition/page_transition.dart';
import 'package:animated_text_kit/animated_text_kit.dart';
import 'package:marquee/marquee.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late AudioPlayer _audioPlayer;

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
    _playSound();
  }

  Future<void> _playSound() async {
    try {
      await _audioPlayer.play(AssetSource('splash_sound.mp3'));
    } catch (e) {
      // ignore error
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: AnimatedSplashScreen(
        splash: Center(
          child: Column(
            children: [
              SizedBox(
                width: 250,
                height: 150,
                child: Image.asset('assets/logo.png'),
              ),
              const SizedBox(height: 20),
              AnimatedTextKit(
                repeatForever: true,
                animatedTexts: [
                  ColorizeAnimatedText(
                    'NavU',
                    textAlign: TextAlign.center,
                    textStyle: const TextStyle(
                      fontSize: 32.0,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                    colors: [
                      const Color.fromARGB(255, 225, 255, 0),
                      Colors.green,
                      Colors.purple,
                      Colors.orange,
                      Colors.red,
                      Colors.yellow,
                      Colors.pink,
                      Colors.cyan,
                      const Color.fromARGB(255, 0, 157, 255),
                    ],
                    speed: Duration(milliseconds: 8000),
                  ),
                ],
                pause: Duration.zero,
              ),
              const SizedBox(height: 8),
              AnimatedTextKit(
                repeatForever: true,
                animatedTexts: [
                  ColorizeAnimatedText(
                    'Your Pocket Guide',
                    textStyle: const TextStyle(
                      fontSize: 20.0,
                      fontWeight: FontWeight.w600,
                    ),
                    colors: [
                      const Color.fromARGB(255, 209, 249, 8),
                      Colors.green,
                      Colors.purple,
                      Colors.orange,
                      Colors.red,
                      Colors.yellow,
                      Colors.pink,
                      Colors.cyan,
                      const Color.fromARGB(255, 0, 157, 255),
                    ],
                    speed: const Duration(milliseconds: 2000),
                  ),
                ],
                pause: Duration.zero,
              ),
            ],
          ),
        ),
        splashIconSize: 262,
        nextScreen: const HomeScreen(),
        splashTransition: SplashTransition.fadeTransition,
        pageTransitionType: PageTransitionType.fade,
        duration: 2900,
        backgroundColor: const Color.fromARGB(255, 0, 0, 0),
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkPermissionsOnResume();
    }
  }

  Future<void> _checkPermissionsOnResume() async {
    var status = await Permission.location.status;
    if (status.isGranted) {
      print('Location permission granted on resume');
    } else {
      print('Location permission still denied on resume');
    }
  }

  Future<bool> _checkAndRequestAllPermissions(BuildContext context) async {
    Map<Permission, PermissionStatus> statuses = await [
      Permission.location,
      Permission.camera,
      Permission.microphone,
      //Permission.storage,
      Permission.bluetooth,
      Permission.bluetoothConnect,
      Permission.bluetoothScan,
      //Permission.accessMediaLocation,
      Permission.activityRecognition,
      //Permission.scheduleExactAlarm,
      //Permission.notification,
      //Permission.manageExternalStorage,
    ].request();

    bool allGranted = statuses.values.every((status) => status.isGranted);

    if (allGranted) {
      return true;
    } else {
      await _showOpenSettingsDialog(context);
      return false;
    }
  }

  Future<void> _showOpenSettingsDialog(BuildContext context) async {
    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Permissions Required'),
          content: const Text(
              'Permissions are required for navigation. Please enable all app permissions in the settings.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                await openAppSettings();
                Navigator.of(context).pop();
              },
              child: const Text('Open Settings'),
            ),
          ],
        );
      },
    );
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });

    if (index == 1) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const ProfilePage()),
      ).then((_) {
        if (!mounted) return;
        setState(() {
          _selectedIndex = 0;
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 245, 255, 215),
      appBar: AppBar(
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: () {
              exit(0);
            },
          ),
        ],
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: SizedBox(
          height: kToolbarHeight,
          child: Marquee(
            text:
                "•NOTE: FOT will remain closed tomorrow•\t\t\t\t•Tip: Try not to trip on your way to stairs•\t\t\t\t•Hello Ma'am!•\t\t\t\t•Yayyy :D•\t\t\t\t ",
            style: const TextStyle(fontSize: 20, color: Colors.white),
            blankSpace: 10.0,
            velocity: 50.0,
            startAfter: Duration.zero,
            pauseAfterRound: Duration.zero,
            scrollAxis: Axis.horizontal,
            crossAxisAlignment: CrossAxisAlignment.center,
          ),
        ),
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(width: 200),
          Image.asset(
            'assets/finalmap.png',
            width: 150,
            height: 150,
          ),
          const SizedBox(height: 1),
          ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const Maps()),
              );
            },
            child: const Text('Map'),
          ),
          const SizedBox(height: 50),
          const SizedBox(width: 400),
          Image.asset(
            'assets/finalnav.png',
            width: 150,
            height: 150,
          ),
          const SizedBox(height: 1),
          ElevatedButton(
            onPressed: () async {
              bool permissionGranted =
                  await _checkAndRequestAllPermissions(context);
              if (!mounted) return;
              if (permissionGranted) {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const Navigation()),
                );
              }
            },
            child: const Text('Navigation'),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Profile'),
        ],
      ),
      drawer: Drawer(
        backgroundColor: const Color.fromARGB(255, 240, 220, 107),
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            Container(
              height: 80,
              color: const Color.fromARGB(255, 255, 57, 57),
              alignment: Alignment.bottomCenter,
              child: const Text(
                'Menu  🍽️',
                style: TextStyle(color: Colors.white, fontSize: 24),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.home),
              title: const Text('Home'),
              onTap: () {
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('Settings'),
              onTap: () {
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.contact_mail),
              title: const Text('Contact Us'),
              onTap: () {
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }
}
