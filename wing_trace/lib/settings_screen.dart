import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'report_bug_screen.dart';
import 'device_setup_screen.dart';

class SettingsScreen extends StatelessWidget {
  final bool isConnected;
  final String deviceName;

  const SettingsScreen({
    super.key,
    required this.isConnected,
    required this.deviceName,
  });

  // Logic to completely remove the hardware link
  Future<void> _removeHardware(BuildContext context) async {
    try {
      String uid = FirebaseAuth.instance.currentUser!.uid;

      // Reset the setup flag in Firestore
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'hasCompletedSetup': false,
      });

      if (context.mounted) {
        Navigator.pop(context); // Close the dialog
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Hardware removed. You will need to setup again.")),
        );
        Navigator.pop(context); // Go back to Dashboard
      }
    } catch (e) {
      debugPrint("Error removing hardware: $e");
    }
  }

  void _showRemoveConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Remove Hardware?"),
        content: const Text(
            "This will completely disconnect the device. You will have to go through the setup process again to reconnect."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCEL")),
          TextButton(
            onPressed: () => _removeHardware(context),
            child: const Text("REMOVE", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // --- HELP & DOCUMENTATION BOTTOM SHEET ---
  void _showHelpBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: const BoxDecoration(
          color: Color(0xFFFDFBE7),
          borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
                width: 50,
                height: 5,
                decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10))),
            const Padding(
              padding: EdgeInsets.all(20.0),
              child: Text("WingTrace User Guide",
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.green)),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  _helpSection("1. Hardware Setup", [
                    "Power the WingTrace module using a 5V adapter.",
                    "Ensure your phone WiFi is connected to 'WingTrace_V1'.",
                    "Return to the app and use the 'Setup Device' button.",
                  ]),
                  _helpSection("2. Internet Provisioning", [
                    "Enter your home/farm WiFi SSID and Password in the Setup screen.",
                    "The app will securely send these details to the hardware (192.168.4.1/save).",
                    "The hardware will reboot and link to the cloud automatically.",
                  ]),
                  _helpSection("3. Dashboard & Monitoring", [
                    "LIVE Status: Indicates your app is synchronized with the hardware.",
                    "Detection Count: Real-time update of pests identified via AI.",
                    "Env Stats: Shows live Temperature and Humidity from the field sensors.",
                  ]),
                  _helpSection("4. Troubleshooting", [
                    "WiFi not found? Reset the hardware power supply.",
                    "Connection failed? Ensure your phone is connected to the 'WingTrace_V1' network before provisioning.",
                    "For deep technical issues, use 'Report a Bug' to contact the team.",
                  ]),
                  const SizedBox(height: 40),
                  const Center(
                    child: Text(
                      "Developed by Jessin, Alwin, Akhil & Edwin\nGuided by Prof. Anu Bonia Francis",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: Colors.grey, fontStyle: FontStyle.italic),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _helpSection(String title, List<String> steps) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 25),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
          const SizedBox(height: 10),
          ...steps.map((step) => Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("• ", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                    Expanded(child: Text(step, style: const TextStyle(color: Colors.black54, height: 1.4))),
                  ],
                ),
              )),
        ],
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
          _sectionHeader(context, "Hardware Information"),
          if (isConnected)
            Column(
              children: [
                _buildHardwareCard(context),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _showRemoveConfirmation(context),
                    icon: const Icon(Icons.link_off, color: Colors.red),
                    label: const Text("DISCONNECT & REMOVE DEVICE", style: TextStyle(color: Colors.red)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.red),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    ),
                  ),
                ),
              ],
            )
          else
            _buildEmptyState(context, "No WingTrace device connected."),
          const SizedBox(height: 20),
          _sectionHeader(context, "Software & App"),
          _buildListTile(Icons.info_outline, "Software Version", "v1.0.4-stable"),
          _buildListTile(Icons.update, "Check for Updates", "Up to date", onTap: () => _showUpdateDialog(context)),
          _buildListTile(Icons.security, "Privacy Policy", "Data & Security", onTap: () => _showPrivacyPolicy(context)),
          const SizedBox(height: 20),
          _sectionHeader(context, "About WingTrace"),
          _buildListTile(Icons.group, "About Us", "Learn about the project", onTap: () => _showAboutUs(context)),
          _buildListTile(Icons.help_center_outlined, "Help & Documentation", "Setup & Troubleshooting guide",
              onTap: () => _showHelpBottomSheet(context)),
          _buildListTile(Icons.bug_report, "Report a Bug", "Help us improve", onTap: () {
            Navigator.push(context, MaterialPageRoute(builder: (context) => const ReportBugScreen()));
          }),
          const SizedBox(height: 40),
          Center(
            child: Text(
              "WingTrace Mobile Application\nDeveloped for Final Year Project 2026",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _sectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 10, bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 1.2),
      ),
    );
  }

  Widget _buildHardwareCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
      ),
      child: Column(
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.asset(
                  'assets/device_image.png',
                  width: 80,
                  height: 80,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      const Icon(Icons.developer_board, size: 50, color: Colors.grey),
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(deviceName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                    const SizedBox(height: 4),
                    const Text("Serial: WT-2026-X11", style: TextStyle(color: Colors.grey, fontSize: 12)),
                    const SizedBox(height: 4),
                    const Row(
                      children: [
                        Icon(Icons.battery_5_bar, color: Colors.green, size: 16),
                        SizedBox(width: 5),
                        Text("85% Charge", style: TextStyle(color: Colors.green, fontSize: 12)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 30),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _hwStat(Icons.wifi, "Strong", "Signal"),
              _hwStat(Icons.thermostat, "28°C", "Temp"),
              _hwStat(Icons.storage, "2.4 GB", "SD Card"),
            ],
          ),
        ],
      ),
    );
  }

  Widget _hwStat(IconData icon, String val, String label) {
    return Column(
      children: [
        Icon(icon, size: 20, color: Colors.grey),
        Text(val, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 10)),
      ],
    );
  }

  Widget _buildListTile(IconData icon, String title, String subtitle, {VoidCallback? onTap}) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 4),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15), side: BorderSide(color: Colors.green.withOpacity(0.2))),
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
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        children: [
          Text(msg, style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 15),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const DeviceSetupScreen()));
            },
            icon: const Icon(Icons.add, color: Colors.white),
            label: const Text("CONNECT NEW DEVICE", style: TextStyle(color: Colors.white)),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, shape: const StadiumBorder()),
          ),
        ],
      ),
    );
  }

  void _showPrivacyPolicy(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.security, color: Colors.green),
            SizedBox(width: 10),
            Text("Privacy Policy"),
          ],
        ),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("Data Collection", style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 5),
              Text("WingTrace collect pest detection data, location for mapping, and device health stats.",
                  style: TextStyle(fontSize: 13)),
              SizedBox(height: 15),
              Text("User Privacy", style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 5),
              Text("Agricultural insights are anonymized for research purposes.", style: TextStyle(fontSize: 13)),
              SizedBox(height: 15),
              Text("Storage", style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 5),
              Text("Images processed by the AI are stored locally and on secured cloud servers.",
                  style: TextStyle(fontSize: 13)),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("CLOSE", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }

  void _showUpdateDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Check Updates"),
        content: const Text("Your WingTrace software and firmware are currently up to date."),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("OK"))],
      ),
    );
  }

  void _showAboutUs(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: "WingTrace",
      applicationVersion: "1.0.4",
      applicationIcon: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.asset(
          'assets/logo.png', // Ensure this matches your logo filename
          width: 60,
          height: 60,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) => const Icon(Icons.bug_report, color: Colors.green, size: 40),
        ),
      ),
      applicationLegalese: "© 2026 WingTrace Team",
      children: [
        const SizedBox(height: 15),
        const Text("Project Significance:", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
        const Text(
          "This is a Major Project developed for the Final Year Curriculum 2025-2026. WingTrace is an automated mosquito and pest detection system using hardware-integrated AI.",
        ),
        const SizedBox(height: 15),
        const Text("Development Team:", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
        const Text("• Jessin Sunny (Hardware Lead)"),
        const Text("• Alwin Philip (AI/ML Developer)"),
        const Text("• Akhil S Nair (App Developer)"),
        const Text("• Edwin Varkey (Research Lead and Backend Developer)"),
        const SizedBox(height: 10),
        const Divider(),
        const Text(
          "Guided by: Prof. Anu Bonia Francis, Department of Computer Science, RIT Kottayam.",
          style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
        ),
      ],
    );
  }
}