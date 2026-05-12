import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

class AccuracySummaryScreen extends StatefulWidget {
  const AccuracySummaryScreen({super.key});

  @override
  State<AccuracySummaryScreen> createState() => _AccuracySummaryScreenState();
}

class _AccuracySummaryScreenState extends State<AccuracySummaryScreen> {
  final User? _user = FirebaseAuth.instance.currentUser;
  late DatabaseReference _dbRef;
  
  bool _isLoading = true;
  String? _errorMessage;

  double _overallAccuracy = 0.0;
  List<Map<String, dynamic>> _speciesAccuracy = [];

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
      // 1. Fetch user's devices
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

      // Add fallback mock device
      if (deviceIds.isEmpty) {
        deviceIds.add("WT12345678");
      }

      double totalConfSum = 0.0;
      int totalCount = 0;
      Map<String, List<double>> speciesConfMap = {};

      // 2. Fetch Audio Detections from RTDB
      for (String deviceId in deviceIds) {
        final event = await _dbRef.child("devices/$deviceId/detections").once();
        final snapshot = event.snapshot;
        if (snapshot.exists && snapshot.value != null) {
          final detVal = Map<dynamic, dynamic>.from(snapshot.value as Map);
          
          detVal.forEach((key, value) {
            final entry = Map<dynamic, dynamic>.from(value as Map);
            
            // Extract Confidence
            double conf = 0.0;
            if (entry['confidence'] != null) {
              conf = double.tryParse(entry['confidence'].toString()) ?? 0.0;
            }
            // Normalize to 0-100 scale if it's 0-1
            if (conf <= 1.0 && conf > 0.0) {
              conf = conf * 100;
            }

            // Extract Species
            String species = entry['species']?.toString() ?? "Unknown";
            String formattedPest = _formatPestName(species);

            totalConfSum += conf;
            totalCount += 1;
            
            if (!speciesConfMap.containsKey(formattedPest)) {
              speciesConfMap[formattedPest] = [];
            }
            speciesConfMap[formattedPest]!.add(conf);
          });
        }
      }

      double overallAvg = 0.0;
      if (totalCount > 0) {
        overallAvg = totalConfSum / totalCount;
      }

      List<Map<String, dynamic>> speciesList = [];
      speciesConfMap.forEach((pest, confList) {
        double sum = 0.0;
        for (var c in confList) sum += c;
        double avg = sum / confList.length;
        speciesList.add({
          "pest": pest,
          "accuracy": avg,
        });
      });

      // Sort alphabetically or by accuracy (let's sort by accuracy descending)
      speciesList.sort((a, b) => (b["accuracy"] as double).compareTo(a["accuracy"] as double));

      if (mounted) {
        setState(() {
          _overallAccuracy = overallAvg;
          _speciesAccuracy = speciesList;
          _isLoading = false;
        });
      }

    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = "Failed to load accuracy data: $e";
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(title: const Text("Accuracy Summary")),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: Colors.green))
        : _errorMessage != null
          ? Center(child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: Colors.green,
                    child: Text("${_overallAccuracy.toStringAsFixed(0)}%", style: const TextStyle(fontSize: 30, color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 20),
                  const Text("Overall Identification Accuracy", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const Divider(height: 40),
                  if (_speciesAccuracy.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 20),
                      child: Text("No detection data available.", style: TextStyle(color: Colors.grey)),
                    )
                  else
                    ..._speciesAccuracy.map((item) => _accuracyTile(item["pest"], "${(item["accuracy"] as double).toStringAsFixed(0)}%")),
                ],
              ),
            ),
    );
  }

  Widget _accuracyTile(String pest, String percentage) {
    return ListTile(
      title: Text(pest),
      trailing: Text(percentage, style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
    );
  }
}