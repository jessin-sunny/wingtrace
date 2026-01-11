import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart'; 
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async'; // Required for Timer
import 'package:animated_text_kit/animated_text_kit.dart'; // Required for Typewriter
import 'detection_screen.dart'; 
import 'history_screen.dart';
import 'analytics_screen.dart';
import 'settings_screen.dart';
import 'profile_screen.dart';
import 'accuracy_summary_screen.dart';
import 'detection_count_screen.dart';
import 'last_detected_screen.dart';
import 'pest_chatbot_screen.dart';

class UserDashboard extends StatefulWidget {
  const UserDashboard({super.key});

  @override
  State<UserDashboard> createState() => _UserDashboardState();
}

class _UserDashboardState extends State<UserDashboard> {
  bool _isConnected = false;
  final String _deviceName = "WingTrace v1";
  final User? _user = FirebaseAuth.instance.currentUser;
  
  Timer? _factTimer; // Controller for rotating facts

  final List<String> _pestFacts = [
    "Only female mosquitoes bite; they need blood protein for their eggs.",
    "Mosquitoes can detect CO2 from your breath from 75 feet away.",
    "A full moon can increase mosquito activity by up to 500%!",
    "Mosquitoes are the world's deadliest animals, causing 1 million deaths yearly.",
    "Mosquitoes can breed in as little as a teaspoon of stagnant water.",
    "Dragonflies are natural predators; one can eat hundreds of mosquitoes a day."
  ];
  
  late String _currentFact;

  @override
  void initState() {
    super.initState();
    _currentFact = (_pestFacts..shuffle()).first;

    // Changes the fact every 20 seconds
    _factTimer = Timer.periodic(const Duration(seconds: 20), (timer) {
      if (mounted) {
        setState(() {
          _currentFact = (_pestFacts..shuffle()).first;
        });
      }
    });
  }

  @override
  void dispose() {
    _factTimer?.cancel(); // Important: Stop the timer when leaving the screen
    super.dispose();
  }

  // --- UI HELPERS ---

  Widget _envStatItem(IconData icon, String value, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.green, size: 32),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value, 
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.black87)
            ),
            Text(
              label, 
              style: const TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.w500)
            ),
          ],
        ),
      ],
    );
  }

  Widget _summaryItem(IconData icon, String label) {
    return Column(
      children: [
        Icon(icon, color: Colors.grey[700], size: 35),
        const SizedBox(height: 5),
        Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 10, color: Colors.green)),
      ],
    );
  }

  Widget _actionButton(String label, IconData icon) {
    return Column(
      children: [
        Container(
          width: 70, height: 70,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: Colors.green, width: 2),
          ),
          child: Icon(icon, color: Colors.green, size: 35),
        ),
        const SizedBox(height: 5),
        Text(label, textAlign: TextAlign.center, style: const TextStyle(color: Colors.green, fontSize: 12)),
      ],
    );
  }

  // --- LOGIC ---

  void _showConnectionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return FutureBuilder(
              future: Future.delayed(const Duration(seconds: 4)), 
              builder: (context, snapshot) {
                bool isFound = snapshot.connectionState == ConnectionState.done;
                return Dialog(
                  backgroundColor: Colors.green.withOpacity(0.9),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    height: 400,
                    width: MediaQuery.of(context).size.width * 0.85,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (!isFound) ...[
                          const CircularProgressIndicator(color: Colors.white),
                          const SizedBox(height: 25),
                          const Text("looking for device...", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                        ] else ...[
                          ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: Image.asset('assets/device_image.png', height: 200, fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) => const Icon(Icons.developer_board, size: 100, color: Colors.white),
                            ),
                          ),
                          const SizedBox(height: 15),
                          Text("$_deviceName found", style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w500)),
                          const SizedBox(height: 25),
                          ElevatedButton(
                            onPressed: () {
                              setState(() => _isConnected = true);
                              Navigator.pop(context);
                            },
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.green, shape: const StadiumBorder(), padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12)),
                            child: const Text("CONNECT", style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  void _protectedNavigation(Widget screen) {
    if (_isConnected) {
      Navigator.push(context, MaterialPageRoute(builder: (context) => screen));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Action blocked: Please connect your device first."), backgroundColor: Colors.redAccent));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDFBE7),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Stack(
              children: [
                Container(
                  height: 200,
                  decoration: const BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.only(bottomLeft: Radius.circular(100), bottomRight: Radius.circular(100)),
                  ),
                ),
                Positioned(
                  top: 60, left: 0, right: 0,
                  child: Column(
                    children: [
                      const CircleAvatar(radius: 40, backgroundColor: Colors.white, child: Icon(Icons.person, size: 50, color: Colors.grey)),
                      const SizedBox(height: 10),
                      StreamBuilder<DocumentSnapshot>(
                        stream: FirebaseFirestore.instance.collection('users').doc(_user?.uid).snapshots(),
                        builder: (context, snapshot) {
                          String name = "Guest User";
                          if (snapshot.hasData && snapshot.data!.exists) {
                            final data = snapshot.data!.data() as Map<String, dynamic>;
                            name = data['name'] ?? "WingTrace User";
                          }
                          return Text(name, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold));
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  Align(
                    alignment: Alignment.centerRight,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: ElevatedButton(
                        onPressed: _isConnected ? null : _showConnectionDialog,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _isConnected ? Colors.transparent : Colors.red,
                          elevation: _isConnected ? 0 : 2,
                          shape: const StadiumBorder(),
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(_isConnected ? 'LIVE' : 'connect', style: TextStyle(color: _isConnected ? Colors.red : Colors.white, fontWeight: FontWeight.bold)),
                            if (_isConnected) ...[const SizedBox(width: 5), const Icon(Icons.fiber_manual_record, color: Colors.red, size: 12)],
                          ],
                        ),
                      ),
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 20),
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(30), border: Border.all(color: Colors.green, width: 1)),
                    child: Column(
                      children: [
                        const Text('QUICK SUMMARY', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 18)),
                        const SizedBox(height: 15),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            GestureDetector(onTap: () => _protectedNavigation(const AccuracySummaryScreen()), child: _summaryItem(Icons.list_alt, 'accuracy\nsummary')),
                            GestureDetector(onTap: () => _protectedNavigation(const DetectionCountScreen()), child: _summaryItem(Icons.touch_app, 'detection\ncount today')),
                            GestureDetector(onTap: () => _protectedNavigation(const LastDetectedScreen()), child: _summaryItem(Icons.access_time, 'last\ndetected\npest')),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Environmental Stats (Conditional)
                  if (_isConnected) 
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _envStatItem(Icons.thermostat, "28°C", "Temperature"),
                          Container(height: 30, width: 1, color: Colors.green.withOpacity(0.3)),
                          _envStatItem(Icons.water_drop, "65%", "Humidity"),
                        ],
                      ),
                    ),

                  const SizedBox(height: 10),

                  // Aligned Action Buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GestureDetector(onTap: () => _protectedNavigation(const DetectionScreen()), child: _actionButton('Start\nDetection', Icons.biotech)),
                      GestureDetector(onTap: () => _protectedNavigation(const HistoryScreen()), child: _actionButton('View\nHistory', Icons.history_edu),),
                      GestureDetector(onTap: () => _protectedNavigation(const AnalyticsScreen()), child: _actionButton('Analytics', Icons.insights)),
                    ],
                  ),

                  const SizedBox(height: 30),

                  // --- TYPEWRITER "DO YOU KNOW?" SECTION ---
                  Container(
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(30), border: Border.all(color: Colors.green, width: 1)),
                    child: Column(
                      children: [
                        const Center(child: Text('Do You Know?', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 18))),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            ClipOval(child: Image.asset('assets/mosquito.png', width: 80, height: 80, fit: BoxFit.cover, errorBuilder: (context, error, stackTrace) => const Icon(Icons.bug_report, size: 40, color: Colors.green))),
                            const SizedBox(width: 15),
                            Expanded(
                              child: SizedBox(
                                height: 60, // Fixed height to prevent UI "jumping" during typing
                                child: AnimatedTextKit(
                                  key: ValueKey(_currentFact), // Restart animation when fact changes
                                  animatedTexts: [
                                    TypewriterAnimatedText(
                                      _currentFact,
                                      textStyle: const TextStyle(color: Colors.green, fontSize: 13),
                                      speed: const Duration(milliseconds: 50),
                                    ),
                                  ],
                                  totalRepeatCount: 1,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 100), 
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).padding.bottom + 10, // Dynamic padding based on phone type
          left: 20, 
          right: 20
        ),
        child: Container(
          height: 65,
          decoration: BoxDecoration(
            color: Colors.green,
            borderRadius: BorderRadius.circular(35),
            boxShadow: [
              BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 5))
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              IconButton(icon: const Icon(Icons.home, color: Colors.white, size: 30), onPressed: () {}),
                  IconButton(icon: const Icon(Icons.settings, color: Colors.white, size: 30), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => SettingsScreen(isConnected: _isConnected, deviceName: _deviceName)))),
                  IconButton(icon: const Icon(Icons.history, color: Colors.white, size: 30), onPressed: () => _protectedNavigation(const HistoryScreen())),
                  IconButton(icon: const Icon(Icons.person, color: Colors.white, size: 30), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ProfileScreen()))),
                  IconButton(icon: const Icon(Icons.smart_toy_outlined, color: Colors.white, size: 30), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const PestChatbotScreen()))),
              // ... your IconButtons
            ],
          ),
        ),
      ),
    );
  }
}