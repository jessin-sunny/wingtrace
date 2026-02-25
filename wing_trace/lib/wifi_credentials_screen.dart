import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_database/firebase_database.dart'; // Ensure this is in pubspec.yaml
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

  // The local IP of the hardware in AP mode
  final String _hardwareApUrl = "http://192.168.4.1/setup";
  final String _deviceId = "WT12345678"; // Dynamic ID recommended

  Future<void> _updateWifi() async {
    if (_ssidController.text.isEmpty || _passController.text.isEmpty) {
      _showSnackBar("Please enter both SSID and Password");
      return;
    }

    // Capture start time in seconds (matching lastSeen format)
    final int resetStartTimeSeconds = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    setState(() => _isSending = true);

    try {
      // Step 1: Send credentials to ESP32
      final response = await http.post(
        Uri.parse(_hardwareApUrl),
        body: {
          'ssid': _ssidController.text.trim(),
          'pass': _passController.text.trim(),
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        // Step 2: Listen directly to Realtime DB instead of polling a server function
        _listenToDeviceStatus(resetStartTimeSeconds);
      }
    } catch (e) {
      setState(() => _isSending = false);
      _showSnackBar("Error: Connection lost. Ensure you are on WingTrace Wi-Fi.");
    }
  }

  void _listenToDeviceStatus(int resetStartTimeSeconds) {
    _showWaitingDialog();

    // Step 3: Set a 2-minute timeout timer
    _timeoutTimer = Timer(const Duration(minutes: 2), () {
      _stopListening();
      if (mounted) {
        Navigator.pop(context); // Close waiting dialog
        _showErrorDialog("Timeout: Device failed to reconnect. Check Wi-Fi details.");
        setState(() => _isSending = false);
      }
    });

    // Step 4: Listen for changes in the 'status' node
    _statusSubscription = FirebaseDatabase.instance
        .ref("devices/$_deviceId/status")
        .onValue
        .listen((event) {
      final data = event.snapshot.value as Map<dynamic, dynamic>?;

      if (data != null) {
        bool isOnline = data['isOnline'] ?? false;
        int lastSeen = data['lastSeen'] ?? 0;

        // Step 5: Verify reconnection AFTER the reset started
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
            CircularProgressIndicator(),
            SizedBox(height: 20),
            Text("WingTrace is reconnecting...", style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 10),
            Text("Checking Realtime Database for device status.", textAlign: TextAlign.center),
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
        title: const Icon(Icons.check_circle, color: Colors.green, size: 50),
        content: const Text("Successfully Reconnected!\nYour device is now online.", textAlign: TextAlign.center),
        actions: [
          TextButton(
            onPressed: () => Navigator.popUntil(context, (route) => route.isFirst),
            child: const Text("DONE"),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String msg) => showDialog(
    context: context,
    builder: (ctx) => AlertDialog(title: const Text("Error"), content: Text(msg), actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("OK"))])
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
      appBar: AppBar(title: const Text("Configure Wi-Fi"), backgroundColor: Colors.blue, foregroundColor: Colors.white),
      body: Padding(
        padding: const EdgeInsets.all(25.0),
        child: Column(
          children: [
            TextField(
              controller: _ssidController, 
              decoration: const InputDecoration(labelText: "Home Wi-Fi SSID", border: OutlineInputBorder(), prefixIcon: Icon(Icons.wifi))
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _passController, 
              obscureText: true, 
              decoration: const InputDecoration(labelText: "Password", border: OutlineInputBorder(), prefixIcon: Icon(Icons.lock))
            ),
            const SizedBox(height: 40),
            _isSending 
              ? const CircularProgressIndicator() 
              : ElevatedButton(
                  onPressed: _updateWifi,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, minimumSize: const Size(double.infinity, 55)),
                  child: const Text("CONNECT DEVICE", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
          ],
        ),
      ),
    );
  }
}