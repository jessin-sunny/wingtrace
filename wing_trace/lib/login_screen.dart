import 'package:flutter/material.dart';
import 'signup_screen.dart';
import 'officer_dashboard.dart';
import 'user_dashboard.dart';


// 1. We change this to a StatefulWidget
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool _isObscured = true;
  // Add these controllers to capture text
  final TextEditingController _userController = TextEditingController();

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
                      TextField(
                        controller: _userController, // Assign controller
                        decoration: const InputDecoration(hintText: 'username'),
                      ),
                      const SizedBox(height: 15),
                      TextField(
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
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            // ROLE BASED NAVIGATION LOGIC
                            String userText = _userController.text.toLowerCase();
                            
                            if (userText.contains('officer') || userText.contains('admin')) {
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(builder: (context) => const OfficerDashboard()),
                              );
                            } else {
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(builder: (context) => const UserDashboard()),
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green[700],
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                          ),
                          child: const Text('login', style: TextStyle(color: Colors.white)),
                        ),
                      ),
                      // ... rest of your TextButton code
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