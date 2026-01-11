import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'user_dashboard.dart'; // Ensure this matches your file name
import 'officer_dashboard.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  // --- LOGIC START ---
  final AuthService _authService = AuthService();
  
  // 1. Controllers to capture text input
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPassController = TextEditingController();

  final List<String> _roles = ['Regular User', 'Agricultural/Health Officer'];
  String? _selectedRole;
  bool _isLoading = false;

  void _handleSignUp() async {
    // Basic Validation
    if (_nameController.text.isEmpty || 
        _emailController.text.isEmpty || 
        _passwordController.text.isEmpty ||
        _selectedRole == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please fill all fields")));
      return;
    }

    if (_passwordController.text != _confirmPassController.text) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Passwords do not match")));
      return;
    }

    setState(() => _isLoading = true);

    // Map UI Role to Database Role
    String dbRole = (_selectedRole == 'Agricultural/Health Officer') ? 'officer' : 'farmer';

    // Call Firebase
    String? error = await _authService.signUp(
      _emailController.text.trim(),
      _passwordController.text.trim(),
      _nameController.text.trim(),
      dbRole 
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (error == null) {
      // Success: Route to correct Dashboard
      if (dbRole == 'officer') {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const OfficerDashboard()));
      } else {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const UserDashboard()));
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
    }
  }
  // --- LOGIC END ---

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
                      TextField(
                        controller: _nameController, // Added Controller
                        decoration: const InputDecoration(hintText: 'Full Name'),
                      ),
                      TextField(
                        controller: _emailController, // Added Controller
                        decoration: const InputDecoration(hintText: 'Email/username'),
                      ),
                      TextField(
                        controller: _phoneController, // Added Controller
                        decoration: const InputDecoration(hintText: 'Mobile No.'),
                      ),
                      
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

                      TextField(
                        controller: _passwordController, // Added Controller
                        obscureText: true, 
                        decoration: const InputDecoration(hintText: 'Password')
                      ),
                      TextField(
                        controller: _confirmPassController, // Added Controller
                        obscureText: true, 
                        decoration: const InputDecoration(hintText: 'Confirm Password')
                      ),
                      const SizedBox(height: 25),
                      
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _handleSignUp, // Connected Logic
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green[700],
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                          ),
                          // Added Loading Indicator support
                          child: _isLoading 
                            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Text('Register', style: TextStyle(color: Colors.white)),
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