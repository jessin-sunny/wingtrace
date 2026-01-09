import 'package:flutter/material.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  // 1. Define the list of roles and a variable to store the selection
  final List<String> _roles = ['Regular User', 'Agricultural/Health Officer'];
  String? _selectedRole; // This starts as null so the hint shows up

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDFBE7),
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 30),
            child: Column(
              children: [
                const Icon(Icons.webhook, size: 80, color: Colors.green),
                const Text(
                  'Sign Up',
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
                      const TextField(decoration: InputDecoration(hintText: 'Full Name')),
                      const TextField(decoration: InputDecoration(hintText: 'Email/username')),
                      const TextField(decoration: InputDecoration(hintText: 'Mobile No.')),
                      
                      // 2. The Role Dropdown Widget
                      DropdownButtonFormField<String>(
                        value: _selectedRole,
                        hint: const Text('Select Role'),
                        decoration: const InputDecoration(
                          enabledBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: Colors.grey),
                          ),
                        ),
                        items: _roles.map((String role) {
                          return DropdownMenuItem<String>(
                            value: role,
                            child: Text(role),
                          );
                        }).toList(),
                        onChanged: (String? newValue) {
                          setState(() {
                            _selectedRole = newValue;
                          });
                        },
                      ),

                      const TextField(obscureText: true, decoration: InputDecoration(hintText: 'Password')),
                      const TextField(obscureText: true, decoration: InputDecoration(hintText: 'Confirm Password')),
                      const SizedBox(height: 25),
                      
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            print("Selected Role: $_selectedRole");
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green[700],
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                          ),
                          child: const Text('Register', style: TextStyle(color: Colors.white)),
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 20),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Already a user? Login →', style: TextStyle(color: Colors.green)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}