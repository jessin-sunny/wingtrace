import 'package:flutter/material.dart';

class OfficerDashboard extends StatelessWidget {
  const OfficerDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDFBE7),
      appBar: AppBar(
        title: const Text("Officer Panel"),
        backgroundColor: Colors.green[800],
      ),
      body: const Center(
        child: Text(
          "Agricultural/Health Officer View\n(Data Analytics & Regional Monitoring)",
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 18, color: Colors.green),
        ),
      ),
    );
  }
}