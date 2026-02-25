import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'dart:convert';
import 'dart:async';

class AudioDetectionScreen extends StatefulWidget {
  const AudioDetectionScreen({super.key});

  @override
  State<AudioDetectionScreen> createState() => _AudioDetectionScreenState();
}

class _AudioDetectionScreenState extends State<AudioDetectionScreen> with SingleTickerProviderStateMixin {
  String _statusText = "Initializing...";
  bool _isLoading = false;
  String? _deviceId;
  late AnimationController _pulseController;
  final String _serverUrl = "https://wingtrace.onrender.com";

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _fetchDeviceId();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  // 1. Fetch the linked device ID from Firestore
  Future<void> _fetchDeviceId() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (userDoc.exists) {
        final data = userDoc.data();
        if (data != null && data['devices'] != null && (data['devices'] as List).isNotEmpty) {
          setState(() {
            _deviceId = data['devices'][0];
            _statusText = "Ready to analyze frequencies";
          });
        }
      }
    } catch (e) {
      setState(() => _statusText = "Error loading device ID");
    }
  }

  // 2. Control Logic (Calls your Python server endpoints)
  Future<void> _toggleAudioCommand(bool start) async {
    if (_deviceId == null) return;

    setState(() => _isLoading = true);
    final String endpoint = start ? "/startAudio" : "/stopAudio";
    final String userId = FirebaseAuth.instance.currentUser?.uid ?? "";

    try {
      final response = await http.post(
        Uri.parse("$_serverUrl$endpoint"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "deviceId": _deviceId,
          "userId": userId,
        }),
      );

      if (response.statusCode != 200) {
        final error = jsonDecode(response.body)['error'] ?? "Command failed";
        _showSnackBar(error);
      }
    } catch (e) {
      _showSnackBar("Connection error: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    if (_deviceId == null) {
      return Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // 3. Listen to RTDB for real-time recording status
    return StreamBuilder<DatabaseEvent>(
      stream: FirebaseDatabase.instance.ref("devices/$_deviceId/audio").onValue,
      builder: (context, snapshot) {
        bool isRecording = false;
        if (snapshot.hasData && snapshot.data!.snapshot.value != null) {
          final data = Map<dynamic, dynamic>.from(snapshot.data!.snapshot.value as Map);
          isRecording = data['isRecording'] ?? false;
        }

        return Scaffold(
          backgroundColor: const Color(0xFFFDFBE7),
          appBar: AppBar(
            title: const Text("Audio Detection"),
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
          ),
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  "Wingbeat Frequency Analysis",
                  style: TextStyle(color: Colors.green[800], fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 40),
                
                // Pulsing Mic Icon depends on RTDB isRecording status
                ScaleTransition(
                  scale: isRecording 
                      ? Tween(begin: 1.0, end: 1.2).animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut))
                      : const AlwaysStoppedAnimation(1.0),
                  child: Container(
                    width: 150,
                    height: 150,
                    decoration: BoxDecoration(
                      color: isRecording ? Colors.green.withOpacity(0.1) : Colors.grey[200],
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.green, width: 2),
                    ),
                    child: Icon(
                      isRecording ? Icons.mic : Icons.mic_none,
                      size: 80,
                      color: Colors.green,
                    ),
                  ),
                ),
                
                const SizedBox(height: 40),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Text(
                    isRecording ? "Listening for wingbeat frequencies..." : _statusText,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 16, color: Colors.black54),
                  ),
                ),
                const SizedBox(height: 60),
                
                _isLoading 
                ? const CircularProgressIndicator(color: Colors.green)
                : ElevatedButton.icon(
                  onPressed: () => _toggleAudioCommand(!isRecording),
                  icon: Icon(isRecording ? Icons.stop : Icons.play_arrow),
                  label: Text(isRecording ? "STOP ANALYSIS" : "START ANALYSIS"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isRecording ? Colors.red : Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}