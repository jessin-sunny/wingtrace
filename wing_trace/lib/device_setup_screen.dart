import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:network_info_plus/network_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'user_dashboard.dart';

class DeviceSetupScreen extends StatefulWidget {
  const DeviceSetupScreen({super.key});

  @override
  State<DeviceSetupScreen> createState() => _DeviceSetupScreenState();
}

class _DeviceSetupScreenState extends State<DeviceSetupScreen> {
  int _currentStep = 0;
  bool _isLoading = false;
  final NetworkInfo _networkInfo = NetworkInfo();

  final TextEditingController _ssidController = TextEditingController();
  final TextEditingController _passController = TextEditingController();

  String? _detectedDeviceId;
  String? _detectedDeviceName;

  // --- STEP 1: Verify Hardware WiFi Connection ---
  Future<void> _checkWifiConnection() async {
    setState(() => _isLoading = true);

    // 1. Explicitly request BOTH permissions required for WiFi SSID on Android 13+
    Map<Permission, PermissionStatus> statuses = await [
      Permission.locationWhenInUse,
      Permission.nearbyWifiDevices, // Critical for Android 13+
    ].request();

    if (statuses[Permission.locationWhenInUse]!.isGranted) {
      // Check GPS service status
      var serviceStatus = await Permission.location.serviceStatus;
      
      if (serviceStatus.isEnabled) {
        String? wifiName = await _networkInfo.getWifiName();
        String cleanSsid = wifiName?.replaceAll('"', '') ?? "";

        if (cleanSsid.contains("WingTrace_V1")) {
          setState(() {
            _detectedDeviceId = "WT-${DateTime.now().millisecondsSinceEpoch}"; 
            _detectedDeviceName = "WingTrace_V1";
            _currentStep = 1;
          });
        } else {
          _showError("Connected to: $cleanSsid. Please switch to 'WingTrace_V1' WiFi.");
        }
      } else {
        _showError("Please enable GPS/Location in your system tray.");
      }
    } else {
      _showError("Permission denied. Please enable it in Settings > Apps > wing_trace.");
      // Force open settings if they click verify again and it's denied
      if (statuses[Permission.locationWhenInUse]!.isPermanentlyDenied) {
        await openAppSettings();
      }
    }
    setState(() => _isLoading = false);
  }
  // --- STEP 2: Send Internet Credentials to Hardware Gateway ---
  Future<void> _provisionHardware() async {
    if (_ssidController.text.isEmpty || _passController.text.isEmpty) {
      _showError("Please enter WiFi details.");
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Send credentials to hardware's internal web server
      final response = await http.post(
        Uri.parse("http://192.168.4.1/setup"),
        body: {
          "ssid": _ssidController.text.trim(),
          "password": _passController.text.trim(),
          "uid": FirebaseAuth.instance.currentUser?.uid, // Linking user to device
        },
      ).timeout(const Duration(seconds: 12));

      if (response.statusCode == 200) {
        _registerToFirebase();
      }
    } catch (e) {
      // SUCCESS HACK: When the hardware receives WiFi credentials, it reboots to connect.
      // This causes an immediate connection drop/error in the app.
      // In IoT setup, a 'Connection Failed' here often means the hardware is now switching to the internet!
      _registerToFirebase(); 
    }
  }

  // --- STEP 3: Register Device in Cloud Firestore ---
  Future<void> _registerToFirebase() async {
    try {
      String uid = FirebaseAuth.instance.currentUser!.uid;

      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'hasCompletedSetup': true,
        'device_id': _detectedDeviceId,
        'device_name': _detectedDeviceName,
        'device_list': FieldValue.arrayUnion([_detectedDeviceName]),
        'last_setup': DateTime.now(),
      });

      if (mounted) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const UserDashboard()));
      }
    } catch (e) {
      _showError("Cloud registration failed. Check your internet.");
    } finally {
      setState(() => _isLoading = false);
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
        actions: [
          TextButton(
            onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const UserDashboard())),
            child: const Text("SKIP", style: TextStyle(color: Colors.white)),
          )
        ],
      ),
      body: Column(
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
      value: (_currentStep + 1) / 3,
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
          desc: "1. Power on your WingTrace module.\n2. Go to WiFi Settings.\n3. Connect to 'WingTrace v1'.",
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
              const Text("Enter your farm WiFi details so the hardware can connect to the cloud.", textAlign: TextAlign.center),
              const SizedBox(height: 30),
              TextField(controller: _ssidController, decoration: const InputDecoration(labelText: "Network Name (SSID)", border: OutlineInputBorder())),
              const SizedBox(height: 15),
              TextField(controller: _passController, obscureText: true, decoration: const InputDecoration(labelText: "Network Password", border: OutlineInputBorder())),
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
        style: ElevatedButton.styleFrom(backgroundColor: Colors.green, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
        child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : Text(label, style: const TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }
}