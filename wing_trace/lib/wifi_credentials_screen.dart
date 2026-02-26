import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Required for UID
import 'dart:convert'; // 🔹 FIXED: Required for jsonEncode
import 'dart:async';

class WifiCredentialsScreen extends StatefulWidget {
  const WifiCredentialsScreen({super.key});

  @override
  State<WifiCredentialsScreen> createState() => _WifiCredentialsScreenState();
}

class _WifiCredentialsScreenState extends State<WifiCredentialsScreen> {
  final TextEditingController _ssidController = TextEditingController();
  final TextEditingController _passController = TextEditingController();
  bool _isSending = false;
  StreamSubscription<DatabaseEvent>? _statusSubscription;
  Timer? _timeoutTimer;

  // Configuration
  final String _hardwareApUrl = "http://192.168.4.1/setup";
  final String _deviceId = "WT12345678"; // Ensure this matches your RTDB node

  Future<void> _updateWifi() async {
    final String ssid = _ssidController.text.trim();
    final String password = _passController.text.trim();

    if (ssid.isEmpty || password.isEmpty) {
      _showSnackBar("Please enter both SSID and Password");
      return;
    }

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      _showSnackBar("User not authenticated.");
      return;
    }

    // Capture start time in seconds (matching your RTDB lastSeen format)
    final int resetStartTimeSeconds = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    setState(() => _isSending = true);

    try {
      // 🔹 Step 1: Send credentials as JSON to ESP32
      final response = await http.post(
        Uri.parse(_hardwareApUrl),
        headers: {
          "Content-Type": "application/json",
        },
        body: jsonEncode({
          "ssid": ssid,
          "password": password,
          "userid": uid,
        }),
      ).timeout(const Duration(seconds: 12)); // Slightly longer timeout for hardware processing

      if (response.statusCode == 200) {
        // 🔹 Step 2: Listen for the device to come back online in Firebase
        _listenToDeviceStatus(resetStartTimeSeconds);
      } else {
        throw Exception("Hardware error: ${response.statusCode}");
      }
    } catch (e) {
      setState(() => _isSending = false);
      _showSnackBar("Error: Could not reach WingTrace. Ensure you are connected to the device Wi-Fi.");
      debugPrint("Setup Error: $e");
    }
  }

  void _listenToDeviceStatus(int resetStartTimeSeconds) {
    _showWaitingDialog();

    // Step 3: 2-minute safety timeout
    _timeoutTimer = Timer(const Duration(minutes: 2), () {
      _stopListening();
      if (mounted) {
        Navigator.pop(context); // Close waiting dialog
        _showErrorDialog("Timeout: Device failed to reconnect. Please check your Wi-Fi credentials and try again.");
        setState(() => _isSending = false);
      }
    });

    // Step 4: Watch the 'status' node in Realtime Database
    _statusSubscription = FirebaseDatabase.instance
        .ref("devices/$_deviceId/status")
        .onValue
        .listen((event) {
      final data = event.snapshot.value as Map<dynamic, dynamic>?;

      if (data != null) {
        bool isOnline = data['isOnline'] ?? false;
        int lastSeen = data['lastSeen'] ?? 0;

        // Step 5: SUCCESS if device is online AND was seen AFTER we sent credentials
        if (isOnline && lastSeen > resetStartTimeSeconds) {
          _stopListening();
          if (mounted) {
            Navigator.pop(context); // Close waiting dialog
            _showSuccessDialog();
          }
        }
      }
    });
  }

  void _stopListening() {
    _statusSubscription?.cancel();
    _timeoutTimer?.cancel();
  }

  // --- UI Components ---

  void _showWaitingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Colors.blue),
            SizedBox(height: 20),
            Text("WingTrace is reconnecting...", style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 10),
            Text("The device is restarting to join your home network. Do not close this app.", textAlign: TextAlign.center, style: TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Icon(Icons.check_circle, color: Colors.green, size: 60),
        content: const Text("Successfully Connected!\nYour WingTrace device is now online and active.", textAlign: TextAlign.center),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.popUntil(context, (route) => route.isFirst),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text("DONE", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String msg) => showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text("Setup Failed"),
      content: Text(msg),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("OK"))]
    )
  );

  void _showSnackBar(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  @override
  void dispose() {
    _stopListening();
    _ssidController.dispose();
    _passController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDFBE7),
      appBar: AppBar(
        title: const Text("Configure Wi-Fi"), 
        backgroundColor: Colors.blue, 
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(25.0),
        child: Column(
          children: [
            const Icon(Icons.wifi, size: 80, color: Colors.blue),
            const SizedBox(height: 20),
            const Text(
              "Network Provisioning",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            const Text(
              "Enter the credentials for the local Wi-Fi you want your device to use.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 30),
            TextField(
              controller: _ssidController, 
              decoration: const InputDecoration(
                labelText: "Wi-Fi Name (SSID)", 
                border: OutlineInputBorder(), 
                prefixIcon: Icon(Icons.wifi)
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _passController, 
              obscureText: true, 
              decoration: const InputDecoration(
                labelText: "Wi-Fi Password", 
                border: OutlineInputBorder(), 
                prefixIcon: Icon(Icons.lock)
              ),
            ),
            const SizedBox(height: 40),
            _isSending 
              ? const CircularProgressIndicator() 
              : ElevatedButton(
                  onPressed: _updateWifi,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue, 
                    minimumSize: const Size(double.infinity, 55),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text("CONNECT DEVICE", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                ),
          ],
        ),
      ),
    );
  }
}