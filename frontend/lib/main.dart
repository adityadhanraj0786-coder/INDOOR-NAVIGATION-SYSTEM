import 'dart:io';
import 'maps.dart';
import 'profile.dart';
import 'navigation.dart';
//import 'package:coolapp/pages/profile.dart';
import 'package:flutter/material.dart';
import 'package:animated_splash_screen/animated_splash_screen.dart';
import 'package:page_transition/page_transition.dart';
import 'package:animated_text_kit/animated_text_kit.dart';
import 'package:marquee/marquee.dart';
import 'package:audioplayers/audioplayers.dart';

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
      print('Error playing sound: $e');
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
            //mainAxisSize: MainAxisSize.min, // prevents extra vertical expansion
            children: [
              SizedBox(
                width: 250,
                height: 150, // fixed size so it won't push content down
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
                    //duration: Duration(milliseconds: 2000),
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
                      fontSize: 20.0, // smaller size
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
                      Color.fromARGB(255, 0, 157, 255),
                      Colors.green,
                      Colors.orange,
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
        nextScreen: HomeScreen(),
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

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    if (index == 0) {
      setState(() {
        _selectedIndex = 0;
      });
    }
    if (index == 1) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const ProfilePage()),
      ).then((_) {
        setState(() {
          _selectedIndex = 0; // 👈 Reset to Home after returning
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 245, 255, 215),
      appBar: AppBar(
        //leading: Icon(  Icons.menu, color: Colors.white),
        actions: [
          IconButton(
            icon: Icon(Icons.logout, color: Colors.white),
            onPressed: () {
              exit(0);
            },
          ),
        ],
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(
          color: Colors.white, // 👈 makes drawer (hamburger) icon white
        ),
        title: SizedBox(
          height: kToolbarHeight, // match AppBar height
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
        mainAxisAlignment: MainAxisAlignment.center, // center vertically
        crossAxisAlignment: CrossAxisAlignment.center, // center horizontally

        children: [
          const SizedBox(width: 200), // space from top
          Image.asset(
            'assets/finalmap.png', 
            width: 150,
            height: 150,
          ),
          const SizedBox(height: 1), // space between image and button
          ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const Maps()),
              );
            },
            child: const Text('Map'),
          ),
          const SizedBox(height: 50), // space between buttons
          const SizedBox(width: 400), // space from side
          Image.asset(
            'assets/finalnav.png', 
            width: 150,
            height: 150,
          ),
          const SizedBox(height: 1), // space between image and button
          ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const Navigation()),
              );
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

              //decoration: BoxDecoration(
              color: const Color.fromARGB(255, 255, 57, 57),
              alignment: Alignment.bottomCenter,
              //),

              //padding: const EdgeInsets.all(40.0),
              child: Text(
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
