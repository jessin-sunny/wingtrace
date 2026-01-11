// import 'package:flutter/material.dart';
// import 'package:firebase_auth/firebase_auth.dart'; // 1. IMPORT FIREBASE AUTH
// import 'login_screen.dart'; // 2. IMPORT LOGIN SCREEN

// class ProfileScreen extends StatelessWidget {
//   const ProfileScreen({super.key});

//   @override
//   Widget build(BuildContext context) {
//     // Get the current user email to display dynamically
//     final User? user = FirebaseAuth.instance.currentUser;
//     final String userEmail = user?.email ?? "user@wingtrace.com";

//     return Scaffold(
//       backgroundColor: const Color(0xFFFDFBE7),
//       appBar: AppBar(title: const Text("User Profile"), backgroundColor: Colors.green),
//       body: Column(
//         children: [
//           const SizedBox(height: 30),
//           const Center(
//             child: CircleAvatar(
//               radius: 60,
//               backgroundColor: Colors.green,
//               child: Icon(Icons.person, size: 80, color: Colors.white),
//             ),
//           ),
//           const SizedBox(height: 20),
//           const Text("WingTrace User", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
//           Text(userEmail, style: const TextStyle(color: Colors.grey)), // Display actual email
//           const SizedBox(height: 30),
//           ListTile(
//             leading: const Icon(Icons.edit),
//             title: const Text("Edit Profile"),
//             onTap: () {
//                 // Add edit logic here later
//             },
//           ),
//           ListTile(
//             leading: const Icon(Icons.logout, color: Colors.red),
//             title: const Text("Logout", style: TextStyle(color: Colors.red)),
            
//             // --- FIXED LOGOUT LOGIC ---
//             onTap: () async {
//               // 1. Sign out from Firebase
//               await FirebaseAuth.instance.signOut();

//               // 2. Navigate to Login Page AND remove all previous routes (Dashboard/Splash)
//               if (context.mounted) {
//                 Navigator.of(context).pushAndRemoveUntil(
//                   MaterialPageRoute(builder: (context) => const LoginPage()),
//                   (Route<dynamic> route) => false, // This condition removes everything else
//                 );
//               }
//             },
//             // --------------------------
//           ),
//         ],
//       ),
//     );
//   }
// }
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // Store the stream in a variable to avoid re-subscribing on every build
  late Stream<DocumentSnapshot> _userStream;
  final User? _currentUser = FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    // Initialize the stream once when the screen loads
    if (_currentUser != null) {
      _userStream = FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUser!.uid)
          .snapshots(); // .snapshots() provides the real-time Stream
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

              String name = "WingTrace User";
              
              // Check if document actually exists in Firestore
              if (snapshot.hasData && snapshot.data!.exists) {
                final data = snapshot.data!.data() as Map<String, dynamic>;
                name = data['name'] ?? "WingTrace User";
              }

              return Text(
                name,
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
              // Navigation to EditProfileScreen could go here
            },
          ),
          
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text("Logout", style: TextStyle(color: Colors.red)),
            onTap: () async {
              _showLogoutDialog(context);
            },
          ),
        ],
      ),
    );
  }

  // Improved logout with a confirmation dialog for better UX
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
              if (context.mounted) {
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