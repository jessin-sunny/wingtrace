import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'dart:convert';
import 'dart:async';
import 'pest_details_screen.dart';

class AudioDetectionScreen extends StatefulWidget {
  const AudioDetectionScreen({super.key});

  @override
  State<AudioDetectionScreen> createState() => _AudioDetectionScreenState();
}

class _AudioDetectionScreenState extends State<AudioDetectionScreen> with SingleTickerProviderStateMixin {
  String _statusText = "Initializing...";
  bool _isLoading = false;
  bool _isWaitingForDetection = false;
  String? _deviceId;
  late AnimationController _pulseController;
  final String _serverUrl = "https://wingtrace.onrender.com";

  StreamSubscription<DatabaseEvent>? _detectionListener;

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
    _detectionListener?.cancel();
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

      if (response.statusCode == 200) {
        // If stopping audio, start listening for detections from Firebase
        if (!start) {
          _startListeningForDetections();
        } else {
          // If starting audio, cancel any existing detection listener
          _detectionListener?.cancel();
          _detectionListener = null;
          setState(() => _isWaitingForDetection = false);
        }
      } else {
        final error = jsonDecode(response.body)['error'] ?? "Command failed";
        _showSnackBar(error);
      }
    } catch (e) {
      _showSnackBar("Connection error: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // 3. Listen for new detections from Firebase after audio stops
  void _startListeningForDetections() {
    if (_deviceId == null) return;

    setState(() {
      _isWaitingForDetection = true;
      _statusText = "Waiting for server analysis...";
    });

    final detectionsRef = FirebaseDatabase.instance.ref("devices/$_deviceId/detections");

    // Listen for the latest detection
    _detectionListener = detectionsRef.orderByKey().limitToLast(1).onValue.listen((event) {
      if (event.snapshot.value != null && _isWaitingForDetection) {
        // Get the last detection from the snapshot
        if (event.snapshot.children.isNotEmpty) {
          final lastDetection = event.snapshot.children.first;
          debugPrint('Detection received: ${lastDetection.value}');
          _processAudioDetection(lastDetection.value);
        }
      }
    });

    // Set timeout - if no detection in 60 seconds, stop waiting
    Future.delayed(const Duration(seconds: 60), () {
      if (_isWaitingForDetection && mounted) {
        setState(() {
          _isWaitingForDetection = false;
          _statusText = "No detection received. Try again.";
        });
        _detectionListener?.cancel();
        _detectionListener = null;
      }
    });
  }

  // 4. Process the detection through HuggingFace model
  Future<void> _processAudioDetection(dynamic detectionData) async {
    _detectionListener?.cancel();
    _detectionListener = null;

    setState(() {
      _statusText = "Processing detection...";
      _isWaitingForDetection = false;
    });

    try {
      debugPrint('Detection data: $detectionData');

      // Extract species from Firebase detection
      String? species;
      double? confidence;

      if (detectionData is Map) {
        species = detectionData['species']?.toString();
        confidence = detectionData['confidence'] as double?;
        debugPrint('Extracted species: $species, confidence: $confidence');
      }

      if (species == null || species.isEmpty) {
        _showSnackBar("No species found in detection");
        setState(() => _statusText = "Ready to analyze frequencies");
        return;
      }

      // Parse species to extract category
      // Species format: "Anopheles (Malaria Vector)" -> category: "anopheles"
      final category = _extractCategoryFromSpecies(species);

      if (category != null) {
        // Fetch pest info from server
        final pestInfo = await _fetchPestInfo(category);

        // Save to Firestore
        await _saveDetectionToFirestore(species, category, confidence);

        // Navigate to details screen
        if (mounted) {
          final (pestType, pestCategory) = _parseSpecies(species);
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PestDetailsScreen(
                imageFile: null, // No image for audio detection
                pestType: pestType,
                pestCategory: pestCategory,
                pestInfo: pestInfo,
              ),
            ),
          );

          setState(() => _statusText = "Ready to analyze frequencies");
        }
      } else {
        _showSnackBar("Could not identify pest category");
        setState(() => _statusText = "Ready to analyze frequencies");
      }
    } catch (e) {
      debugPrint('Audio detection error: $e');
      _showSnackBar("Analysis failed: $e");
      setState(() => _statusText = "Ready to analyze frequencies");
    }
  }

  // Extract category from species name to match Firestore Document IDs
  // "Anopheles (Malaria Vector)" -> "anopheles"
  // "Aphidoletes Aphidimyza" -> "aphidoletes_aphidimyza"
  String? _extractCategoryFromSpecies(String species) {
    // 1. Remove anything in parentheses and trim the edges
    final cleaned = species.replaceAll(RegExp(r'\s*\([^)]*\)'), '').trim().toLowerCase();

    if (cleaned.isEmpty) return null;

    // 2. Replace spaces with underscores so it matches Firebase exactly
    return cleaned.replaceAll(' ', '_');
  }

  // Parse species into type and category
  // "Anopheles (Malaria Vector)" -> ("Malaria Vector", "Anopheles")
  (String, String) _parseSpecies(String species) {
    final match = RegExp(r'^([^(]+)\s*\(([^)]+)\)').firstMatch(species);

    if (match != null) {
      final category = match.group(1)?.trim() ?? species;
      final type = match.group(2)?.trim() ?? '';
      return (type, category);
    }

    // No parentheses, use species as both
    return ('Pest', species.trim());
  }

  // 5. Fetch pest information from Firestore
  Future<Map<String, dynamic>?> _fetchPestInfo(String category) async {
    try {
      debugPrint('Fetching pest info for category: $category');

      final docSnapshot = await FirebaseFirestore.instance
          .collection('categories')
          .doc(category.toLowerCase())
          .get()
          .timeout(const Duration(seconds: 20));

      if (docSnapshot.exists) {
        final data = docSnapshot.data();
        debugPrint('Pest info fetched: ${data?.keys.join(', ')}');
        return data;
      } else {
        debugPrint('No document found for category: $category');
      }
    } catch (e) {
      debugPrint('Pest info fetch error: $e');
    }
    return null;
  }

  // 6. Save detection to Firestore
  Future<void> _saveDetectionToFirestore(String species, String category, double? confidence) async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('detections')
          .add({
        'pest_name': species,
        'category': category,
        'confidence': confidence,
        'source': 'audio_detection',
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Firestore save error: $e');
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
                    _isWaitingForDetection
                        ? "Processing audio analysis...\nWaiting for server results..."
                        : (isRecording
                            ? "Listening for wingbeat frequencies..."
                            : _statusText),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 16, color: Colors.black54),
                  ),
                ),
                const SizedBox(height: 60),

                _isLoading || _isWaitingForDetection
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