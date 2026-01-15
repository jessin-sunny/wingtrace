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
  
  // Your Railway Server URL
  final String serverUrl = "https://wingtrace-production.up.railway.app";

  final TextEditingController _ssidController = TextEditingController();
  final TextEditingController _passController = TextEditingController();

  String? _detectedDeviceId;
  String? _detectedDeviceName;
  Timer? _pollingTimer;

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _ssidController.dispose();
    _passController.dispose();
    super.dispose();
  }

  // --- STEP 1: Verify Hardware WiFi Connection ---
  Future<void> _checkWifiConnection() async {
    setState(() => _isLoading = true);

    Map<Permission, PermissionStatus> statuses = await [
      Permission.locationWhenInUse,
      Permission.nearbyWifiDevices,
    ].request();

    if (statuses[Permission.locationWhenInUse]!.isGranted) {
      var serviceStatus = await Permission.location.serviceStatus;
      
      if (serviceStatus.isEnabled) {
        String? wifiName = await _networkInfo.getWifiName();
        String cleanSsid = wifiName?.replaceAll('"', '') ?? "";

        // Matches any SSID starting with "WingTrace"
        if (cleanSsid.toLowerCase().startsWith("wingtrace")) {
          setState(() {
            _detectedDeviceName = cleanSsid;
            _currentStep = 1;
          });
        } else {
          _showError("Connected to: $cleanSsid. Please switch to a 'WingTrace' WiFi.");
        }
      } else {
        _showError("Please enable GPS/Location in your system tray.");
      }
    } else {
      _showError("Permission denied. Please enable it in Settings.");
      if (statuses[Permission.locationWhenInUse]!.isPermanentlyDenied) {
        await openAppSettings();
      }
    }
    setState(() => _isLoading = false);
  }

  // --- STEP 2: Send Internet Credentials to ESP32 ---
  Future<void> _provisionHardware() async {
    if (_ssidController.text.isEmpty || _passController.text.isEmpty) {
      _showError("Please enter WiFi details.");
      return;
    }

    setState(() => _isLoading = true);
    final String? userId = FirebaseAuth.instance.currentUser?.uid;

    try {
      // 1. Send (SSID, Password, UserId) to Device (192.168.4.1)
      final response = await http.post(
        Uri.parse("http://192.168.4.1/save"),
        headers: {"Content-Type": "application/x-www-form-urlencoded"},
        body: {
          "ssid": _ssidController.text.trim(),
          "password": _passController.text.trim(),
          "userid": userId,
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        // Capture the hardcoded DeviceId returned by the ESP32
        final data = jsonDecode(response.body);
        _detectedDeviceId = data['device_id'];
        
        debugPrint("Credentials accepted. Starting server check...");
        _startServerPolling(userId!);
      }
    } catch (e) {
      // Reboot causes connection drop, which is expected.
      debugPrint("ESP32 Rebooting. Starting server polling...");
      _startServerPolling(userId!);
    }
  }

  // --- STEP 3: Poll Railway Server for Success (2 Min Timeout) ---
  void _startServerPolling(String userId) {
    int attempts = 0;
    const int maxAttempts = 24; // 24 * 5 seconds = 120 seconds (2 mins)

    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      attempts++;
      
      if (attempts >= maxAttempts) {
        timer.cancel();
        setState(() => _isLoading = false);
        _showError("Setup timed out. Check hardware connection.");
        return;
      }

      try {
        // Checking if Device has reached Server successfully
        final response = await http.get(Uri.parse("$serverUrl/check-status/$userId"));
        
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data['status'] == "success") {
            timer.cancel();
            _registerToFirebase();
          }
        }
      } catch (e) {
        debugPrint("Polling Railway Server...");
      }
    });
  }

  // --- STEP 4: Finalize Cloud Registration ---
  Future<void> _registerToFirebase() async {
    try {
      String uid = FirebaseAuth.instance.currentUser!.uid;

      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'hasCompletedSetup': true,
        'device_id': _detectedDeviceId ?? "WT-GEN-${DateTime.now().millisecondsSinceEpoch}",
        'device_name': _detectedDeviceName,
        'last_setup': DateTime.now(),
      });

      if (mounted) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const UserDashboard()));
      }
    } catch (e) {
      _showError("Cloud registration failed.");
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
                Text(_currentStep == 1 ? "Waiting for Server response (Up to 2 mins)" : "Connecting...", 
                  textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
              ],
            ),
          )
        : Column(
            children: [
              _buildProgressIndicator(),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(25.0),
                  child: _buildCurrentStepUI(),
                ),
              ),
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
    switch (_currentStep) {
      case 0:
        return _stepLayout(
          icon: Icons.settings_input_component,
          title: "Connect to Hardware",
          desc: "1. Power on WingTrace.\n2. In WiFi Settings, connect to the network starting with 'WingTrace'.",
          btnLabel: "VERIFY CONNECTION",
          onPressed: _checkWifiConnection,
        );
      case 1:
        return SingleChildScrollView(
          child: Column(
            children: [
              const Icon(Icons.wifi_lock, size: 80, color: Colors.green),
              const SizedBox(height: 20),
              const Text("Provision Internet", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const Text("Enter your WiFi details so WingTrace can connect to the cloud.", textAlign: TextAlign.center),
              const SizedBox(height: 30),
              TextField(
                controller: _ssidController, 
                decoration: const InputDecoration(labelText: "WiFi SSID", border: OutlineInputBorder())
              ),
              const SizedBox(height: 15),
              TextField(
                controller: _passController, 
                obscureText: true, 
                decoration: const InputDecoration(labelText: "WiFi Password", border: OutlineInputBorder())
              ),
              const SizedBox(height: 30),
              _fullWidthButton("PROVISION DEVICE", _provisionHardware),
            ],
          ),
        );
      default:
        return const Center(child: CircularProgressIndicator());
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
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green, 
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))
        ),
        child: Text(label, style: const TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }
}