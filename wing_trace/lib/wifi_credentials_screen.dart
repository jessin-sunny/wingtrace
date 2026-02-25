import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
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
  Timer? _pollingTimer;
  
  final String _hardwareApUrl = "http://192.168.4.1/setup";
  final String _serverStatusUrl = "https://wingtrace.onrender.com/status"; 

  Future<void> _updateWifi() async {
    if (_ssidController.text.isEmpty || _passController.text.isEmpty) {
      _showSnackBar("Please enter both SSID and Password");
      return;
    }

    // Step 1: Capture start time in milliseconds
    final int resetStartTime = DateTime.now().millisecondsSinceEpoch;
    setState(() => _isSending = true);

    try {
      final response = await http.post(
        Uri.parse(_hardwareApUrl),
        body: {'ssid': _ssidController.text.trim(), 'pass': _passController.text.trim()},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        // Step 2: Begin Polling the backend
        _startPolling(resetStartTime);
      }
    } catch (e) {
      setState(() => _isSending = false);
      _showSnackBar("Error: Connection lost. Ensure you are still on WingTrace Wi-Fi.");
    }
  }

  void _startPolling(int resetStartTime) {
    int elapsed = 0;
    _showWaitingDialog();

    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      elapsed += 3;

      // Step 3: Timeout after 2 minutes
      if (elapsed >= 120) {
        timer.cancel();
        Navigator.pop(context); // Close dialog
        _showErrorDialog("Timeout: Device failed to reconnect. Please check Wi-Fi details.");
        setState(() => _isSending = false);
        return;
      }

      try {
        final res = await http.post(
          Uri.parse(_serverStatusUrl),
          headers: {"Content-Type": "application/json"},
          body: jsonEncode({"deviceId": "WT12345678"}), // Use dynamic ID
        );

        if (res.statusCode == 200) {
          final data = jsonDecode(res.body);
          bool isOnline = data['isOnline'] ?? false;
          int lastSeen = data['lastSeen'] ?? 0;

          // Step 4: Verify lastSeen is AFTER resetStartTime
          if (isOnline && (lastSeen * 1000) > resetStartTime) {
            timer.cancel();
            Navigator.pop(context); // Close dialog
            _showSuccessDialog();
          }
        }
      } catch (e) {
        debugPrint("Searching for device..."); 
      }
    });
  }

  // --- Helper UI Components ---

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
            Text("WingTrace is connecting to your Home Wi-Fi...", textAlign: TextAlign.center),
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
        title: const Text("Successfully Connected!"),
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
    _pollingTimer?.cancel();
    _ssidController.dispose();
    _passController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDFBE7),
      appBar: AppBar(title: const Text("Wi-Fi Setup"), backgroundColor: Colors.blue, foregroundColor: Colors.white),
      body: Padding(
        padding: const EdgeInsets.all(25.0),
        child: Column(
          children: [
            TextField(controller: _ssidController, decoration: const InputDecoration(labelText: "Home Wi-Fi SSID")),
            const SizedBox(height: 20),
            TextField(controller: _passController, obscureText: true, decoration: const InputDecoration(labelText: "Password")),
            const SizedBox(height: 40),
            _isSending ? const CircularProgressIndicator() : ElevatedButton(
              onPressed: _updateWifi,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, minimumSize: const Size(double.infinity, 55)),
              child: const Text("CONNECT DEVICE", style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}