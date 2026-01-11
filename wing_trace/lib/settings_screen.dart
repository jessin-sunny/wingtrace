import 'package:flutter/material.dart';
import 'report_bug_screen.dart';

class SettingsScreen extends StatelessWidget {
  final bool isConnected;
  final String deviceName;

  const SettingsScreen({
    super.key,
    required this.isConnected,
    required this.deviceName,
  });

  @override
  Widget build(BuildContext context) {
    final Color primaryColor = Theme.of(context).primaryColor;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text("Settings"),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 15),
        children: [
          // 1. HARDWARE INFO SECTION
          _sectionHeader(context, "Hardware Information"),
          if (isConnected)
            _buildHardwareCard(context)
          else
            _buildEmptyState("No WingTrace device connected."),

          const SizedBox(height: 20),

          // 2. SOFTWARE & APP SECTION
          _sectionHeader(context, "Software & App"),
          _buildListTile(Icons.info_outline, "Software Version", "v1.0.4-stable"),
          _buildListTile(Icons.update, "Check for Updates", "Up to date", onTap: () {
             _showUpdateDialog(context);
          }),
          _buildListTile(Icons.security, "Privacy Policy", "View details"),

          const SizedBox(height: 20),

          // 3. ABOUT US & SUPPORT
          _sectionHeader(context, "About WingTrace"),
          _buildListTile(Icons.group, "About Us", "Learn about the project", onTap: () {
            _showAboutUs(context);
          }),
          _buildListTile(Icons.help_center_outlined, "Help & Documentation", "Setup guide"),
          _buildListTile(Icons.bug_report, "Report a Bug", "Help us improve", onTap: () {
            Navigator.push(context, MaterialPageRoute(builder: (context) => const ReportBugScreen()));
          }),
          const SizedBox(height: 40),
          Center(
            child: Text(
              "WingTrace Mobile Application\nDeveloped for College Research 2026",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // --- UI Component Builders ---

  Widget _sectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 10, bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: Theme.of(context).primaryColor,
          fontWeight: FontWeight.bold,
          fontSize: 13,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildHardwareCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10),
        ],
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
                    Row(
                      children: [
                        const Icon(Icons.battery_5_bar, color: Colors.green, size: 16),
                        const SizedBox(width: 5),
                        Text("85% Charge", style: TextStyle(color: Colors.green[700], fontSize: 12)),
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
              _hwStat(Icons.thermostat, "32°C", "Temp"),
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
      margin: const EdgeInsets.symmetric(vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: ListTile(
        leading: Icon(icon, color: Colors.green),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
        trailing: const Icon(Icons.chevron_right, size: 20),
        onTap: onTap,
      ),
    );
  }

  Widget _buildEmptyState(String msg) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Center(
        child: Text(msg, style: const TextStyle(color: Colors.grey)),
      ),
    );
  }

  // --- Dialog Functions ---

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
      applicationIcon: const Icon(Icons.bug_report, color: Colors.green, size: 40),
      children: [
        const Text("WingTrace is an automated mosquito and pest detection system built to identify vectors of diseases like Dengue and Zika using hardware-integrated AI."),
      ],
    );
  }
}