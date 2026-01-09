import 'package:flutter/material.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  // Mock Data: Simulating entries from a database
  final List<Map<String, String>> historyData = const [
    {"pest": "Aedes Aegypti", "date": "Jan 4, 2026", "confidence": "98%", "status": "Dangerous"},
    {"pest": "Anopheles", "date": "Jan 2, 2026", "confidence": "92%", "status": "Warning"},
    {"pest": "Culex", "date": "Dec 28, 2025", "confidence": "85%", "status": "Common"},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDFBE7),
      appBar: AppBar(
        title: const Text("Detection History"),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(10),
        itemCount: historyData.length,
        itemBuilder: (context, index) {
          final item = historyData[index];
          return Card(
            margin: const EdgeInsets.symmetric(vertical: 8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            child: ListTile(
              leading: const CircleAvatar(
                backgroundColor: Colors.green,
                child: Icon(Icons.bug_report, color: Colors.white),
              ),
              title: Text(item['pest']!, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text("Date: ${item['date']}"),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(item['confidence']!, style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                  const Text("Match", style: TextStyle(fontSize: 10)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}