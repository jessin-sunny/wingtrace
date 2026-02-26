import 'package:flutter/material.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'wifi_credentials_screen.dart';

class NetworkResetGuideScreen extends StatefulWidget {
  const NetworkResetGuideScreen({super.key});

  @override
  State<NetworkResetGuideScreen> createState() => _NetworkResetGuideScreenState();
}

class _NetworkResetGuideScreenState extends State<NetworkResetGuideScreen> {
  final NetworkInfo _networkInfo = NetworkInfo();
  bool _isVerifying = false;

  Future<void> _verifyAndProceed() async {
    setState(() => _isVerifying = true);

    // 1. Request Location Permission (Required for SSID on Android/iOS)
    var status = await Permission.locationWhenInUse.request();
    if (!status.isGranted) {
      _showError("Location permission is required to verify the device Wi-Fi.");
      setState(() => _isVerifying = false);
      return;
    }

    // 2. Get Current SSID
    String? wifiName = await _networkInfo.getWifiName(); 
    
    setState(() => _isVerifying = false);

    // 🔹 Updated Logic: Check if the SSID contains "WingTrace" (ignores case and quotes)
    if (wifiName != null && wifiName.toLowerCase().contains("wingtrace")) {
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const WifiCredentialsScreen()),
      );
    } else {
      _showError("Not connected. Ensure your Wi-Fi is connected to 'WingTrace-XXXX'");
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDFBE7),
      appBar: AppBar(title: const Text("Network Reset"), backgroundColor: Colors.blue, foregroundColor: Colors.white),
      body: Padding(
        padding: const EdgeInsets.all(25.0),
        child: Column(
          children: [
            const SizedBox(height: 40),
            const Icon(Icons.wifi_tethering_rounded, size: 80, color: Colors.blue),
            const SizedBox(height: 30),
            const Text("Connect to Hardware", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 15),
            const Text(
              "1. Hold the hardware button until the green LED turns off.\n\n2. Open your phone's Wi-Fi settings.\n\n3. Connect to the network starting with 'WingTrace'.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, height: 1.5),
            ),
            const Spacer(),
            ElevatedButton(
              onPressed: _isVerifying ? null : _verifyAndProceed,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                minimumSize: const Size(double.infinity, 55),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              ),
              child: _isVerifying 
                ? const CircularProgressIndicator(color: Colors.white)
                : const Text("I'VE CONNECTED TO WINGTRACE", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}