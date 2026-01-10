import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart'; // Import your service
import 'signup_screen.dart';
import 'officer_dashboard.dart';
import 'user_dashboard.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  // 1. Service & Controllers
  final AuthService _authService = AuthService();
  final TextEditingController _emailController = TextEditingController(); // Renamed for clarity
  final TextEditingController _passwordController = TextEditingController(); // Added password controller
  
  bool _isObscured = true;
  bool _isLoading = false; // To show spinner

  // 2. The Login Logic
  void _handleLogin() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please fill all fields")));
      return;
    }

    setState(() => _isLoading = true);

    // A. Sign In with Firebase Auth
    String? error = await _authService.signIn(
      _emailController.text.trim(),
      _passwordController.text.trim(),
    );

    if (error != null) {
      // Login Failed
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
    } else {
      // B. Login Success -> Fetch Role from Firestore
      try {
        String uid = FirebaseAuth.instance.currentUser!.uid;
        DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
        
        setState(() => _isLoading = false);

        if (userDoc.exists) {
          String role = userDoc.get('role'); // 'farmer', 'officer', etc.
          
          // C. Navigate based on Database Role
          if (role == 'officer' || role == 'admin') {
            Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const OfficerDashboard()));
          } else {
            Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const UserDashboard()));
          }
        } else {
           // Fallback if doc missing
           Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const UserDashboard()));
        }
      } catch (e) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error fetching role: $e")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDFBE7),
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 30),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.webhook, size: 80, color: Colors.green),
                const Text(
                  'Sign In',
                  style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.green),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(25),
                    border: Border.all(color: Colors.green, width: 1),
                  ),
                  child: Column(
                    children: [
                      // Email Field
                      TextField(
                        controller: _emailController, // Connected controller
                        decoration: const InputDecoration(hintText: 'email'), // Firebase needs email, not username
                      ),
                      const SizedBox(height: 15),
                      // Password Field
                      TextField(
                        controller: _passwordController, // Connected controller
                        obscureText: _isObscured,
                        decoration: InputDecoration(
                          hintText: 'password',
                          suffixIcon: IconButton(
                            icon: Icon(_isObscured ? Icons.visibility_off : Icons.visibility, color: Colors.green),
                            onPressed: () => setState(() => _isObscured = !_isObscured),
                          ),
                        ),
                      ),
                      const SizedBox(height: 25),
                      
                      // Login Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _handleLogin, // Disable if loading
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green[700],
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                          ),
                          child: _isLoading 
                            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Text('login', style: TextStyle(color: Colors.white)),
                        ),
                      ),
                      
                      TextButton(
                        onPressed: () {},
                        child: const Text('forgot password?', style: TextStyle(color: Colors.grey)),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 30),
                const Text('or sign in using', style: TextStyle(color: Colors.green)),
                const SizedBox(height: 10),
                
                const CircleAvatar(
                  backgroundColor: Colors.white,
                  child: Icon(Icons.g_mobiledata, size: 40, color: Colors.red),
                ),
                
                const SizedBox(height: 20),
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const SignUpPage()),
                    );
                  },
                  child: const Text(
                    'Not a user? Register →',
                    style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}