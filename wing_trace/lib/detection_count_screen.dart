import 'package:flutter/material.dart';

class DetectionCountScreen extends StatelessWidget {
  const DetectionCountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(title: const Text("Detections Today")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text("Total Scans Today", style: TextStyle(fontSize: 20, color: Colors.grey)),
            const Text("12", style: TextStyle(fontSize: 80, fontWeight: FontWeight.bold, color: Colors.green)),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(15),
              ),
              child: const Text("+20% increase from yesterday", style: TextStyle(color: Colors.green)),
            ),
          ],
        ),
      ),
    );
  }
}