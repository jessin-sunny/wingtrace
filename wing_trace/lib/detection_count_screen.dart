import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

class DetectionCountScreen extends StatefulWidget {
  const DetectionCountScreen({super.key});

  @override
  State<DetectionCountScreen> createState() => _DetectionCountScreenState();
}

class _DetectionCountScreenState extends State<DetectionCountScreen> {
  final User? _user = FirebaseAuth.instance.currentUser;
  late DatabaseReference _dbRef;
  
  bool _isLoading = true;
  String? _errorMessage;

  int _imageCount = 0;
  int _audioCount = 0;

  @override
  void initState() {
    super.initState();
    _dbRef = FirebaseDatabase.instanceFor(
      app: Firebase.app(),
      databaseURL: 'https://wingtrace-ead16-default-rtdb.firebaseio.com',
    ).ref();
    _fetchData();
  }

  Future<void> _fetchData() async {
    if (_user == null) {
      setState(() {
        _errorMessage = "User not logged in.";
        _isLoading = false;
      });
      return;
    }

    try {
      DateTime now = DateTime.now();
      DateTime startOfToday = DateTime(now.year, now.month, now.day);
      int imgCount = 0;
      int audCount = 0;

      // 1. Fetch Today's Image Detections (Firestore)
      final fsQuery = await FirebaseFirestore.instance
          .collection('detections')
          .where('userId', isEqualTo: _user!.uid)
          .get();

      // Filter in memory to avoid needing a composite index
      for (var doc in fsQuery.docs) {
        final data = doc.data();
        if (data['timestamp'] != null) {
          DateTime d = (data['timestamp'] as Timestamp).toDate();
          if (d.isAfter(startOfToday) || d.isAtSameMomentAs(startOfToday)) {
            imgCount++;
          }
        }
      }

      // 2. Fetch Today's Audio Detections (RTDB)
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(_user!.uid).get();
      List<String> deviceIds = [];
      if (userDoc.exists) {
        final data = userDoc.data()!;
        if (data.containsKey('devices') && (data['devices'] as List).isNotEmpty) {
          for (var d in data['devices']) {
            deviceIds.add(d.toString());
          }
        }
      }
      if (deviceIds.isEmpty) {
        deviceIds.add("WT12345678");
      }

      for (String deviceId in deviceIds) {
        final event = await _dbRef.child("devices/$deviceId/detections").once();
        final snapshot = event.snapshot;
        if (snapshot.exists && snapshot.value != null) {
          final detVal = Map<dynamic, dynamic>.from(snapshot.value as Map);
          
          detVal.forEach((key, value) {
            final entry = Map<dynamic, dynamic>.from(value as Map);
            
            DateTime date = DateTime.now();
            if (entry['timestamp'] != null) {
              int ts = int.tryParse(entry['timestamp'].toString()) ?? 0;
              if (ts > 0) {
                 if (ts < 2000000000) {
                   date = DateTime.fromMillisecondsSinceEpoch(ts * 1000);
                 } else {
                   date = DateTime.fromMillisecondsSinceEpoch(ts);
                 }
              }
            }

            if (date.isAfter(startOfToday) || date.isAtSameMomentAs(startOfToday)) {
              audCount++;
            }
          });
        }
      }

      if (mounted) {
        setState(() {
          _imageCount = imgCount;
          _audioCount = audCount;
          _isLoading = false;
        });
      }

    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = "Failed to load data: $e";
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    int totalCount = _imageCount + _audioCount;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(title: const Text("Detections Today")),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: Colors.green))
        : _errorMessage != null
          ? Center(child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)))
          : Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("Total Combined Scans Today", style: TextStyle(fontSize: 20, color: Colors.grey)),
                  Text("$totalCount", style: const TextStyle(fontSize: 80, fontWeight: FontWeight.bold, color: Colors.green)),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 25),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.camera_alt, color: Colors.blue, size: 20),
                        const SizedBox(width: 8),
                        Text("$_imageCount Camera", style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 15),
                          child: Text("|", style: TextStyle(color: Colors.grey, fontSize: 20)),
                        ),
                        const Icon(Icons.mic, color: Colors.orange, size: 20),
                        const SizedBox(width: 8),
                        Text("$_audioCount Audio", style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}