import 'package:flutter/material.dart';
import 'dart:async';

class AudioDetectionScreen extends StatefulWidget {
  const AudioDetectionScreen({super.key});

  @override
  State<AudioDetectionScreen> createState() => _AudioDetectionScreenState();
}

class _AudioDetectionScreenState extends State<AudioDetectionScreen> with SingleTickerProviderStateMixin {
  bool _isListening = false;
  String _statusText = "Ready to analyze frequencies";
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _toggleListening() {
    setState(() {
      _isListening = !_isListening;
      _statusText = _isListening ? "Listening for wingbeat frequencies..." : "Analysis Paused";
    });

    if (_isListening) {
      // Simulate a detection result after 5 seconds
      Timer(const Duration(seconds: 5), () {
        if (mounted && _isListening) {
          setState(() {
            _statusText = "Detected: Aedes Aegypti (85% confidence)";
            _isListening = false;
          });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
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
            
            // Pulsing Mic Icon
            ScaleTransition(
              scale: _isListening 
                  ? Tween(begin: 1.0, end: 1.2).animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut))
                  : const AlwaysStoppedAnimation(1.0),
              child: Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  color: _isListening ? Colors.green.withOpacity(0.1) : Colors.grey[200],
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.green, width: 2),
                ),
                child: Icon(
                  _isListening ? Icons.mic : Icons.mic_none,
                  size: 80,
                  color: Colors.green,
                ),
              ),
            ),
            
            const SizedBox(height: 40),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                _statusText,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, color: Colors.black54),
              ),
            ),
            const SizedBox(height: 60),
            
            ElevatedButton.icon(
              onPressed: _toggleListening,
              icon: Icon(_isListening ? Icons.stop : Icons.play_arrow),
              label: Text(_isListening ? "STOP ANALYSIS" : "START ANALYSIS"),
              style: ElevatedButton.styleFrom(
                backgroundColor: _isListening ? Colors.red : Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}