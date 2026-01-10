import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart'; // 1. IMPORT FIREBASE AUTH
import 'login_screen.dart'; // 2. IMPORT LOGIN SCREEN

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Get the current user email to display dynamically
    final User? user = FirebaseAuth.instance.currentUser;
    final String userEmail = user?.email ?? "user@wingtrace.com";

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
          Text(userEmail, style: const TextStyle(color: Colors.grey)), // Display actual email
          const SizedBox(height: 30),
          ListTile(
            leading: const Icon(Icons.edit),
            title: const Text("Edit Profile"),
            onTap: () {
                // Add edit logic here later
            },
          ),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text("Logout", style: TextStyle(color: Colors.red)),
            
            // --- FIXED LOGOUT LOGIC ---
            onTap: () async {
              // 1. Sign out from Firebase
              await FirebaseAuth.instance.signOut();

              // 2. Navigate to Login Page AND remove all previous routes (Dashboard/Splash)
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => const LoginPage()),
                  (Route<dynamic> route) => false, // This condition removes everything else
                );
              }
            },
            // --------------------------
          ),
        ],
      ),
    );
  }
}