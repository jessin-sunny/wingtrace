import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'login_screen.dart';
import 'edit_profile_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late Stream<DocumentSnapshot> _userStream;
  final User? _currentUser = FirebaseAuth.instance.currentUser;
  
  // 1. ADDED: State variable to store the name for access outside the builder
  String _currentName = "WingTrace User";

  @override
  void initState() {
    super.initState();
    if (_currentUser != null) {
      _userStream = FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUser!.uid)
          .snapshots();
    }
  }

  @override
  Widget build(BuildContext context) {
    final String userEmail = _currentUser?.email ?? "user@wingtrace.com";

    return Scaffold(
      backgroundColor: const Color(0xFFFDFBE7),
      appBar: AppBar(
        title: const Text("User Profile"),
        backgroundColor: Colors.green,
        elevation: 0,
      ),
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

          // --- REAL-TIME NAME DISPLAY ---
          StreamBuilder<DocumentSnapshot>(
            stream: _userStream,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const Text("Error loading name", style: TextStyle(color: Colors.red));
              }

              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Text("Loading...", style: TextStyle(fontSize: 24, color: Colors.grey));
              }

              if (snapshot.hasData && snapshot.data!.exists) {
                final data = snapshot.data!.data() as Map<String, dynamic>;
                // 2. UPDATED: Store the name in the state variable
                _currentName = data['name'] ?? "WingTrace User";
              }

              return Text(
                _currentName,
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              );
            },
          ),

          Text(userEmail, style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 30),
          const Divider(),
          
          ListTile(
            leading: const Icon(Icons.edit, color: Colors.green),
            title: const Text("Edit Profile"),
            onTap: () {
              // 3. FIXED: Now _currentName is accessible here
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => EditProfileScreen(currentName: _currentName),
                ),
              );
            },
          ),
          
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text("Logout", style: TextStyle(color: Colors.red)),
            onTap: () => _showLogoutDialog(context),
          ),
        ],
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Logout"),
        content: const Text("Are you sure you want to log out of WingTrace?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          TextButton(
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => const LoginPage()),
                  (route) => false,
                );
              }
            },
            child: const Text("Logout", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}