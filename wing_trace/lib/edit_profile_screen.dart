import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class EditProfileScreen extends StatefulWidget {
  final String currentName;

  const EditProfileScreen({super.key, required this.currentName});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late TextEditingController _nameController;
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.currentName);
  }

  // --- 1. UPDATE PASSWORD ---
  Future<void> _updatePassword() async {
    if (_passwordController.text.trim().isEmpty) return;
    try {
      await FirebaseAuth.instance.currentUser?.updatePassword(_passwordController.text.trim());
      _showSnackBar("Password updated successfully!");
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        _showSnackBar("Please re-authenticate to change password.");
      } else {
        _showSnackBar("Password Error: ${e.message}");
      }
    }
  }

  // --- 2. UPDATE PHONE (Basic logic) ---
  // Note: Real phone update requires SMS verification (verifyPhoneNumber)
  Future<void> _triggerPhoneUpdate() async {
    String phone = _phoneController.text.trim();
    if (phone.isEmpty) return;

    // For this example, we update the phone only in Firestore.
    // To update Auth phone, use FirebaseAuth.instance.verifyPhoneNumber first.
    await FirebaseFirestore.instance.collection('users').doc(FirebaseAuth.instance.currentUser!.uid).update({
      'phone': phone,
    });
    _showSnackBar("Phone number updated in records.");
  }

  // --- 3. MAIN UPDATE LOGIC ---
  Future<void> _saveAllChanges() async {
    setState(() => _isLoading = true);
    try {
      String uid = FirebaseAuth.instance.currentUser!.uid;

      // Update Name in Firestore
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'name': _nameController.text.trim(),
      });

      // Update Password if field is not empty
      if (_passwordController.text.isNotEmpty) await _updatePassword();

      // Update Phone if field is not empty
      if (_phoneController.text.isNotEmpty) await _triggerPhoneUpdate();

      if (mounted) Navigator.pop(context);
    } catch (e) {
      _showSnackBar("Update failed: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDFBE7),
      appBar: AppBar(title: const Text("Edit Profile"), backgroundColor: Colors.green),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            _buildTextField(_nameController, "Full Name", Icons.person),
            const SizedBox(height: 15),
            _buildTextField(_phoneController, "New Phone Number", Icons.phone, keyboard: TextInputType.phone),
            const SizedBox(height: 15),
            _buildTextField(_passwordController, "New Password", Icons.lock, isObscure: true),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _saveAllChanges,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                child: _isLoading 
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text("SAVE CHANGES", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, IconData icon, {bool isObscure = false, TextInputType keyboard = TextInputType.text}) {
    return TextField(
      controller: controller,
      obscureText: isObscure,
      keyboardType: keyboard,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.green),
        border: const OutlineInputBorder(),
        focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.green)),
      ),
    );
  }
}