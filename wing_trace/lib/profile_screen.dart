import 'package:flutter/material.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDFBE7),
      appBar: AppBar(title: const Text("User Profile"), backgroundColor: Colors.green),
      body: Column(
        children: [
          const SizedBox(height: 30),
          const Center(
            child: CircleAvatar(
              radius: 60,
              backgroundColor: Colors.green,
              child: Icon(Icons.person, size: 80, color: Colors.white),
            ),
          ),
          const SizedBox(height: 20),
          const Text("WingTrace User", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const Text("user@collegeproject.edu", style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 30),
          ListTile(
            leading: const Icon(Icons.edit),
            title: const Text("Edit Profile"),
            onTap: () {},
          ),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text("Logout", style: TextStyle(color: Colors.red)),
            onTap: () => Navigator.of(context).popUntil((route) => route.isFirst),
          ),
        ],
      ),
    );
  }
}