import 'dart:math'; // Required for Random()
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart'; 
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'package:animated_text_kit/animated_text_kit.dart'; 

import 'detection_screen.dart'; 
import 'history_screen.dart';
import 'analytics_screen.dart';
import 'settings_screen.dart';
import 'profile_screen.dart';
import 'accuracy_summary_screen.dart';
import 'detection_count_screen.dart';
import 'last_detected_screen.dart';
import 'pest_chatbot_screen.dart';
import 'device_setup_screen.dart';

class UserDashboard extends StatefulWidget {
  const UserDashboard({super.key});

  @override
  State<UserDashboard> createState() => _UserDashboardState();
}

class _UserDashboardState extends State<UserDashboard> {
  bool _isLive = false; 
  final String _deviceName = "WingTrace v1";
  final User? _user = FirebaseAuth.instance.currentUser;
  Timer? _factTimer;

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

    _factTimer = Timer.periodic(const Duration(seconds: 20), (timer) {
      if (mounted) {
        setState(() { _currentFact = (_pestFacts..shuffle()).first; });
      }
    });
  }

  @override
  void dispose() {
    _factTimer?.cancel();
    super.dispose();
  }

  // --- LOGIC ---

  // Helper to pick a random image from your 8 assets
  String _getRandomGhibliAsset() {
    int index = Random().nextInt(8) + 1; // Generates 1 to 8
    return 'assets/profile_pics/p$index.png';
  }

  // Logic to save the random choice to Firestore if the user doesn't have one yet
  Future<void> _assignDefaultProfilePic() async {
    if (_user == null) return;
    String randomPic = _getRandomGhibliAsset();
    await FirebaseFirestore.instance.collection('users').doc(_user!.uid).update({
      'profile_pic': randomPic,
    });
  }

  void _handleConnectTap(bool hasSetup) {
    if (!hasSetup) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const DeviceSetupScreen()));
    } else {
      _showConnectionDialog();
    }
  }

  void _showConnectionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return FutureBuilder(
          future: Future.delayed(const Duration(seconds: 3)), 
          builder: (context, snapshot) {
            bool isFound = snapshot.connectionState == ConnectionState.done;
            return Dialog(
              backgroundColor: Colors.green.withOpacity(0.9),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!isFound) ...[
                      const CircularProgressIndicator(color: Colors.white),
                      const SizedBox(height: 20),
                      const Text("Searching for device...", style: TextStyle(color: Colors.white)),
                    ] else ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.asset(
                          'assets/device_image.png',
                          width: 150, height: 150, fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => const Icon(Icons.developer_board, size: 50, color: Colors.grey),
                        ),
                      ),
                      const SizedBox(height: 15),
                      Text("$_deviceName Ready", style: const TextStyle(color: Colors.white, fontSize: 18)),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: () {
                          setState(() => _isLive = true);
                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.green),
                        child: const Text("GO LIVE"),
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
  }

  void _protectedNavigation(Widget screen) {
    if (_isLive) {
      Navigator.push(context, MaterialPageRoute(builder: (context) => screen));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please connect your WingTrace device first."), backgroundColor: Colors.redAccent)
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDFBE7),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(_user?.uid).snapshots(),
        builder: (context, snapshot) {
          bool hasSetup = false;
          String name = "Guest User";
          String profilePic = ""; // Default empty

          if (snapshot.hasData && snapshot.data!.exists) {
            final data = snapshot.data!.data() as Map<String, dynamic>;
            hasSetup = data['hasCompletedSetup'] ?? false;
            name = data['name'] ?? "WingTrace User";
            
            // Random assignment logic
            if (data.containsKey('profile_pic') && data['profile_pic'] != null) {
              profilePic = data['profile_pic'];
            } else {
              // If field missing, assign one in the background
              _assignDefaultProfilePic();
            }

            if (!hasSetup && _isLive) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                setState(() => _isLive = false);
              });
            }
          }

          return SingleChildScrollView(
            child: Column(
              children: [
                _buildHeader(name, profilePic),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      Align(
                        alignment: Alignment.centerRight,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: ElevatedButton(
                            onPressed: () => _handleConnectTap(hasSetup),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _isLive ? Colors.transparent : Colors.red,
                              elevation: _isLive ? 0 : 2,
                              shape: const StadiumBorder(),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _isLive ? 'LIVE' : (hasSetup ? 'connect' : 'setup device'),
                                  style: TextStyle(color: _isLive ? Colors.red : Colors.white, fontWeight: FontWeight.bold),
                                ),
                                if (_isLive) ...[const SizedBox(width: 5), const Icon(Icons.fiber_manual_record, color: Colors.red, size: 12)],
                              ],
                            ),
                          ),
                        ),
                      ),
                      
                      _buildSummarySection(),

                      if (_isLive) _buildEnvStats(),

                      const SizedBox(height: 10),
                      _buildActionButtons(),
                      const SizedBox(height: 30),
                      _buildDoYouKnowSection(),
                      const SizedBox(height: 100), 
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  // --- SUB-WIDGETS ---

  Widget _buildHeader(String name, String profilePicAsset) {
    return Stack(
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
              CircleAvatar(
                radius: 45, 
                backgroundColor: Colors.white, 
                child: CircleAvatar(
                  radius: 42,
                  backgroundColor: Colors.grey[200],
                  // Logic: If Firestore hasn't updated yet, show a generic icon, otherwise show the Ghibli asset
                  backgroundImage: profilePicAsset.isNotEmpty 
                    ? AssetImage(profilePicAsset) 
                    : null,
                  child: profilePicAsset.isEmpty 
                    ? const Icon(Icons.person, size: 50, color: Colors.grey) 
                    : null,
                ),
              ),
              const SizedBox(height: 10),
              Text(name, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSummarySection() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 20),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(30), border: Border.all(color: Colors.green, width: 1)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _summaryItem(Icons.list_alt, 'accuracy\nsummary', const AccuracySummaryScreen()),
          _summaryItem(Icons.touch_app, 'detection\ncount', const DetectionCountScreen()),
          _summaryItem(Icons.access_time, 'last\ndetected', const LastDetectedScreen()),
        ],
      ),
    );
  }

  Widget _buildEnvStats() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 15),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _envStatItem(Icons.thermostat, "28°C", "Temperature"),
          Container(height: 30, width: 1, color: Colors.green.withOpacity(0.3)),
          _envStatItem(Icons.water_drop, "65%", "Humidity"),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _actionButton('Start\nDetection', Icons.biotech, const DetectionScreen()),
        _actionButton('View\nHistory', Icons.history_edu, const HistoryScreen()),
        _actionButton('Analytics', Icons.insights, const AnalyticsScreen()),
      ],
    );
  }

  Widget _buildDoYouKnowSection() {
    return Container(
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
                  height: 60, 
                  child: AnimatedTextKit(
                    key: ValueKey(_currentFact), 
                    animatedTexts: [
                      TypewriterAnimatedText(_currentFact, textStyle: const TextStyle(color: Colors.green, fontSize: 13), speed: const Duration(milliseconds: 50)),
                    ],
                    totalRepeatCount: 1,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNav() {
    return SafeArea(
      child: Container(
        height: 70,
        margin: const EdgeInsets.fromLTRB(15, 0, 15, 10), 
        decoration: BoxDecoration(color: Colors.green, borderRadius: BorderRadius.circular(30)),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            IconButton(icon: const Icon(Icons.home, color: Colors.white, size: 30), onPressed: () {}),
            IconButton(icon: const Icon(Icons.settings, color: Colors.white, size: 30), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => SettingsScreen(isConnected: _isLive, deviceName: _deviceName)))),
            IconButton(icon: const Icon(Icons.person, color: Colors.white, size: 30), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ProfileScreen()))),
            IconButton(icon: const Icon(Icons.smart_toy_outlined, color: Colors.white, size: 30), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const PestChatbotScreen()))),
          ],
        ),
      ),
    );
  }

  Widget _envStatItem(IconData icon, String value, String label) {
    return Row(
      children: [
        Icon(icon, color: Colors.green, size: 32),
        const SizedBox(width: 8),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          Text(label, style: const TextStyle(color: Colors.green, fontSize: 12)),
        ]),
      ],
    );
  }

  Widget _summaryItem(IconData icon, String label, Widget screen) {
    return GestureDetector(
      onTap: () => _protectedNavigation(screen),
      child: Column(children: [Icon(icon, color: Colors.grey[700], size: 35), Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 10, color: Colors.green))]),
    );
  }

  Widget _actionButton(String label, IconData icon, Widget screen) {
    return GestureDetector(
      onTap: () => _protectedNavigation(screen),
      child: Column(children: [
        Container(width: 70, height: 70, decoration: BoxDecoration(borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.green, width: 2)), child: Icon(icon, color: Colors.green, size: 35)),
        const SizedBox(height: 5),
        Text(label, textAlign: TextAlign.center, style: const TextStyle(color: Colors.green, fontSize: 12)),
      ]),
    );
  }
}