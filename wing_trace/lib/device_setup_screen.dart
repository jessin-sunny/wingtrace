import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:network_info_plus/network_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'user_dashboard.dart';
import 'dart:convert';
import 'dart:async';

class DeviceSetupScreen extends StatefulWidget {
  const DeviceSetupScreen({super.key});

  @override
  State<DeviceSetupScreen> createState() => _DeviceSetupScreenState();
}

class _DeviceSetupScreenState extends State<DeviceSetupScreen> {
  int _currentStep = 0;
  bool _isLoading = false;
  final NetworkInfo _networkInfo = NetworkInfo();
  
  final String serverUrl = "https://wingtrace-production.up.railway.app";
  final TextEditingController _ssidController = TextEditingController();
  final TextEditingController _passController = TextEditingController();

  String? _setupToken;
  StreamSubscription<DocumentSnapshot>? _statusSubscription;

  @override
  void initState() {
    super.initState();
    // 🔹 CALL IMMEDIATELY: Get token while internet is still active
    _fetchSetupToken(isInitial: true); 
  }

  @override
  void dispose() {
    _statusSubscription?.cancel();
    _ssidController.dispose();
    _passController.dispose();
    super.dispose();
  }

  // --- STEP 1: Verify Hardware WiFi Connection ---
  Future<void> _checkWifiConnection() async {
    // 🔹 GUARD: Do not proceed if we don't have a token from the server yet
    if (_setupToken == null) {
      await _fetchSetupToken();
      if (_setupToken == null) {
        _showError("Still waiting for internet to fetch setup token. Please check your connection.");
        return;
      }
    }

    setState(() => _isLoading = true);

    Map<Permission, PermissionStatus> statuses = await [
      Permission.locationWhenInUse,
      Permission.nearbyWifiDevices,
    ].request();

    if (statuses[Permission.locationWhenInUse]!.isGranted) {
      String? wifiName = await _networkInfo.getWifiName();
      String cleanSsid = wifiName?.replaceAll('"', '') ?? "";

      // 🔹 STRICT VERIFICATION: Ensure we are actually on WingTrace
      if (cleanSsid.toLowerCase().startsWith("wingtrace")) {
        setState(() {
          _currentStep = 1; // Advance ONLY if SSID is correct
        });
      } else if (cleanSsid.isEmpty || cleanSsid == "<unknown ssid>") {
        _showError("Could not detect WiFi name. Ensure GPS/Location is ON.");
      } else {
        _showError("Connected to: $cleanSsid. Please switch to 'WingTrace' WiFi.");
      }
    } else {
      _showError("Location/Nearby permissions required.");
    }
    setState(() => _isLoading = false);
  }

  // --- STEP 1.5: Fetch Token from Railway Server ---
  Future<void> _fetchSetupToken({bool isInitial = false}) async {
    final String? userId = FirebaseAuth.instance.currentUser?.uid;
    try {
      final response = await http.post(
        Uri.parse("$serverUrl/startSetup"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"userId": userId}),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _setupToken = data['setupToken'];
        });
        debugPrint("Token fetched: $_setupToken");
      } else if (!isInitial) {
        _showError("Server rejected setup request");
      }
    } catch (e) {
      if (!isInitial) {
        _showError("Failed to reach server. Connect to internet first.");
      }
      debugPrint("Token fetch error: $e");
    }
  }

  // --- STEP 2: Send Credentials + Token to ESP32 ---
  Future<void> _provisionHardware() async {
    if (_ssidController.text.isEmpty || _passController.text.isEmpty) {
      _showError("Please enter WiFi details.");
      return;
    }

    setState(() => _isLoading = true);
    final String? userId = FirebaseAuth.instance.currentUser?.uid;

    try {
      // Send JSON to ESP32 endpoint
      final response = await http.post(
        Uri.parse("http://192.168.4.1/setup"),
        body: jsonEncode({
          "ssid": _ssidController.text.trim(),
          "password": _passController.text.trim(),
          "userid": userId,
          "setupToken": _setupToken,
        }),
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        _listenForCompletion();
      }
    } catch (e) {
      // Expected: connection drops when ESP32 restarts
      _listenForCompletion();
    }
  }

  // --- STEP 3: Monitor Firestore ---
  void _listenForCompletion() {
    if (_setupToken == null) return;

    _statusSubscription = FirebaseFirestore.instance
        .collection('setupSessions')
        .doc(_setupToken!)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists) {
        final data = snapshot.data();
        if (data?['status'] == "USED") {
          _finalizeSetup();
        } else if (data?['status'] == "EXPIRED") {
          _statusSubscription?.cancel();
          setState(() => _isLoading = false);
          _showError("Setup token expired. Please restart.");
        }
      }
    });

    Future.delayed(const Duration(minutes: 2), () {
      if (_isLoading && mounted) {
        _statusSubscription?.cancel();
        setState(() => _isLoading = false);
        _showError("Setup timed out. Check device internet.");
      }
    });
  }

  Future<void> _finalizeSetup() async {
    _statusSubscription?.cancel();
    try {
      String uid = FirebaseAuth.instance.currentUser!.uid;
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'hasCompletedSetup': true,
      });

      if (mounted) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const UserDashboard()));
      }
    } catch (e) {
      _showError("Final sync failed.");
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDFBE7),
      appBar: AppBar(
        title: const Text("Device Setup"),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: _isLoading 
        ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(color: Colors.green),
                const SizedBox(height: 20),
                const Text("Configuring WingTrace...", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                const SizedBox(height: 8),
                Text(_currentStep == 1 ? "Waiting for Device to reach Cloud..." : "Talking to Device...", 
                  textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
              ],
            ),
          )
        : Column(
            children: [
              _buildProgressIndicator(),
              Expanded(child: Padding(padding: const EdgeInsets.all(25.0), child: _buildCurrentStepUI())),
            ],
          ),
    );
  }

  Widget _buildProgressIndicator() {
    return LinearProgressIndicator(
      value: (_currentStep + 1) / 2,
      backgroundColor: Colors.green.withOpacity(0.2),
      valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
    );
  }

  Widget _buildCurrentStepUI() {
    if (_currentStep == 0) {
      return _stepLayout(
        icon: Icons.settings_input_component,
        title: "Connect to Hardware",
        desc: "Power on WingTrace and connect your phone to its WiFi network.",
        btnLabel: "VERIFY CONNECTION",
        onPressed: _checkWifiConnection,
      );
    } else {
      return SingleChildScrollView(
        child: Column(
          children: [
            const Icon(Icons.wifi_lock, size: 80, color: Colors.green),
            const SizedBox(height: 20),
            const Text("Provision Internet", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const Text("Enter your home WiFi details."),
            const SizedBox(height: 30),
            TextField(controller: _ssidController, decoration: const InputDecoration(labelText: "WiFi SSID", border: OutlineInputBorder())),
            const SizedBox(height: 15),
            TextField(controller: _passController, obscureText: true, decoration: const InputDecoration(labelText: "WiFi Password", border: OutlineInputBorder())),
            const SizedBox(height: 30),
            _fullWidthButton("PROVISION DEVICE", _provisionHardware),
          ],
        ),
      );
    }
  }

  Widget _stepLayout({required IconData icon, required String title, required String desc, required String btnLabel, required VoidCallback onPressed}) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 100, color: Colors.green),
        const SizedBox(height: 30),
        Text(title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        const SizedBox(height: 15),
        Text(desc, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, color: Colors.black54)),
        const SizedBox(height: 40),
        _fullWidthButton(btnLabel, onPressed),
      ],
    );
  }

  Widget _fullWidthButton(String label, VoidCallback? onPressed) {
    return SizedBox(
      width: double.infinity,
      height: 55,
      child: ElevatedButton(
        onPressed: _isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(backgroundColor: Colors.green, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
        child: Text(label, style: const TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }
}