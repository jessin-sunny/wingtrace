import 'package:flutter/material.dart';

class LastDetectedScreen extends StatelessWidget {
  const LastDetectedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(title: const Text("Last Detected Pest")),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                child: Image.network(
                  'https://placehold.co/400x200/green/white?text=Last+Pest+Photo',
                  fit: BoxFit.cover,
                ),
              ),
              const ListTile(
                title: Text("Aedes Aegypti", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22)),
                subtitle: Text("Detected at 10:45 AM today"),
              ),
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  "This mosquito is a primary vector for Zika, Dengue, and Yellow Fever. It was identified with 98% confidence.",
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}