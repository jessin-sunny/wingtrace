import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'user_dashboard.dart';

class DeviceSetupScreen extends StatefulWidget {
  const DeviceSetupScreen({super.key});

  @override
  State<DeviceSetupScreen> createState() => _DeviceSetupScreenState();
}

class _DeviceSetupScreenState extends State<DeviceSetupScreen> {
  int _currentStep = 0;
  bool _isScanning = false;
  bool _deviceFound = false;

  // 1. Logic to finalize setup in Firestore
  Future<void> _completeSetup() async {
    setState(() => _isScanning = true);
    
    // Simulate final handshake/communication with hardware
    await Future.delayed(const Duration(seconds: 3));

    try {
      String uid = FirebaseAuth.instance.currentUser!.uid;
      
      // Mark setup as finished in the user's document
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'hasCompletedSetup': true, 
      });

      if (mounted) {
        // Navigate to dashboard and clear the navigation stack
        Navigator.pushReplacement(
          context, 
          MaterialPageRoute(builder: (_) => const UserDashboard())
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Setup failed: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isScanning = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDFBE7),
      appBar: AppBar(
        title: const Text("Hardware Setup"),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false, // Prevents user from leaving mid-setup
      ),
      body: Stepper(
        type: StepperType.vertical,
        currentStep: _currentStep,
        // Customizing the controls to make them WingTrace themed
        controlsBuilder: (context, details) {
          return Padding(
            padding: const EdgeInsets.only(top: 20),
            child: Row(
              children: [
                ElevatedButton(
                  onPressed: details.onStepContinue,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                  child: Text(_currentStep == 2 ? "FINISH" : "CONTINUE", style: const TextStyle(color: Colors.white)),
                ),
                if (_currentStep > 0)
                  TextButton(
                    onPressed: details.onStepCancel,
                    child: const Text("BACK", style: TextStyle(color: Colors.grey)),
                  ),
              ],
            ),
          );
        },
        onStepContinue: () {
          if (_currentStep == 1 && !_deviceFound) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Please scan and find the device first.")),
            );
            return;
          }

          if (_currentStep < 2) {
            setState(() => _currentStep += 1);
          } else {
            _completeSetup();
          }
        },
        onStepCancel: () {
          if (_currentStep > 0) setState(() => _currentStep -= 1);
        },
        steps: [
          Step(
            title: const Text("Step 1: Power On"),
            subtitle: const Text("Hardware Preparation"),
            content: const Text("Ensure your WingTrace hardware is plugged into a power source and the green LED is blinking."),
            isActive: _currentStep >= 0,
            state: _currentStep > 0 ? StepState.complete : StepState.indexed,
          ),
          Step(
            title: const Text("Step 2: Connect"),
            subtitle: const Text("Bluetooth/WiFi Discovery"),
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("The app will now look for nearby WingTrace v1 modules."),
                const SizedBox(height: 15),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      // Simulating a scan process
                      setState(() => _deviceFound = true);
                    },
                    icon: Icon(_deviceFound ? Icons.check_circle : Icons.search, color: Colors.white),
                    label: Text(_deviceFound ? "WingTrace Found!" : "Scan for Device", style: const TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _deviceFound ? Colors.blue : Colors.green,
                    ),
                  ),
                )
              ],
            ),
            isActive: _currentStep >= 1,
            state: _currentStep > 1 ? StepState.complete : StepState.indexed,
          ),
          Step(
            title: const Text("Step 3: Register"),
            subtitle: const Text("Link to Account"),
            content: _isScanning 
              ? const Column(
                  children: [
                    CircularProgressIndicator(color: Colors.green),
                    SizedBox(height: 10),
                    Text("Registering device to your cloud profile..."),
                  ],
                )
              : const Text("Click 'FINISH' to securely link this hardware to your WingTrace account."),
            isActive: _currentStep >= 2,
            state: _currentStep == 2 ? StepState.editing : StepState.indexed,
          ),
        ],
      ),
    );
  }
}