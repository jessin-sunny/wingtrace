import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import 'user_dashboard.dart';
import 'officer_dashboard.dart';
import 'device_setup_screen.dart'; // Import the new setup screen

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final AuthService _authService = AuthService();
  
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPassController = TextEditingController();

  final List<String> _roles = ['Regular User', 'Agricultural/Health Officer'];
  final List<String> _officerTypes = ['health', 'agriculture'];
  String? _selectedRole;
  String? _selectedOfficerType;
  String? _selectedDistrict;
  String? _selectedCommunityId;
  String? _selectedCommunityName;
  bool _isLoadingCommunities = false;
  final List<Map<String, String>> _communities = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadCommunities();
  }

  Future<void> _loadCommunities() async {
    setState(() => _isLoadingCommunities = true);
    try {
      final snapshot = await FirebaseFirestore.instance.collection('communities').get();
      _communities.clear();
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final name = data['name']?.toString() ?? doc.id;
        final district = data['district']?.toString() ?? 'Unknown';
        _communities.add({
          'id': doc.id,
          'name': name,
          'district': district,
        });
      }
    } catch (_) {
      // Keep list empty; UI will show no communities.
    }
    if (mounted) setState(() => _isLoadingCommunities = false);
  }

  List<String> get _districts {
    final set = <String>{};
    for (final entry in _communities) {
      final district = entry['district'];
      if (district != null && district.isNotEmpty) set.add(district);
    }
    final list = set.toList()..sort();
    return list;
  }

  List<Map<String, String>> get _filteredCommunities {
    if (_selectedDistrict == null) return [];
    return _communities.where((c) => c['district'] == _selectedDistrict).toList();
  }

  // --- UPDATED LOGIC ---
  void _handleSignUp() async {
    // 1. Check if fields are empty
    if (_nameController.text.isEmpty || 
        _emailController.text.isEmpty || 
        _phoneController.text.isEmpty || 
        _passwordController.text.isEmpty ||
        _selectedRole == null ||
        _selectedDistrict == null ||
        _selectedCommunityId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please fill all fields")));
      return;
    }

    // 2. NEW: Check Phone Number (10 digits)
    String phone = _phoneController.text.trim();
    if (!RegExp(r'^[0-9]{10}$').hasMatch(phone)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter a valid 10-digit mobile number"))
      );
      return;
    }

    // 3. NEW: Check Email Format
    String email = _emailController.text.trim();
    if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(email)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter a valid email address"))
      );
      return;
    }

    // 4. NEW: Check Password Length (Firebase needs 6+)
    if (_passwordController.text.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Password must be at least 6 characters"))
      );
      return;
    }

    // 5. Check Passwords Match
    if (_passwordController.text != _confirmPassController.text) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Passwords do not match")));
      return;
    }

    if (_selectedRole == 'Agricultural/Health Officer' && _selectedOfficerType == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Select officer type")));
      return;
    }

    setState(() => _isLoading = true);

    String dbRole = (_selectedRole == 'Agricultural/Health Officer') ? 'officer' : 'farmer';
    DateTime now = DateTime.now();
    // 6. Call Firebase
    // String? error = await _authService.signUp(
    //   email,
    //   _passwordController.text.trim(),
    //   _nameController.text.trim(),
    //   dbRole 
    // );
    Map<String, dynamic> userMap = {
      "name": _nameController.text.trim(),
      "emailid": _emailController.text.trim(),
      "phoneno": "+91$phone", // Added prefix as per your requirement
      "role": dbRole,
      "officerType": dbRole == 'officer' ? _selectedOfficerType : null,
      "communityID": _selectedCommunityId,
      "communityId": _selectedCommunityId,
      "communityName": _selectedCommunityName,
      "district": _selectedDistrict,
      "profilePic": "assets/profile_pics/p1.png", // Default avatar
      "devices": [], // Empty array for new user
      "lastLogin": now, // Firestore handles DateTime objects or Strings
      "createdAt": now,
      "updatedAt": now,
    };

    if (dbRole == 'officer') {
      final isAvailable = await _validateOfficerSlot(
        _selectedCommunityId!,
        _selectedOfficerType!,
      );
      if (!isAvailable) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Officer slot already taken for this community")),
        );
        return;
      }
    }
    String? error = await _authService.signUp(
      userMap["emailid"],
      _passwordController.text.trim(),
      userMap // Passing the map to match the new structure
    );

    if (!mounted) return;

    if (error == null) {
      if (dbRole == 'officer') {
        await _assignOfficerToCommunity(
          _selectedCommunityId!,
          _selectedOfficerType!,
        );
      }
      // Success Logic
      if (dbRole == 'officer') {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const OfficerDashboard()));
      } else {
        bool isHardwareNearby = await _checkForNearbyDevice(); 

        setState(() => _isLoading = false);

        if (isHardwareNearby) {
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const DeviceSetupScreen()));
        } else {
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const UserDashboard()));
        }
      }
    } else {
      // Error Logic
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
    }
  }

  Future<bool> _validateOfficerSlot(String communityId, String officerType) async {
    try {
      final doc = await FirebaseFirestore.instance.collection('communities').doc(communityId).get();
      final data = doc.data() as Map<String, dynamic>?;
      final officers = data?['officers'] is Map ? Map<String, dynamic>.from(data?['officers']) : <String, dynamic>{};
      final existing = officers[officerType]?.toString();
      return existing == null || existing.isEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<void> _assignOfficerToCommunity(String communityId, String officerType) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await FirebaseFirestore.instance.collection('communities').doc(communityId).set({
      'officers': {officerType: uid}
    }, SetOptions(merge: true));
  }

  // Simulated Bluetooth/WiFi scan
  Future<bool> _checkForNearbyDevice() async {
    await Future.delayed(const Duration(seconds: 2));
    return true; // Simulate finding a WingTrace module
  }
  // --- END LOGIC ---

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
                  child: Image.asset(
                    'assets/logo.png',
                    height: 170,
                    width: 170,
                    errorBuilder: (context, error, stackTrace) => 
                        const Icon(Icons.webhook, size: 80, color: Colors.green),
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
                      TextField(controller: _nameController, decoration: const InputDecoration(hintText: 'Full Name')),
                      TextField(controller: _emailController, decoration: const InputDecoration(hintText: 'Email/username')),
                      TextField(
                        controller: _phoneController,
                        decoration: const InputDecoration(
                        hintText: 'Mobile No.',
                        counterText: "", // Hides the "0/10" counter text
                        ),
                        keyboardType: TextInputType.number, // Shows number pad
                        maxLength: 10, // Limits input to 10 chars automatically
                        ),
                      if (_isLoadingCommunities)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: LinearProgressIndicator(),
                        ),
                      DropdownButtonFormField<String>(
                        value: _selectedDistrict,
                        hint: const Text('Select District'),
                        items: _districts
                            .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                            .toList(),
                        onChanged: (val) {
                          setState(() {
                            _selectedDistrict = val;
                            _selectedCommunityId = null;
                            _selectedCommunityName = null;
                          });
                        },
                      ),
                      DropdownButtonFormField<String>(
                        value: _selectedCommunityId,
                        hint: const Text('Select Community'),
                        items: _filteredCommunities
                            .map((c) => DropdownMenuItem(value: c['id'], child: Text(c['name'] ?? c['id']!)))
                            .toList(),
                        onChanged: (val) {
                          setState(() {
                            _selectedCommunityId = val;
                            _selectedCommunityName = _filteredCommunities
                                .firstWhere((c) => c['id'] == val, orElse: () => {})['name'];
                          });
                        },
                      ),
                      DropdownButtonFormField<String>(
                        value: _selectedRole,
                        hint: const Text('Select Role'),
                        items: _roles.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                        onChanged: (val) {
                          setState(() {
                            _selectedRole = val;
                            if (val != 'Agricultural/Health Officer') {
                              _selectedOfficerType = null;
                            }
                          });
                        },
                      ),
                      if (_selectedRole == 'Agricultural/Health Officer')
                        DropdownButtonFormField<String>(
                          value: _selectedOfficerType,
                          hint: const Text('Select Officer Type'),
                          items: _officerTypes
                              .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                              .toList(),
                          onChanged: (val) => setState(() => _selectedOfficerType = val),
                        ),
                      TextField(controller: _passwordController, obscureText: true, decoration: const InputDecoration(hintText: 'Password')),
                      TextField(controller: _confirmPassController, obscureText: true, decoration: const InputDecoration(hintText: 'Confirm Password')),
                      const SizedBox(height: 25),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _handleSignUp,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green[700],
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                          ),
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