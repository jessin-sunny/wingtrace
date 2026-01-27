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
  // 2. The Login Logic
  void _handleLogin() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill all fields"))
      );
      return;
    }

    setState(() => _isLoading = true);

    // A. Sign In with Firebase Auth
    String? error = await _authService.signIn(
      _emailController.text.trim(),
      _passwordController.text.trim(),
    );

    setState(() => _isLoading = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
    }
    }

  void _showForgotPasswordDialog() {
    final TextEditingController resetEmailController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Reset Password"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Enter your email address. We will send you a link to reset your password."),
            const SizedBox(height: 15),
            TextField(
              controller: resetEmailController,
              decoration: const InputDecoration(
                hintText: "Enter your email",
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            onPressed: () async {
              String email = resetEmailController.text.trim();
              if (email.isEmpty) return;

              // 1. CAPTURE THE MESSENGER BEFORE CLOSING DIALOG
              // This 'messenger' variable holds a reference to the valid root scaffold
              final messenger = ScaffoldMessenger.of(context);
              
              // 2. Close Dialog immediately
              Navigator.pop(context);

              // 3. Call Firebase
              String? error = await _authService.sendPasswordResetEmail(email);

              // 4. Use the captured 'messenger' to show the snackbar
              messenger.showSnackBar(
                SnackBar(content: Text("Error: $error")),
              );
                        },
            child: const Text("Send Link", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
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
                Transform.translate(
                  offset: const Offset(0, 20),
                  child:
                    Image.asset(
                      'assets/logo.png', // The path to your actual logo
                      height: 170,       // Adjust size as needed
                      width: 170,
                      errorBuilder: (context, error, stackTrace) => 
                          const Icon(Icons.webhook, size: 80, color: Colors.green), // Fallback if image fails
                    ),
                ),
                const SizedBox(height: 5),
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
                        onPressed:_showForgotPasswordDialog,
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