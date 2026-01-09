import 'package:flutter/material.dart';
import 'detection_screen.dart'; 
import 'history_screen.dart';
import 'analytics_screen.dart';
import 'settings_screen.dart';
import 'profile_screen.dart';
import 'accuracy_summary_screen.dart';
import 'detection_count_screen.dart';
import 'last_detected_screen.dart';

class UserDashboard extends StatefulWidget {
  const UserDashboard({super.key});

  @override
  State<UserDashboard> createState() => _UserDashboardState();
}

class _UserDashboardState extends State<UserDashboard> {
  // 1. Connection Status State
  bool _isConnected = false;

  // 2. "Do You Know?" Logic - Randomized Facts
  final List<String> _pestFacts = [
    "Only female mosquitoes bite; they need blood protein for their eggs.",
    "Mosquitoes can detect CO2 from your breath from 75 feet away.",
    "A full moon can increase mosquito activity by up to 500%!",
    "Mosquitoes are the world's deadliest animals, causing 1 million deaths yearly.",
    "Mosquitoes can breed in as little as a teaspoon of stagnant water."
  ];
  late String _currentFact;

  @override
  void initState() {
    super.initState();
    // Selects a random fact when the screen is first loaded
    _currentFact = (_pestFacts..shuffle()).first;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDFBE7),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Curved Green Header
            Stack(
              children: [
                Container(
                  height: 200,
                  decoration: const BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(100),
                      bottomRight: Radius.circular(100),
                    ),
                  ),
                ),
                Positioned(
                  top: 60,
                  left: 0,
                  right: 0,
                  child: Column(
                    children: [
                      const CircleAvatar(
                        radius: 40,
                        backgroundColor: Colors.white,
                        child: Icon(Icons.person, size: 50, color: Colors.grey),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'username',
                        style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
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
                  // DYNAMIC CONNECT/LIVE BUTTON
                  Align(
                    alignment: Alignment.centerRight,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _isConnected = !_isConnected;
                          });
                          if (_isConnected) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("Hardware Connected Successfully!")),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _isConnected ? Colors.red : Colors.grey[700],
                          shape: const StadiumBorder(),
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _isConnected ? 'LIVE' : 'connect',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                            if (_isConnected) ...[
                              const SizedBox(width: 5),
                              const Icon(Icons.fiber_manual_record, color: Colors.white, size: 12),
                            ]
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Quick Summary Card
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 20),
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: Colors.green, width: 1),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'QUICK SUMMARY',
                          style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 18),
                        ),
                        const SizedBox(height: 15),
                        // Inside the Quick Summary Container
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            GestureDetector(
                              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AccuracySummaryScreen())),
                              child: _summaryItem(Icons.list_alt, 'accuracy\nsummary'),
                            ),
                            GestureDetector(
                              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const DetectionCountScreen())),
                              child: _summaryItem(Icons.touch_app, 'detection\ncount today'),
                            ),
                            GestureDetector(
                              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const LastDetectedScreen())),
                              child: _summaryItem(Icons.access_time, 'last\ndetected\npest'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Square Action Buttons with Navigation
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const DetectionScreen())),
                        child: _actionButton('Start\nDetection', Icons.biotech),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const HistoryScreen())),
                        child: _actionButton('View\nHistory', Icons.history_edu),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AnalyticsScreen())),
                        child: _actionButton('Analytics', Icons.insights),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // DO YOU KNOW? SECTION (Dynamic)
                  Container(
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: Colors.green, width: 1),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Center(
                          child: Text(
                            'Do You Know?',
                            style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 18),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            ClipOval(
                              child: Image.asset('assets/mosquito.png', width: 80, height: 80,fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => const Icon(Icons.bug_report, size: 40, color: Colors.green),
                              ),
                            ),
                            const SizedBox(width: 15),
                            Expanded(
                              child: Text(
                                _currentFact, // DYNAMIC FACT
                                style: const TextStyle(color: Colors.green, fontSize: 13),
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
      // Custom Navigation Bar
      bottomNavigationBar: Container(
        height: 70,
        decoration: const BoxDecoration(
          color: Colors.green,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(30),
            topRight: Radius.circular(30),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            // Home Icon (Current Dashboard)
            IconButton(
              icon: const Icon(Icons.home, color: Colors.white, size: 30),
              onPressed: () { /* Already here */ },
            ),
            // Settings Icon
            IconButton(
              icon: const Icon(Icons.settings, color: Colors.white, size: 30),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SettingsScreen())),
            ),
            // History (Time) Icon
            IconButton(
              icon: const Icon(Icons.history, color: Colors.white, size: 30),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const HistoryScreen())),
            ),
            // Profile Icon
            IconButton(
              icon: const Icon(Icons.person, color: Colors.white, size: 30),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ProfileScreen())),
            ),
          ],
        ),
      ),
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
}