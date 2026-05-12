import 'dart:math';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart'; // 🔹 Required for weather stats
import 'package:firebase_core/firebase_core.dart';
import 'dart:convert';
import 'dart:async';
import 'package:animated_text_kit/animated_text_kit.dart';
import 'package:http/http.dart' as http;

// Screen Imports
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
import 'audio_detection_screen.dart';
import 'community_feed_screen.dart';

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

  // Realtime Database Reference
  final DatabaseReference _dbRef = FirebaseDatabase.instanceFor(
    app: Firebase.app(),
    databaseURL: 'https://wingtrace-ead16-default-rtdb.firebaseio.com',
  ).ref();
  String? _realDeviceId; // Fetched from Firestore

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
        setState(() {
          _currentFact = (_pestFacts..shuffle()).first;
        });
      }
    });
  }

  @override
  void dispose() {
    _factTimer?.cancel();
    super.dispose();
  }

  // --- LOGIC ---

  String _getRandomGhibliAsset() {
    int index = Random().nextInt(8) + 1;
    return 'assets/profile_pics/p$index.png';
  }

  Future<void> _assignDefaultProfilePic() async {
    if (_user == null) return;
    String randomPic = _getRandomGhibliAsset();
    await FirebaseFirestore.instance.collection('users').doc(_user!.uid).update({
      'profile_pic': randomPic,
    });
  }

  Future<void> _handleConnectTap(bool hasSetup) async {
    if (!hasSetup) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const DeviceSetupScreen()));
      return;
    }

    if (_isLive) {
      bool? confirm = await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text("Disconnect Device?"),
          content: const Text("This will stop live monitoring until the device reboots."),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("CANCEL")),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text("DISCONNECT", style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      );

      if (confirm == true) {
        final resp = await http.post(
          Uri.parse("https://wingtrace.onrender.com/disconnect"),
          headers: {"Content-Type": "application/json"},
          body: jsonEncode({
            "deviceId": _realDeviceId ?? "WT12345678",
            "userId": _user?.uid
          }),
        );
        if (resp.statusCode == 200) {
          setState(() => _isLive = false);
        }
      }
    } else {
      _showConnectionDialog();
    }
  }

  void _showSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
      );
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
                        onPressed: () async {
                          // 1. Local UI feedback
                          _showSnackBar("Establishing secure link...");

                          try {
                            // 2. Call your server's connect endpoint
                            final response = await http.post(
                              Uri.parse("https://wingtrace.onrender.com/connect"),
                              headers: {"Content-Type": "application/json"},
                              body: jsonEncode({
                                "deviceId": _realDeviceId ?? "WT12345678",
                                "userId": _user?.uid,
                                "timestamp": DateTime.now().millisecondsSinceEpoch ~/ 1000,
                              }),
                            ).timeout(const Duration(seconds: 15));

                            if (response.statusCode == 200) {
                              // 3. Success: Update state and close dialog
                              setState(() => _isLive = true);
                              if (mounted) Navigator.pop(context);
                              _showSnackBar("WingTrace is now Live!");
                            } else {
                              // Handle server-side errors (e.g., Device busy or offline)
                              final errorMsg = jsonDecode(response.body)['error'] ?? "Unknown Error";
                              _showSnackBar("Connection Failed: $errorMsg");
                            }
                          } catch (e) {
                            // Handle network or timeout errors
                            _showSnackBar("Network Error: Check your internet connection.");
                            debugPrint("Connect Error: $e");
                          }
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
          String profilePic = "";
          String? communityId;

          if (snapshot.hasData && snapshot.data!.exists) {
            final data = snapshot.data!.data() as Map<String, dynamic>;
            hasSetup = data['hasCompletedSetup'] ?? false;
            name = data['name'] ?? "WingTrace User";
            
            // 🔹 Fetch real Device ID from Firestore
            if (data.containsKey('devices') && (data['devices'] as List).isNotEmpty) {
              _realDeviceId = data['devices'][0];
            }

            if (data.containsKey('profile_pic') && data['profile_pic'] != null) {
              profilePic = data['profile_pic'];
            } else {
              _assignDefaultProfilePic();
            }

            communityId = data['communityID']?.toString() ?? data['communityId']?.toString();

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
                      // 🔹 Connect Button
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

                      _buildCommunitySection(communityId),

                      // 🔹 Real-time Weather Stats (RTDB)
                      if (_isLive && _realDeviceId != null) _buildRTDBWeather(_realDeviceId!),

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

  // 🔹 New Widget: Listen to RTDB weather node
  // Widget _buildRTDBWeather(String deviceId) {
  //   return StreamBuilder<DatabaseEvent>(
  //     stream: _dbRef.child("devices/$deviceId/weather").onValue,
  //     builder: (context, snapshot) {
  //       String temp = "--";
  //       String hum = "--";

  //       if (snapshot.hasData && snapshot.data!.snapshot.value != null) {
  //         final data = Map<dynamic, dynamic>.from(snapshot.data!.snapshot.value as Map);
  //         temp = data['temperature']?.toString() ?? "--";
  //         hum = data['humidity']?.toString() ?? "--";
  //       }

  //       return Padding(
  //         padding: const EdgeInsets.symmetric(vertical: 15),
  //         child: Row(
  //           mainAxisAlignment: MainAxisAlignment.spaceEvenly,
  //           children: [
  //             _envStatItem(Icons.thermostat, "$temp°C", "Temperature"),
  //             Container(height: 30, width: 1, color: Colors.green.withOpacity(0.3)),
  //             _envStatItem(Icons.water_drop, "$hum%", "Humidity"),
  //           ],
  //         ),
  //       );
  //     },
  //   );
  // }
  Widget _buildRTDBWeather(String deviceId) {
  // Use the exact path from your screenshot: devices/WT12345678/weather
    return StreamBuilder<DatabaseEvent>(
      stream: _dbRef.child("devices/$deviceId/weather").onValue,
      builder: (context, snapshot) {
        // 1. Check for basic connection/stream errors
        if (snapshot.hasError) {
          return _envStatItem(Icons.error_outline, "Error", "Stream Failed");
        }

        // 2. While waiting for the very first bit of data
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _envStatItem(Icons.sync, "...", "Connecting");
        }

        // 3. Process the data
        String temp = "--";
        String hum = "--";

        if (snapshot.hasData && snapshot.data!.snapshot.value != null) {
          try {
            // Cast the value to a Map
            final data = Map<dynamic, dynamic>.from(snapshot.data!.snapshot.value as Map);
            
            // Verify keys match your RTDB: 'temperature' and 'humidity'
            temp = data['temperature']?.toString() ?? "--";
            hum = data['humidity']?.toString() ?? "--";
          } catch (e) {
            debugPrint("Data Parsing Error: $e");
          }
        } else {
          // This means the path 'devices/$deviceId/weather' exists but is empty
          return _envStatItem(Icons.cloud_off, "No Data", "Check Hardware");
        }

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 15),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _envStatItem(Icons.thermostat, "$temp°C", "Temperature"),
              Container(height: 30, width: 1, color: Colors.green.withOpacity(0.3)),
              _envStatItem(Icons.water_drop, "$hum%", "Humidity"),
            ],
          ),
        );
      },
    );
  }

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
                  backgroundImage: profilePicAsset.isNotEmpty ? AssetImage(profilePicAsset) : null,
                  child: profilePicAsset.isEmpty ? const Icon(Icons.person, size: 50, color: Colors.grey) : null,
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

  Widget _buildCommunitySection(String? communityId) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.green, width: 1),
        color: Colors.white,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.people_alt_outlined, color: Colors.green),
              const SizedBox(width: 8),
              const Text(
                'Community Updates',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const Spacer(),
              TextButton(
                onPressed: communityId == null || communityId.isEmpty
                    ? null
                    : () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const CommunityFeedScreen()),
                        ),
                child: const Text('Open Feed'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (communityId == null || communityId.isEmpty)
            const Text(
              'No community linked to your account yet.',
              style: TextStyle(color: Colors.grey),
            )
          else ...[
            _buildLatestCommunityPost(communityId),
            const SizedBox(height: 12),
            _buildAssignedOfficersCard(communityId),
          ],
          const SizedBox(height: 6),
          const Text(
            'Only verified detections are shown. Exact house location is never shared.',
            style: TextStyle(color: Colors.grey, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildLatestCommunityPost(String communityId) {
    final query = FirebaseFirestore.instance
      .collection('communities')
      .doc(communityId)
      .collection('posts')
      .orderBy('timestamp', descending: true)
      .limit(1);

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: LinearProgressIndicator(),
          );
        }

        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return const Text('No verified posts yet.', style: TextStyle(color: Colors.grey));
        }

        final data = docs.first.data() as Map<String, dynamic>;
        final pestType = data['pestType']?.toString() ?? 'Unknown Pest';
        final timestamp = data['timestamp'];

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.08),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.green),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      pestType,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(_timeAgoFromTimestamp(timestamp), style: const TextStyle(color: Colors.grey)),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAssignedOfficersCard(String communityId) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('communities').doc(communityId).snapshots(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data() as Map<String, dynamic>?;
        final officers = data?['officers'] is Map
            ? Map<String, dynamic>.from(data?['officers'])
            : <String, dynamic>{};

        if (officers.isEmpty) {
          return const Text('No assigned officers yet.', style: TextStyle(color: Colors.grey));
        }

        final officerIds = officers.values.map((value) => value.toString()).toList();

        return FutureBuilder<List<DocumentSnapshot>>(
          future: Future.wait(
            officerIds.map((id) => FirebaseFirestore.instance.collection('users').doc(id).get()),
          ),
          builder: (context, officerSnapshot) {
            if (officerSnapshot.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: LinearProgressIndicator(),
              );
            }

            final officerDocs = officerSnapshot.data ?? [];
            return Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Assigned Officers', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    ...officerDocs.map((doc) {
                      final officerData = doc.data() as Map<String, dynamic>?;
                      final name = officerData?['name']?.toString() ?? doc.id;
                      final phone = officerData?['phoneno']?.toString();
                      final type = officerData?['officerType']?.toString();
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            const Icon(Icons.badge_outlined, size: 18, color: Colors.green),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
                                  if (type != null && type.isNotEmpty)
                                    Text(type, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                                  if (phone != null && phone.isNotEmpty)
                                    Text(phone, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        // First Row: Image and Audio Detection
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _actionButton('Image\nDetection', Icons.camera_alt, const DetectionScreen(), requiresDevice: false),
            _actionButton('Audio\nDetection', Icons.mic, const AudioDetectionScreen()),
          ],
        ),
        const SizedBox(height: 20), // Spacing between the two rows
        // Second Row: History and Analytics
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _actionButton('View\nHistory', Icons.history_edu, const HistoryScreen(), requiresDevice: false),
            _actionButton('Analytics', Icons.insights, const AnalyticsScreen(), requiresDevice: false),
          ],
        ),
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

  String _timeAgoFromTimestamp(dynamic timestamp) {
    DateTime? time;

    if (timestamp is Timestamp) {
      time = timestamp.toDate();
    } else if (timestamp is String) {
      time = DateTime.tryParse(timestamp);
    }

    if (time == null) return "Just now";

    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return "Just now";
    if (diff.inMinutes < 60) return "${diff.inMinutes} mins ago";
    if (diff.inHours < 24) return "${diff.inHours} hours ago";
    if (diff.inDays < 7) return "${diff.inDays} days ago";

    return "${time.day}/${time.month}/${time.year}";
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
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => screen)),
      child: Column(children: [Icon(icon, color: Colors.grey[700], size: 35), Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 10, color: Colors.green))]),
    );
  }

  Widget _actionButton(String label, IconData icon, Widget screen, {bool requiresDevice = true}) {
    return GestureDetector(
      onTap: () => requiresDevice
          ? _protectedNavigation(screen)
          : Navigator.push(context, MaterialPageRoute(builder: (_) => screen)),
      child: Column(children: [
        Container(width: 70, height: 70, decoration: BoxDecoration(borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.green, width: 2)), child: Icon(icon, color: Colors.green, size: 35)),
        const SizedBox(height: 5),
        Text(label, textAlign: TextAlign.center, style: const TextStyle(color: Colors.green, fontSize: 12)),
      ]),
    );
  }
}