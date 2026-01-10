import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart'; // 1. Add Auth
import 'package:cloud_firestore/cloud_firestore.dart'; // 2. Add Firestore
import 'login_screen.dart';
import 'user_dashboard.dart';    // 3. Import Dashboards
import 'officer_dashboard.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  double _progress = 0.1; 

  @override
  void initState() {
    super.initState();
    _startLoading();
  }

  void _startLoading() {
    // Timer updates the bar every 30ms for a smooth animation
    Timer.periodic(const Duration(milliseconds: 30), (timer) {
      if (mounted) { // Check if widget is still on screen
        setState(() {
          if (_progress < 1.0) {
            _progress += 0.01;
          } else {
            timer.cancel();
            _checkLoginStatus(); // CHANGED: Call the smart check function
          }
        });
      }
    });
  }

  // NEW: Smart Navigation Logic
  Future<void> _checkLoginStatus() async {
    // 1. Check if user is logged in
    User? currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      // Not logged in? Go to Login
      _navigate(const LoginPage());
    } else {
      // 2. Logged in? Check their role in Database
      try {
        DocumentSnapshot userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .get();

        if (userDoc.exists) {
          String role = userDoc.get('role');
          
          // 3. Route to correct Dashboard
          if (role == 'officer' || role == 'admin') {
            _navigate(const OfficerDashboard());
          } else {
            _navigate(const UserDashboard());
          }
        } else {
          // Fallback if DB record is missing
          _navigate(const UserDashboard());
        }
      } catch (e) {
        // If error (e.g., no internet), go to Login safely
        _navigate(const LoginPage());
      }
    }
  }

  void _navigate(Widget screen) {
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => screen),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // YOUR UI CODE REMAINS EXACTLY THE SAME
    return Scaffold(
      backgroundColor: const Color(0xFFFDFBE7),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.webhook, size: 100, color: Colors.green),
              const Text(
                'WingTrace',
                style: TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
              const Text(
                'An Automated System for\nMosquito and Pest Identification',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.green, fontSize: 16),
              ),
              const SizedBox(height: 80),

              Stack(
                alignment: Alignment.centerRight,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: LinearProgressIndicator(
                      value: _progress,
                      minHeight: 30,
                      backgroundColor: Colors.white,
                      color: Colors.green,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(right: 20),
                    child: Text(
                      '${(_progress * 100).toInt()}%',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const Text('loading app', style: TextStyle(color: Colors.black54)),
            ],
          ),
        ),
      ),
    );
  }
}