import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  final User? _user = FirebaseAuth.instance.currentUser;
  late DatabaseReference _dbRef;
  
  bool _isLoading = true;
  String? _errorMessage;

  // Chart data
  List<double> _weeklyCounts = List.filled(7, 0.0); // Mon-Sun
  double _maxCount = 1.0; // To prevent division by zero

  // Distribution data
  List<Map<String, dynamic>> _pestDistribution = [];

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
    // Usually species is like "Anopheles (Malaria Vector)", we can just use the name
    final match = RegExp(r'^([^(]+)\s*\(([^)]+)\)').firstMatch(raw);
    if (match != null) {
      return match.group(2)?.trim() ?? raw; // Show "Malaria Vector" or "Anopheles"
    }
    // Alternatively just show the whole thing
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

      List<DateTime> allDates = [];
      Map<String, int> pestCounts = {};

      // 2. Fetch Audio Detections from RTDB
      for (String deviceId in deviceIds) {
        final event = await _dbRef.child("devices/$deviceId/detections").once();
        final snapshot = event.snapshot;
        if (snapshot.exists && snapshot.value != null) {
          final detVal = Map<dynamic, dynamic>.from(snapshot.value as Map);
          
          detVal.forEach((key, value) {
            final entry = Map<dynamic, dynamic>.from(value as Map);
            
            // Extract Timestamp
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
            allDates.add(date);

            // Extract Species
            String species = entry['species']?.toString() ?? "Unknown";
            String formattedPest = _formatPestName(species);
            pestCounts[formattedPest] = (pestCounts[formattedPest] ?? 0) + 1;
          });
        }
      }

      // 3. Process Weekly Trends (Last 7 Days)
      DateTime now = DateTime.now();
      DateTime startOfToday = DateTime(now.year, now.month, now.day);
      List<double> counts = List.filled(7, 0.0);
      
      for (var date in allDates) {
        DateTime dateStart = DateTime(date.year, date.month, date.day);
        int daysDifference = startOfToday.difference(dateStart).inDays;
        
        // If it's within the last 7 days
        if (daysDifference >= 0 && daysDifference < 7) {
          // weekday is 1(Mon) to 7(Sun)
          int weekDayIndex = date.weekday - 1; 
          counts[weekDayIndex] += 1;
        }
      }
      
      double maxC = 1.0;
      for (var c in counts) {
        if (c > maxC) maxC = c;
      }

      // 4. Process Pest Distribution
      int totalPests = 0;
      pestCounts.forEach((key, value) => totalPests += value);

      List<Map<String, dynamic>> distList = [];
      if (totalPests > 0) {
        // Sort by count descending
        var sortedKeys = pestCounts.keys.toList(growable: false)
          ..sort((k1, k2) => pestCounts[k2]!.compareTo(pestCounts[k1]!));
        
        List<Color> colors = [Colors.red, Colors.orange, Colors.blue, Colors.purple, Colors.teal];
        int colorIdx = 0;

        int limit = 3; // Show top 2 and group rest into "Other Pests" if many
        if (sortedKeys.length <= 3) limit = sortedKeys.length;

        int otherCount = 0;
        for (int i = 0; i < sortedKeys.length; i++) {
          String key = sortedKeys[i];
          int count = pestCounts[key]!;
          
          if (i < 2 || (i == 2 && sortedKeys.length == 3)) {
             double pct = (count / totalPests) * 100;
             distList.add({
               "name": key,
               "percentage": "${pct.toStringAsFixed(0)}%",
               "color": colors[colorIdx % colors.length],
             });
             colorIdx++;
          } else {
            otherCount += count;
          }
        }

        if (otherCount > 0) {
          double pct = (otherCount / totalPests) * 100;
          distList.add({
             "name": "Other Pests",
             "percentage": "${pct.toStringAsFixed(0)}%",
             "color": Colors.blue,
          });
        }
      }

      if (mounted) {
        setState(() {
          _weeklyCounts = counts;
          _maxCount = maxC;
          _pestDistribution = distList;
          _isLoading = false;
        });
      }

    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = "Failed to load analytics: $e";
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDFBE7),
      appBar: AppBar(
        title: const Text("Pest Analytics"),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: Colors.green))
        : _errorMessage != null
          ? Center(child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Weekly Detection Trends", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green)),
                  const SizedBox(height: 20),
                  
                  // Custom Bar Chart
                  Container(
                    height: 200,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.green.withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        _buildBar("Mon", _weeklyCounts[0] / _maxCount),
                        _buildBar("Tue", _weeklyCounts[1] / _maxCount),
                        _buildBar("Wed", _weeklyCounts[2] / _maxCount),
                        _buildBar("Thu", _weeklyCounts[3] / _maxCount),
                        _buildBar("Fri", _weeklyCounts[4] / _maxCount),
                        _buildBar("Sat", _weeklyCounts[5] / _maxCount),
                        _buildBar("Sun", _weeklyCounts[6] / _maxCount),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 30),
                  const Text("Pest Distribution", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green)),
                  const SizedBox(height: 10),
                  
                  if (_pestDistribution.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 20),
                      child: Center(child: Text("No pest data available", style: TextStyle(color: Colors.grey))),
                    )
                  else
                    ..._pestDistribution.map((item) => _buildStatTile(item["name"], item["percentage"], item["color"])),
                ],
              ),
            ),
    );
  }

  Widget _buildBar(String day, double heightFactor) {
    // minimum height so 0 values still have a tiny blip or space
    double h = heightFactor * 150;
    if (h < 5) h = 5;

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Container(
          width: 20,
          height: h,
          decoration: BoxDecoration(color: Colors.green, borderRadius: BorderRadius.circular(5)),
        ),
        const SizedBox(height: 5),
        Text(day, style: const TextStyle(fontSize: 10)),
      ],
    );
  }

  Widget _buildStatTile(String name, String percentage, Color color) {
    return ListTile(
      leading: Icon(Icons.pie_chart, color: color),
      title: Text(name),
      trailing: Text(percentage, style: const TextStyle(fontWeight: FontWeight.bold)),
    );
  }
}