import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'pest_details_screen.dart';

class DetectionItem {
  final String pest;
  final DateTime date;
  final String confidence;
  final String type; // "Image" or "Audio"
  final String? category;
  final String? rawPestType;

  DetectionItem({
    required this.pest,
    required this.date,
    required this.confidence,
    required this.type,
    this.category,
    this.rawPestType,
  });
}

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final User? _user = FirebaseAuth.instance.currentUser;
  final DatabaseReference _dbRef = FirebaseDatabase.instanceFor(
    app: Firebase.app(),
    databaseURL: 'https://wingtrace-ead16-default-rtdb.firebaseio.com',
  ).ref();
  
  List<DetectionItem> _allItems = [];
  bool _isLoading = true;
  String? _errorMessage;

  String _selectedType = "All"; // "All", "Image", "Audio"
  String _selectedTime = "All Time"; // "1 Day", "7 Days", "30 Days", "All Time"

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  String _formatPestName(String raw) {
    if (raw.isEmpty) return "Unknown";
    return raw
        .replaceAll(RegExp(r'[_\-]'), ' ')
        .split(' ')
        .where((w) => w.isNotEmpty)
        .map((w) => '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}')
        .join(' ');
  }

  Future<void> _fetchData() async {
    if (_user == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      List<DetectionItem> items = [];

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

      // Add fallback mock device if no devices are linked
      if (deviceIds.isEmpty) {
        deviceIds.add("WT12345678");
      }

      // 2. Fetch Audio Detections from RTDB
      try {
        for (String deviceId in deviceIds) {
          final event = await _dbRef.child("devices/$deviceId/detections").once();
          final snapshot = event.snapshot;
          if (snapshot.exists && snapshot.value != null) {
            final detVal = Map<dynamic, dynamic>.from(snapshot.value as Map);
            
            detVal.forEach((key, value) {
              final entry = Map<dynamic, dynamic>.from(value as Map);
              double conf = 0.0;
              if (entry['confidence'] != null) {
                conf = double.tryParse(entry['confidence'].toString()) ?? 0.0;
              }
              String confStr = "${(conf * 100).toStringAsFixed(0)}%";

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
              
              String pestName = entry['species']?.toString() ?? "Unknown";

              items.add(DetectionItem(
                pest: _formatPestName(pestName),
                date: date,
                confidence: confStr,
                type: "Audio",
                category: entry['category']?.toString() ?? pestName.split('→').last.trim(),
                rawPestType: "Audio Detection",
              ));
            });
          }
        }
      } catch (e) {
        debugPrint("RTDB Fetch Error: $e");
      }

      // 3. Fetch Image Detections from Firestore
      try {
        final imageQuery = await FirebaseFirestore.instance
            .collection('detections')
            .where('userId', isEqualTo: _user!.uid)
            .get();
        
        for (var doc in imageQuery.docs) {
          final data = doc.data();
          
          String pestName = data['category']?.toString() ?? data['pest_name']?.toString() ?? "Unknown";
          
          double conf = 0.0;
          if (data['confidence'] != null) {
             conf = double.tryParse(data['confidence'].toString()) ?? 0.0;
          }
          String confStr = "${(conf * 100).toStringAsFixed(0)}%";

          DateTime date = DateTime.now();
          if (data['timestamp'] != null) {
            if (data['timestamp'] is Timestamp) {
              date = (data['timestamp'] as Timestamp).toDate();
            }
          }

          items.add(DetectionItem(
            pest: _formatPestName(pestName),
            date: date,
            confidence: confStr,
            type: "Image",
            category: data['category']?.toString(),
            rawPestType: "Image Detection",
          ));
        }
      } catch (e) {
        debugPrint("Firestore Fetch Error: $e");
        _errorMessage = (_errorMessage ?? "") + "Firestore Error: $e";
      }

      // Sort by date descending
      items.sort((a, b) => b.date.compareTo(a.date));

      if (mounted) {
        setState(() {
          _allItems = items;
          _isLoading = false;
        });
      }

    } catch (e) {
      debugPrint("General Error fetching history: $e");
      if (mounted) {
        setState(() {
          _errorMessage = "General Error: $e";
          _isLoading = false;
        });
      }
    }
  }

  List<DetectionItem> get _filteredItems {
    DateTime now = DateTime.now();
    // Reset to start of day for accurate day comparisons
    DateTime startOfToday = DateTime(now.year, now.month, now.day);

    return _allItems.where((item) {
      // Filter by Type
      if (_selectedType != "All" && item.type != _selectedType) return false;

      // Filter by Date
      if (_selectedTime != "All Time") {
        int days = 0;
        if (_selectedTime == "1 Day") days = 1;
        else if (_selectedTime == "7 Days") days = 7;
        else if (_selectedTime == "30 Days") days = 30;

        DateTime itemDateStartOfDay = DateTime(item.date.year, item.date.month, item.date.day);
        if (startOfToday.difference(itemDateStartOfDay).inDays >= days) return false;
      }

      return true;
    }).toList();
  }

  String _formatDate(DateTime time) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return "${months[time.month - 1]} ${time.day}, ${time.year}";
  }

  Future<void> _openPestDetails(DetectionItem item) async {
    if (item.category == null || item.category!.isEmpty) return;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator(color: Colors.green)),
    );

    try {
      final docId = item.category!.toLowerCase().replaceAll(' ', '_');
      final docSnapshot = await FirebaseFirestore.instance
          .collection('categories')
          .doc(docId)
          .get()
          .timeout(const Duration(seconds: 15));

      if (mounted) Navigator.pop(context); // pop loading dialog

      Map<String, dynamic>? pestInfo;
      if (docSnapshot.exists) {
        pestInfo = docSnapshot.data();
      }

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PestDetailsScreen(
              imageFile: null, // No image stored
              pestType: item.rawPestType ?? "Unknown",
              pestCategory: item.category!,
              pestInfo: pestInfo,
              source: item.type.toLowerCase(),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load details: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredItems;

    return Scaffold(
      backgroundColor: const Color(0xFFFDFBE7),
      appBar: AppBar(
        title: const Text("Detection History"),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Filters
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: ["All", "Image", "Audio"].map((type) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4.0),
                      child: ChoiceChip(
                        label: Text(type, style: TextStyle(color: _selectedType == type ? Colors.white : Colors.black87)),
                        selected: _selectedType == type,
                        selectedColor: Colors.green,
                        backgroundColor: Colors.white,
                        onSelected: (bool selected) {
                          setState(() => _selectedType = type);
                        },
                      ),
                    );
                  }).toList(),
                ),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: ["1 Day", "7 Days", "30 Days", "All Time"].map((time) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4.0),
                        child: ChoiceChip(
                          label: Text(time, style: TextStyle(color: _selectedTime == time ? Colors.white : Colors.black87)),
                          selected: _selectedTime == time,
                          selectedColor: Colors.green,
                          backgroundColor: Colors.white,
                          onSelected: (bool selected) {
                            setState(() => _selectedTime = time);
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
          // List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Colors.green))
                : filtered.isEmpty
                    ? const Center(child: Text("No detections found.", style: TextStyle(color: Colors.grey)))
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final item = filtered[index];
                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: item.type == "Audio" ? Colors.blue : Colors.green,
                                child: Icon(
                                  item.type == "Audio" ? Icons.mic : Icons.bug_report, 
                                  color: Colors.white
                                ),
                              ),
                              title: Text(item.pest, style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text("Date: ${_formatDate(item.date)}"),
                              onTap: () => _openPestDetails(item),
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(item.confidence, style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                                  const Text("Match", style: TextStyle(fontSize: 10)),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}