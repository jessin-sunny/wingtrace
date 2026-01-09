import 'package:flutter/material.dart';

class AccuracySummaryScreen extends StatelessWidget {
  const AccuracySummaryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(title: const Text("Accuracy Summary")),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            const CircleAvatar(
              radius: 50,
              backgroundColor: Colors.green,
              child: Text("94%", style: TextStyle(fontSize: 30, color: Colors.white, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 20),
            const Text("Overall Identification Accuracy", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const Divider(height: 40),
            _accuracyTile("Aedes Aegypti", "98%"),
            _accuracyTile("Anopheles", "92%"),
            _accuracyTile("Culex", "89%"),
            _accuracyTile("House Fly", "95%"),
          ],
        ),
      ),
    );
  }

  Widget _accuracyTile(String pest, String percentage) {
    return ListTile(
      title: Text(pest),
      trailing: Text(percentage, style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
    );
  }
}