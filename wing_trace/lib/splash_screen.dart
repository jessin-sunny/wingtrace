import 'dart:async';
import 'package:flutter/material.dart';
import 'login_screen.dart'; // Ensure this import is correct

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  double _progress = 0.1; // Starts at 10% based on your SS

  @override
  void initState() {
    super.initState();
    _startLoading();
  }

  void _startLoading() {
    // Timer updates the bar every 30ms for a smooth animation
    Timer.periodic(const Duration(milliseconds: 30), (timer) {
      setState(() {
        if (_progress < 1.0) {
          _progress += 0.01;
        } else {
          timer.cancel();
          _navigateToLogin();
        }
      });
    });
  }

  void _navigateToLogin() {
    // pushReplacement ensures the user can't "Go Back" to the loading screen
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const LoginPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDFBE7),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo and Title
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

              // The Loading Bar
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