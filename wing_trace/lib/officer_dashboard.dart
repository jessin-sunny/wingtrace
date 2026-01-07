import 'package:flutter/material.dart';
import 'login_screen.dart'; // To handle logout

class OfficerDashboard extends StatefulWidget {
  const OfficerDashboard({super.key});

  @override
  State<OfficerDashboard> createState() => _OfficerDashboardState();
}

class _OfficerDashboardState extends State<OfficerDashboard> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text("Officer Command Center"),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => Navigator.pushReplacement(
              context, MaterialPageRoute(builder: (context) => const LoginPage())
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Welcome Section
            const Text("Regional Overview", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const Text("District: Central Zone (Mock Data)", style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 20),

            // 2. High-Level Global Stats (Row of 2 Cards)
            Row(
              children: [
                _statCard("Total Users", "1,240", Colors.blue),
                _statCard("Active Outbreaks", "3", Colors.red),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _statCard("Detections/Day", "452", Colors.green),
                _statCard("High Risk", "12", Colors.orange),
              ],
            ),
            const SizedBox(height: 30),

            // 3. Urgent Alerts List
            const Text("Recent High-Risk Alerts", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            _alertItem("Aedes Aegypti Detected", "Area: Sector 4", "2 mins ago"),
            _alertItem("Unusual Pest Activity", "Area: Riverside", "15 mins ago"),

            const SizedBox(height: 30),

            // 4. Regional Heatmap Placeholder
            const Text("Regional Activity Heatmap", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Container(
              height: 180,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.green.withOpacity(0.5)),
              ),
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.map_outlined, size: 50, color: Colors.green),
                    Text("Interactive Map Loading...", style: TextStyle(color: Colors.green)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Widget for Statistic Cards
  Widget _statCard(String title, String value, Color color) {
    return Expanded(
      child: Card(
        elevation: 4,
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey)),
              Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
            ],
          ),
        ),
      ),
    );
  }

  // Widget for Individual Alerts
  Widget _alertItem(String title, String subtitle, String time) {
    return Card(
      color: Colors.red[50],
      child: ListTile(
        leading: const Icon(Icons.warning_amber_rounded, color: Colors.red),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
        subtitle: Text(subtitle),
        trailing: Text(time, style: const TextStyle(fontSize: 10)),
      ),
    );
  }
}