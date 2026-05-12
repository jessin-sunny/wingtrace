import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

class LastDetectedScreen extends StatefulWidget {
  const LastDetectedScreen({super.key});

  @override
  State<LastDetectedScreen> createState() => _LastDetectedScreenState();
}

class _LastDetectedScreenState extends State<LastDetectedScreen> {
  final User? _user = FirebaseAuth.instance.currentUser;
  late DatabaseReference _dbRef;
  
  bool _isLoading = true;
  String? _errorMessage;

  Map<String, dynamic>? _latestImage;
  Map<String, dynamic>? _latestAudio;

  @override
  void initState() {
    super.initState();
    _dbRef = FirebaseDatabase.instanceFor(
      app: Firebase.app(),
      databaseURL: 'https://wingtrace-ead16-default-rtdb.firebaseio.com',
    ).ref();
    _fetchData();
  }

  String _formatPestName(String raw) {
    if (raw.isEmpty) return "Unknown";
    final match = RegExp(r'^([^(]+)\s*\(([^)]+)\)').firstMatch(raw);
    if (match != null) {
      return match.group(2)?.trim() ?? raw;
    }
    return raw.replaceAll('_', ' ');
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
      // 1. Fetch Latest Image Detection (Firestore)
      Map<String, dynamic>? latestImg;
      final fsQuery = await FirebaseFirestore.instance
          .collection('detections')
          .where('userId', isEqualTo: _user!.uid)
          .get();

      if (fsQuery.docs.isNotEmpty) {
        // Find the most recent document in memory to avoid needing a composite index
        var docs = fsQuery.docs;
        docs.sort((a, b) {
          Timestamp tA = a.data()['timestamp'] as Timestamp? ?? Timestamp(0, 0);
          Timestamp tB = b.data()['timestamp'] as Timestamp? ?? Timestamp(0, 0);
          return tB.compareTo(tA); // Descending
        });

        final doc = docs.first.data();
        DateTime date = DateTime.now();
        if (doc['timestamp'] != null) {
          date = (doc['timestamp'] as Timestamp).toDate();
        }
        
        double conf = 0.0;
        if (doc['confidence'] != null) {
           conf = double.tryParse(doc['confidence'].toString()) ?? 0.0;
        }
        if (conf <= 1.0 && conf > 0.0) conf = conf * 100;

        latestImg = {
          'pest': _formatPestName(doc['pest_name']?.toString() ?? "Unknown"),
          'date': date,
          'confidence': "${conf.toStringAsFixed(0)}%",
        };
      }

      // 2. Fetch Latest Audio Detection (RTDB)
      Map<String, dynamic>? latestAud;
      DateTime? latestAudDate;

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

            if (latestAudDate == null || date.isAfter(latestAudDate!)) {
              latestAudDate = date;
              
              double conf = 0.0;
              if (entry['confidence'] != null) {
                conf = double.tryParse(entry['confidence'].toString()) ?? 0.0;
              }
              if (conf <= 1.0 && conf > 0.0) conf = conf * 100;

              String species = entry['species']?.toString() ?? "Unknown";

              latestAud = {
                'pest': _formatPestName(species),
                'date': date,
                'confidence': "${conf.toStringAsFixed(0)}%",
              };
            }
          });
        }
      }

      if (mounted) {
        setState(() {
          _latestImage = latestImg;
          _latestAudio = latestAud;
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
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(title: const Text("Last Detected Pest")),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: Colors.green))
        : _errorMessage != null
          ? Center(child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text("Latest Camera Scan", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green)),
                  const SizedBox(height: 10),
                  _buildDetectionCard(_latestImage, Icons.camera_alt, Colors.blue),
                  
                  const SizedBox(height: 30),
                  
                  const Text("Latest Audio Scan", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green)),
                  const SizedBox(height: 10),
                  _buildDetectionCard(_latestAudio, Icons.mic, Colors.orange),
                ],
              ),
            ),
    );
  }

  Widget _buildDetectionCard(Map<String, dynamic>? data, IconData icon, Color color) {
    if (data == null) {
      return Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: const Padding(
          padding: EdgeInsets.all(30.0),
          child: Center(child: Text("No detections yet", style: TextStyle(color: Colors.grey))),
        ),
      );
    }

    String timeStr = _formatDate(data['date'] as DateTime);

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 120,
            width: double.infinity,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Icon(icon, size: 60, color: color.withOpacity(0.5)),
          ),
          ListTile(
            title: Text(data['pest'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22)),
            subtitle: Text("Detected at $timeStr"),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 16.0),
            child: Text(
              "This pest was identified with ${data['confidence']} confidence by the WingTrace AI model.",
              style: const TextStyle(color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime d) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    String month = months[d.month - 1];
    String hour = d.hour > 12 ? '${d.hour - 12}' : '${d.hour == 0 ? 12 : d.hour}';
    String min = d.minute.toString().padLeft(2, '0');
    String ampm = d.hour >= 12 ? 'PM' : 'AM';
    return '$month ${d.day}, ${d.year} • $hour:$min $ampm';
  }
}