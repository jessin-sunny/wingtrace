import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';

class DeviceDetailsScreen extends StatefulWidget {
  final String deviceId;
  final bool initialStatus;

  const DeviceDetailsScreen({super.key, required this.deviceId, required this.initialStatus});

  @override
  State<DeviceDetailsScreen> createState() => _DeviceDetailsScreenState();
}

class _DeviceDetailsScreenState extends State<DeviceDetailsScreen> {
  bool _isOnline = false;
  bool _isLoading = false;
  final String serverUrl = "https://wingtrace-production.up.railway.app";

  @override
  void initState() {
    super.initState();
    _isOnline = widget.initialStatus;
  }

  Future<void> _toggleConnection() async {
    setState(() => _isLoading = true);
    final user = FirebaseAuth.instance.currentUser;
    
    // If online, call /disconnect. (Note: To reconnect, your hardware usually auto-reconnects on boot)
    final String endpoint = _isOnline ? "/disconnect" : "/reconnect"; 
    
    try {
      final response = await http.post(
        Uri.parse("$serverUrl$endpoint"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"deviceId": widget.deviceId, "userId": user?.uid}),
      );

      if (response.statusCode == 200) {
        setState(() => _isOnline = !_isOnline);
      } else {
        _showError(jsonDecode(response.body)['error'] ?? "Action failed");
      }
    } catch (e) {
      _showError("Server unreachable");
    }
    setState(() => _isLoading = false);
  }

  Future<void> _resetDevice() async {
    setState(() => _isLoading = true);
    final user = FirebaseAuth.instance.currentUser;

    try {
      final response = await http.post(
        Uri.parse("$serverUrl/reset"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"deviceId": widget.deviceId, "userId": user?.uid}),
      );

      if (response.statusCode == 200) {
        // Remove from Firestore locally after server queues reset
        await FirebaseFirestore.instance.collection('users').doc(user!.uid).update({
          'hasCompletedSetup': false,
          'devices': FieldValue.arrayRemove([widget.deviceId])
        });
        if (mounted) Navigator.popUntil(context, (route) => route.isFirst);
      } else {
        _showError(jsonDecode(response.body)['error'] ?? "Reset failed");
      }
    } catch (e) {
      _showError("Connection error");
    }
    setState(() => _isLoading = false);
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDFBE7),
      appBar: AppBar(title: Text(widget.deviceId), backgroundColor: Colors.green),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Icon(Icons.developer_board, size: 100, color: Colors.green),
            const SizedBox(height: 20),
            Text("Status: ${_isOnline ? "ONLINE" : "OFFLINE"}", 
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: _isOnline ? Colors.green : Colors.red)),
            const Divider(height: 40),
            ListTile(
              title: const Text("Connection Control"),
              subtitle: Text(_isOnline ? "Disconnect device from server" : "Wait for device to heartbeat"),
              trailing: _isLoading 
                ? const CircularProgressIndicator() 
                : Switch(value: _isOnline, onChanged: (val) => _toggleConnection()),
            ),
            const Spacer(),
            ElevatedButton(
              onPressed: _isLoading ? null : _resetDevice,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
              child: const Text("RESET & UNLINK DEVICE"),
            ),
          ],
        ),
      ),
    );
  }
}