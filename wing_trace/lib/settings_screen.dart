import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'report_bug_screen.dart';
import 'device_setup_screen.dart';

class SettingsScreen extends StatefulWidget {
  final bool isConnected;
  final String deviceName;

  const SettingsScreen({
    super.key,
    required this.isConnected,
    required this.deviceName,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // --- SUB-SCREEN: DEVICE DETAILS ---
  void _navigateToDetails(BuildContext context, String deviceId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DeviceDetailsScreen(
          deviceId: deviceId,
          initialIsOnline: widget.isConnected,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDFBE7),
      appBar: AppBar(
        title: const Text("Settings"),
        centerTitle: true,
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 15),
        children: [
          _sectionHeader("Hardware Information"),
          
          // StreamBuilder ensures the device stays visible if owned
          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(FirebaseAuth.instance.currentUser?.uid)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData || !snapshot.data!.exists) return const SizedBox();
              
              final data = snapshot.data!.data() as Map<String, dynamic>;
              final hasSetup = data['hasCompletedSetup'] ?? false;
              final devices = data['devices'] as List<dynamic>? ?? [];

              if (hasSetup && devices.isNotEmpty) {
                final deviceId = devices[0].toString();
                return GestureDetector(
                  onTap: () => _navigateToDetails(context, deviceId),
                  child: _buildHardwareCard(deviceId),
                );
              } else {
                return _buildEmptyState(context, "No WingTrace device connected.");
              }
            },
          ),

          const SizedBox(height: 20),
          _sectionHeader("Software & App"),
          _buildListTile(Icons.info_outline, "Software Version", "v1.0.4-stable"),
          _buildListTile(Icons.update, "Check for Updates", "Up to date", onTap: () => _showUpdateDialog(context)),
          _buildListTile(Icons.security, "Privacy Policy", "Data & Security", onTap: () => _showPrivacyPolicy(context)),
          
          const SizedBox(height: 20),
          _sectionHeader("About WingTrace"),
          _buildListTile(Icons.group, "About Us", "Learn about the project", onTap: () => _showAboutUs(context)),
          _buildListTile(Icons.help_center_outlined, "Help & Documentation", "Setup & Troubleshooting guide",
              onTap: () => _showHelpBottomSheet(context)),
          _buildListTile(Icons.bug_report, "Report a Bug", "Help us improve", onTap: () {
            Navigator.push(context, MaterialPageRoute(builder: (context) => const ReportBugScreen()));
          }),
          
          const SizedBox(height: 40),
          const Center(
            child: Text(
              "WingTrace Mobile Application\nDeveloped for Final Year Project 2026",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // --- UI COMPONENTS ---

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 10, bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 1.2),
      ),
    );
  }

  Widget _buildHardwareCard(String id) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.asset(
              'assets/device_image.png',
              width: 60, height: 60, fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => const Icon(Icons.developer_board, size: 40, color: Colors.grey),
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(id, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const Text("Tap to view details & manage", style: TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: Colors.green),
        ],
      ),
    );
  }

  Widget _buildListTile(IconData icon, String title, String subtitle, {VoidCallback? onTap}) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15), side: BorderSide(color: Colors.green.withOpacity(0.1))),
      child: ListTile(
        leading: Icon(icon, color: Colors.green),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
        trailing: const Icon(Icons.chevron_right, size: 20),
        onTap: onTap,
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, String msg) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15)),
      child: Column(
        children: [
          Text(msg, style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 15),
          ElevatedButton.icon(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const DeviceSetupScreen())),
            icon: const Icon(Icons.add, color: Colors.white),
            label: const Text("CONNECT NEW DEVICE", style: TextStyle(color: Colors.white)),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, shape: const StadiumBorder()),
          ),
        ],
      ),
    );
  }

  // --- DIALOGS & HELPERS ---

  void _showHelpBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: const BoxDecoration(color: Color(0xFFFDFBE7), borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(width: 50, height: 5, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10))),
            const Padding(padding: EdgeInsets.all(20.0), child: Text("WingTrace User Guide", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.green))),
            const Expanded(child: Center(child: Text("Guide Content..."))),
          ],
        ),
      ),
    );
  }

  void _showUpdateDialog(BuildContext context) {
    showDialog(context: context, builder: (context) => AlertDialog(title: const Text("Update"), content: const Text("Firmware is up to date."), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("OK"))]));
  }

  void _showPrivacyPolicy(BuildContext context) {
    showDialog(context: context, builder: (context) => AlertDialog(title: const Text("Privacy"), content: const Text("Data collected for AI research."), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("CLOSE"))]));
  }

  void _showAboutUs(BuildContext context) {
    showAboutDialog(context: context, applicationName: "WingTrace", applicationVersion: "1.0.4", applicationLegalese: "© 2026 WingTrace Team");
  }
}

// --- NEW SCREEN: DEVICE DETAILS & MANAGEMENT ---

class DeviceDetailsScreen extends StatefulWidget {
  final String deviceId;
  final bool initialIsOnline;

  const DeviceDetailsScreen({super.key, required this.deviceId, required this.initialIsOnline});

  @override
  State<DeviceDetailsScreen> createState() => _DeviceDetailsScreenState();
}

class _DeviceDetailsScreenState extends State<DeviceDetailsScreen> {
  late bool _isOnline;
  bool _isLoading = false;
  final String serverUrl = "https://wingtrace.onrender.com";

  @override
  void initState() {
    super.initState();
    _isOnline = widget.initialIsOnline;
  }

  Future<void> _handleDisconnect() async {
    setState(() => _isLoading = true);
    try {
      final response = await http.post(
        Uri.parse("$serverUrl/disconnect"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "deviceId": widget.deviceId,
          "userId": FirebaseAuth.instance.currentUser?.uid
        }),
      );

      if (response.statusCode == 200) {
        setState(() => _isOnline = false);
        _showSnackBar("Device disconnected successfully.");
      } else {
        _showSnackBar("Failed: ${jsonDecode(response.body)['error']}");
      }
    } catch (e) {
      _showSnackBar("Error connecting to server.");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleReset() async {
    setState(() => _isLoading = true);
    try {
      final response = await http.post(
        Uri.parse("$serverUrl/reset"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "deviceId": widget.deviceId,
          "userId": FirebaseAuth.instance.currentUser?.uid
        }),
      );

      if (response.statusCode == 200) {
        // Remove from Firestore
        await FirebaseFirestore.instance
            .collection('users')
            .doc(FirebaseAuth.instance.currentUser?.uid)
            .update({
          'hasCompletedSetup': false,
          'devices': FieldValue.arrayRemove([widget.deviceId])
        });
        if (mounted) Navigator.pop(context);
      } else {
        _showSnackBar("Reset Failed: ${jsonDecode(response.body)['error']}");
      }
    } catch (e) {
      _showSnackBar("Reset Error: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDFBE7),
      appBar: AppBar(title: const Text("Device Management"), backgroundColor: Colors.green),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            const Icon(Icons.developer_board, size: 80, color: Colors.green),
            const SizedBox(height: 20),
            Text(widget.deviceId, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Text("Status: ${_isOnline ? "CONNECTED" : "DISCONNECTED"}", 
                style: TextStyle(color: _isOnline ? Colors.green : Colors.red, fontWeight: FontWeight.w600)),
            const Divider(height: 40),
            
            _isLoading ? const CircularProgressIndicator() : Column(
              children: [
                _actionTile(
                  _isOnline ? Icons.link_off : Icons.link,
                  _isOnline ? "Disconnect Device" : "Connect Device",
                  "Toggle server link status",
                  _isOnline ? _handleDisconnect : null, // Re-connect logic would go here
                  color: _isOnline ? Colors.orange : Colors.grey,
                ),
                const SizedBox(height: 15),
                _actionTile(
                  Icons.restart_alt,
                  "Reset Hardware",
                  "Wipe ownership and factory reset",
                  _handleReset,
                  color: Colors.red,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionTile(IconData icon, String title, String sub, VoidCallback? onTap, {Color color = Colors.green}) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15), side: BorderSide(color: color.withOpacity(0.3))),
      child: ListTile(
        leading: CircleAvatar(backgroundColor: color.withOpacity(0.1), child: Icon(icon, color: color)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(sub, style: const TextStyle(fontSize: 12)),
        onTap: onTap,
      ),
    );
  }
}