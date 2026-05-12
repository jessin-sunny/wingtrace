import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'pest_details_screen.dart';

class DetectionScreen extends StatefulWidget {
  const DetectionScreen({super.key});

  @override
  State<DetectionScreen> createState() => _DetectionScreenState();
}

class _DetectionScreenState extends State<DetectionScreen> {
  File? _selectedImage;
  final ImagePicker _picker = ImagePicker();

  bool _isAnalyzing = false;
  String? _rawResult;               // e.g. "Mosquito -> Aedes"
  Map<String, dynamic>? _pestInfo;  // JSON from category server
  String? _errorMessage;
  double? _confidenceScore;
  String? _detectedPestType;
  String? _detectedPestCategory;
  String? _communityId;
  bool _isSharing = false;
  String? _shareStatus;

  static const String _gradioBase = 'https://wingtrace-wingmodel2.hf.space';

  /// Resolved at runtime via the HuggingFace API so we always hit the right URL.
  String? _resolvedBase;

  // ── Image Picker ──────────────────────────────────────────────────────────

  Future<void> _pickImage(ImageSource source) async {
    final XFile? picked = await _picker.pickImage(
      source: source,
      imageQuality: 80,
      maxWidth: 1024,
      maxHeight: 1024,
    );
    if (picked != null) {
      setState(() {
        _selectedImage = File(picked.path);
        _rawResult = null;
        _pestInfo = null;
        _errorMessage = null;
        _shareStatus = null;
      });
      await _identifyPest();
    }
  }

  void _showPickerOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Colors.green),
              title: const Text('Take a Photo'),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Colors.green),
              title: const Text('Upload from Gallery'),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  // ── AI Identification Flow ────────────────────────────────────────────────

  Future<void> _identifyPest() async {
    if (_selectedImage == null) return;
    setState(() {
      _isAnalyzing = true;
      _rawResult = null;
      _pestInfo = null;
      _errorMessage = null;
    });

    try {
      // Encode image as base64 data URL
      final bytes = await _selectedImage!.readAsBytes();
      final base64Str = base64Encode(bytes);
      final ext = _selectedImage!.path.split('.').last.toLowerCase();
      final mime = (ext == 'png') ? 'image/png' : 'image/jpeg';
      final base64DataUrl = 'data:$mime;base64,$base64Str';

      final result = await _callGradioModel(base64DataUrl);
      setState(() {
        _rawResult = result;
        _confidenceScore = _extractConfidenceScore(result);
        final (pestType, pestCategory) = _splitResult(result);
        _detectedPestType = pestType;
        _detectedPestCategory = pestCategory;
      });

      final String? category = _extractCategory(result);

      if (category != null) {
        // Fetch pest info
        await _fetchPestInfo(category);

        if (_confidenceScore == null && _pestInfo != null) {
          _confidenceScore = _extractConfidenceFromInfo(_pestInfo!);
        }

        // Save to Firestore
        await _saveDetectionToFirestore(result, category);

        // Auto-share to community (status decides verified vs pending)
        await _autoShareToCommunity();

        // Navigate to details screen
        if (mounted) {
          final (pestType, pestCategory) = _splitResult(result);
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PestDetailsScreen(
                imageFile: _selectedImage!,
                pestType: pestType,
                pestCategory: pestCategory,
                pestInfo: _pestInfo,
                source: 'image',
              ),
            ),
          );

          // Reset image only; keep result for optional share review
          if (mounted) {
            setState(() {
              _selectedImage = null;
              _pestInfo = null;
            });
          }
        }
      } else {
        // No pest detected - just show the no result card on current screen
        setState(() {});
      }
    } catch (e) {
      setState(() => _errorMessage = 'Analysis failed. Please try again.');
      debugPrint('Detection Error: $e');
    } finally {
      if (mounted) setState(() => _isAnalyzing = false);
    }
  }

  /// Fetches the actual Gradio base URL from the HuggingFace API.
  /// The Python `gradio_client` does this automatically; we mirror it here.
  /// Result is cached so it only runs once per screen instance.
  Future<String> _initGradioBase() async {
    if (_resolvedBase != null) return _resolvedBase!;

    try {
      final resp = await http.get(
        Uri.parse('https://huggingface.co/api/spaces/wingtrace/wingmodel2'),
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 15));

      debugPrint('HF API status: ${resp.statusCode}');

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;

        // 'host' → "wingtrace-wingmodel.hf.space"
        final host = data['host']?.toString();
        if (host != null && host.isNotEmpty) {
          _resolvedBase = host.startsWith('http') ? host : 'https://$host';
          debugPrint('Gradio base (host): $_resolvedBase');
          return _resolvedBase!;
        }

        // 'subdomain' → "wingtrace-wingmodel"
        final sub = data['subdomain']?.toString();
        if (sub != null && sub.isNotEmpty) {
          _resolvedBase = 'https://$sub.hf.space';
          debugPrint('Gradio base (subdomain): $_resolvedBase');
          return _resolvedBase!;
        }

        debugPrint('HF API body (first 400): ${resp.body.substring(0, min(400, resp.body.length))}');
      }
    } catch (e) {
      debugPrint('HF URL resolution failed: $e');
    }

    _resolvedBase = _gradioBase; // fall back to hardcoded value
    debugPrint('Gradio base (fallback): $_resolvedBase');
    return _resolvedBase!;
  }

  /// Calls the Gradio model using the correct API prefix and endpoint from /config.
  // Future<String> _callGradioModel(String base64DataUrl) async {
  //   final base = await _initGradioBase();

  //   // ── Get API structure from /config ──
  //   String apiPrefix = '/api';
  //   List<String> endpointNames = [];

  //   try {
  //     final configResp = await http.get(
  //       Uri.parse('$base/config'),
  //       headers: {'Accept': 'application/json'},
  //     ).timeout(const Duration(seconds: 10));

  //     if (configResp.statusCode == 200) {
  //       final config = jsonDecode(configResp.body) as Map<String, dynamic>;
  //       apiPrefix = config['api_prefix']?.toString() ?? '/api';

  //       // Extract endpoint names from dependencies
  //       final dependencies = config['dependencies'] as List?;
  //       if (dependencies != null) {
  //         for (var dep in dependencies) {
  //           if (dep is Map) {
  //             final apiName = dep['api_name']?.toString();
  //             if (apiName != null && apiName.isNotEmpty && apiName != 'null') {
  //               endpointNames.add(apiName);
  //             }
  //           }
  //         }
  //       }

  //       debugPrint('API prefix: $apiPrefix');
  //       debugPrint('Available endpoints: $endpointNames');
  //     }
  //   } catch (e) {
  //     debugPrint('/config error: $e');
  //   }

  //   // Try each discovered endpoint name
  //   for (final endpointName in endpointNames) {
  //     try {
  //       final r = await http.post(
  //         Uri.parse('$base$apiPrefix/$endpointName'),
  //         headers: {'Content-Type': 'application/json'},
  //         body: jsonEncode({'data': [base64DataUrl]}),
  //       ).timeout(const Duration(seconds: 90));

  //       debugPrint('$apiPrefix/$endpointName ${r.statusCode}: ${r.body.substring(0, min(300, r.body.length))}');

  //       if (r.statusCode == 200) {
  //         final respData = jsonDecode(r.body);

  //         // Handle direct response: {"data": [...]}
  //         if (respData is Map && respData.containsKey('data')) {
  //           final dl = respData['data'] as List?;
  //           if (dl != null && dl.isNotEmpty) {
  //             return dl[0].toString().trim();
  //           }
  //         }

  //         // Handle streaming response: {"event_id": "..."}
  //         if (respData is Map && respData.containsKey('event_id')) {
  //           final eventId = respData['event_id'] as String;
  //           return await _streamGradioResult(
  //             Uri.parse('$base$apiPrefix/$endpointName/$eventId')
  //           );
  //         }
  //       }
  //     } catch (e) {
  //       debugPrint('$apiPrefix/$endpointName error: $e');
  //     }
  //   }

  //   // Fallback: try predict_bug and predict with fn_index=0
  //   final fallbackNames = ['predict_bug', 'predict'];
  //   for (final name in fallbackNames) {
  //     try {
  //       final r = await http.post(
  //         Uri.parse('$base$apiPrefix/$name'),
  //         headers: {'Content-Type': 'application/json'},
  //         body: jsonEncode({'data': [base64DataUrl], 'fn_index': 0}),
  //       ).timeout(const Duration(seconds: 90));

  //       debugPrint('Fallback $apiPrefix/$name ${r.statusCode}');

  //       if (r.statusCode == 200) {
  //         final respData = jsonDecode(r.body);
  //         if (respData is Map && respData.containsKey('data')) {
  //           final dl = respData['data'] as List?;
  //           if (dl != null && dl.isNotEmpty) {
  //             return dl[0].toString().trim();
  //           }
  //         }
  //       }
  //     } catch (e) {
  //       debugPrint('Fallback $apiPrefix/$name error: $e');
  //     }
  //   }

  //   throw Exception('Failed to get prediction from Gradio API');
  // }
  Future<String> _callGradioModel(String base64DataUrl) async {
    const base = "https://wingtrace-wingmodel2.hf.space";

    // STEP 1: Upload the file to get a file reference
    // Convert base64 data URL back to bytes
    final base64Data = base64DataUrl.split(',')[1];
    final bytes = base64Decode(base64Data);

    // Determine mime type from data URL
    final mimeMatch = RegExp(r'data:([^;]+);').firstMatch(base64DataUrl);
    final mimeType = mimeMatch?.group(1) ?? 'image/jpeg';
    final extension = mimeType.split('/').last;

    debugPrint('Uploading file: $mimeType, ${bytes.length} bytes');

    // Create multipart request for upload
    final uploadRequest = http.MultipartRequest(
      'POST',
      Uri.parse('$base/gradio_api/upload'),
    );

    uploadRequest.files.add(
      http.MultipartFile.fromBytes(
        'files',
        bytes,
        filename: 'image.$extension',
      ),
    );

    final uploadStreamedResponse = await uploadRequest.send().timeout(const Duration(seconds: 60));
    final uploadResponse = await http.Response.fromStream(uploadStreamedResponse);

    debugPrint('Upload response: ${uploadResponse.statusCode}, body: ${uploadResponse.body}');

    if (uploadResponse.statusCode != 200) {
      throw Exception('File upload failed: ${uploadResponse.statusCode}');
    }

    // Parse upload response to get file reference
    final uploadData = jsonDecode(uploadResponse.body);

    debugPrint('Upload data type: ${uploadData.runtimeType}');

    String? filePath;
    dynamic fileObject;

    // Handle different response formats
    if (uploadData is List && uploadData.isNotEmpty) {
      filePath = uploadData[0].toString();

      // Construct full file object for Gradio 6.x
      fileObject = {
        "path": filePath,
        "url": "$base/gradio_api/file=$filePath",
        "size": bytes.length,
        "orig_name": "image.$extension",
        "mime_type": mimeType,
      };
    } else if (uploadData is Map && uploadData['files'] != null) {
      final files = uploadData['files'] as List;
      if (files.isNotEmpty) {
        filePath = files[0].toString();
        fileObject = {
          "path": filePath,
          "url": "$base/gradio_api/file=$filePath",
          "size": bytes.length,
          "orig_name": "image.$extension",
          "mime_type": mimeType,
        };
      }
    }

    if (filePath == null) {
      throw Exception('No file reference returned from upload');
    }

    debugPrint('File path: $filePath');

    // STEP 2: Send prediction request - try both formats
    // Try with full file object first (Gradio 6.x style)
    var response = await http.post(
      Uri.parse("$base/gradio_api/call/predict_bug"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"data": [fileObject]}),
    ).timeout(const Duration(seconds: 60));

    debugPrint('POST call/predict_bug (with file object): ${response.statusCode}, body: ${response.body.substring(0, min(200, response.body.length))}');

    // If that fails, try with just the path string
    if (response.statusCode != 200 || jsonDecode(response.body)['event_id'] == null) {
      debugPrint('Retrying with just file path...');
      response = await http.post(
        Uri.parse("$base/gradio_api/call/predict_bug"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"data": [filePath]}),
      ).timeout(const Duration(seconds: 60));

      debugPrint('POST call/predict_bug (with path): ${response.statusCode}');
    }

    debugPrint('POST call/predict_bug: ${response.statusCode}');

    if (response.statusCode != 200) {
      throw Exception("Prediction request failed");
    }

    final body = jsonDecode(response.body);
    final eventId = body["event_id"];

    debugPrint('Event ID: $eventId');

    if (eventId == null) {
      throw Exception("No event_id returned from server");
    }

    // STEP 3: read result stream using proper streaming
    final client = http.Client();
    final request = http.Request('GET', Uri.parse("$base/gradio_api/call/predict_bug/$eventId"));
    request.headers['Accept'] = 'text/event-stream';

    final streamedResponse = await client.send(request).timeout(const Duration(seconds: 90));

    debugPrint('Stream response: ${streamedResponse.statusCode}');

    final completer = Completer<String>();
    String buffer = '';

    streamedResponse.stream.transform(const Utf8Decoder()).listen(
      (chunk) {
        debugPrint('Raw chunk: ${chunk.substring(0, min(300, chunk.length))}');

        buffer += chunk;
        final lines = buffer.split('\n');
        buffer = lines.removeLast(); // keep incomplete line

        for (final line in lines) {
          debugPrint('Line: ${line.length > 100 ? line.substring(0, 100) + "..." : line}');

          if (line.startsWith('data: ')) {
            final payload = line.substring(6).trim();

            if (payload.isEmpty || payload == 'null') continue;

            debugPrint('SSE payload: ${payload.substring(0, min(200, payload.length))}');

            try {
              final decoded = jsonDecode(payload);

              // Try multiple formats
              String? result;

              // Format 1: {output: {data: [...]}}
              if (decoded is Map && decoded['output'] is Map) {
                final output = decoded['output'] as Map;
                if (output['data'] is List && (output['data'] as List).isNotEmpty) {
                  result = output['data'][0]?.toString();
                }
              }

              // Format 2: Direct array ["result"]
              if (result == null && decoded is List && decoded.isNotEmpty) {
                result = decoded[0]?.toString();
              }

              // Format 3: {data: [...]}
              if (result == null && decoded is Map && decoded['data'] is List) {
                final dataList = decoded['data'] as List;
                if (dataList.isNotEmpty) {
                  result = dataList[0]?.toString();
                }
              }

              if (result != null && result.isNotEmpty && !completer.isCompleted) {
                debugPrint('Found result: $result');
                completer.complete(result);
              }
            } catch (e) {
              debugPrint('Parse error: $e');
            }
          }
        }
      },
      onDone: () {
        if (!completer.isCompleted) {
          completer.completeError('Stream ended without result');
        }
        client.close();
      },
      onError: (e) {
        if (!completer.isCompleted) {
          completer.completeError(e);
        }
        client.close();
      },
    );

    return await completer.future;
  }

  /// Reads an SSE stream from [uri] and returns the first non-empty result.
  Future<String> _streamGradioResult(Uri uri) async {
    final client = http.Client();
    final completer = Completer<String>();
    String buffer = '';

    try {
      final request = http.Request('GET', uri);
      request.headers['Accept'] = 'text/event-stream';
      final streamed = await client
          .send(request)
          .timeout(const Duration(seconds: 60));

      StreamSubscription? sub;
      sub = streamed.stream
          .transform(const Utf8Decoder(allowMalformed: true))
          .listen(
        (chunk) {
          buffer += chunk;
          final lines = buffer.split('\n');
          buffer = lines.removeLast(); // hold incomplete line

          for (final line in lines) {
            if (!line.startsWith('data: ')) continue;
            final payload = line.substring(6).trim();
            if (payload.isEmpty || payload == 'null') continue;

            try {
              final data = jsonDecode(payload);
              String? result;

              // Gradio 4.x queue: {msg:"process_completed", output:{data:[...]}}
              if (data is Map && data['msg'] == 'process_completed') {
                final out = data['output'] as Map?;
                final dl = out?['data'] as List?;
                if (dl != null && dl.isNotEmpty) {
                  result = dl[0].toString().trim();
                }
              }
              // Gradio 5.x streamed array: ["result"]
              else if (data is List && data.isNotEmpty) {
                result = data[0].toString().trim();
              }
              // Gradio 5.x wrapped: {"data": ["result"]}
              else if (data is Map && data.containsKey('data')) {
                final dl = data['data'] as List?;
                if (dl != null && dl.isNotEmpty) {
                  result = dl[0].toString().trim();
                }
              }

              if (result != null && result.isNotEmpty && !completer.isCompleted) {
                completer.complete(result);
              }

              // Propagate server-side error messages
              if (data is Map) {
                final msg = data['msg']?.toString() ?? '';
                if ((msg == 'process_error' || msg == 'queue_full') &&
                    !completer.isCompleted) {
                  completer.completeError('Server error: $msg');
                }
              }
            } catch (_) {} // ignore individual malformed events
          }
        },
        onError: (e) {
          if (!completer.isCompleted) completer.completeError(e);
        },
        onDone: () {
          if (!completer.isCompleted) {
            completer.completeError('Stream ended without a result');
          }
        },
      );

      final result = await completer.future.timeout(const Duration(seconds: 90));
      await sub.cancel();
      return result;
    } finally {
      client.close();
    }
  }

  String _randomHash() {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final rng = Random();
    return List.generate(11, (_) => chars[rng.nextInt(chars.length)]).join();
  }

  /// Returns the category slug (e.g. "aedes") from "Mosquito -> Aedes",
  /// or null if the model could not identify a pest.
  String? _extractCategory(String result) {
    final cleaned = result
        .replaceFirst(RegExp(r'^Result:\s*', caseSensitive: false), '')
        .trim();

    debugPrint('Extracting category from: $cleaned');

    // Handle both "->" and "→" (Unicode arrow)
    if (!cleaned.contains('->') && !cleaned.contains('→')) {
      debugPrint('No arrow found, returning null');
      return null;
    }

    // Split by either "->" or "→"
    final parts = cleaned.contains('→')
        ? cleaned.split('→')
        : cleaned.split('->');

    final category = parts.last.trim().toLowerCase();

    debugPrint('Extracted category: $category');

    // Treat empty or generic labels as no-result
    const noResultLabels = {'unknown', 'none', 'no result', 'not detected', 'n/a', ''};
    if (noResultLabels.contains(category)) return null;

    return category;
  }

  Future<void> _fetchPestInfo(String category) async {
    try {
      

      final firestoreDocId = category.toLowerCase().replaceAll(' ', '_');
      debugPrint('Fetching pest info for category: $firestoreDocId');
      final docSnapshot = await FirebaseFirestore.instance
          .collection('categories')
          .doc(firestoreDocId)
          .get()
          .timeout(const Duration(seconds: 20));

      if (docSnapshot.exists) {
        final data = docSnapshot.data();
        debugPrint('Pest info fetched: ${data?.keys.join(', ')}');
        if (mounted) setState(() => _pestInfo = data);
      } else {
        debugPrint('No document found for category: $category');
      }
    } catch (e) {
      // Non-fatal – we still show the identification result
      debugPrint('Pest info fetch error: $e');
    }
  }

  Future<void> _saveDetectionToFirestore(String result, String category) async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('detections')
          .add({
        'pest_name': result,
        'category': category,
        'source': 'image_detection',
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Firestore save error: $e');
    }
  }

  void _showSnack(String message, {Color? color}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color),
    );
  }

  Future<String?> _loadCommunityId() async {
    if (_communityId != null) return _communityId;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;

    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (doc.exists) {
        final data = doc.data();
        _communityId = data?['communityID']?.toString() ?? data?['communityId']?.toString();
      }
    } catch (e) {
      debugPrint('Community ID fetch error: $e');
    }

    return _communityId;
  }

  double? _extractConfidenceScore(String raw) {
    final percentMatch = RegExp(r'(\d{1,3}(?:\.\d+)?)\s*%').firstMatch(raw);
    if (percentMatch != null) {
      final value = double.tryParse(percentMatch.group(1) ?? '');
      if (value != null) return (value / 100).clamp(0.0, 1.0);
    }

    final decimalMatch = RegExp(r'(?:(?:confidence|score)\s*[:=]?\s*)?([01]\.\d+)').firstMatch(raw.toLowerCase());
    if (decimalMatch != null) {
      final value = double.tryParse(decimalMatch.group(1) ?? '');
      if (value != null) return value.clamp(0.0, 1.0);
    }

    return null;
  }

  double? _extractConfidenceFromInfo(Map<String, dynamic> info) {
    final raw = info['confidence'] ?? info['confidenceScore'] ?? info['score'];
    if (raw is num) return raw.toDouble().clamp(0.0, 1.0);
    if (raw is String) {
      final value = double.tryParse(raw);
      if (value != null) return value.clamp(0.0, 1.0);
    }
    return null;
  }

  Future<void> _autoShareToCommunity() async {
    final communityId = await _loadCommunityId();
    if (communityId == null || communityId.isEmpty) {
      setState(() => _shareStatus = 'Skipped: no community linked');
      return;
    }
    await _shareToCommunity(communityId);
  }

  Future<void> _shareToCommunity(String communityId) async {
    if (_detectedPestCategory == null) return;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    setState(() => _isSharing = true);
    try {
      final status = (_confidenceScore != null && _confidenceScore! > 0.8)
          ? 'verified'
          : 'pending';
      setState(() => _shareStatus = 'Sharing to $communityId...');
      await FirebaseFirestore.instance
          .collection('communities')
          .doc(communityId)
          .collection('posts')
          .add({
        'authorID': uid,
        'confidence': _confidenceScore,
        'pestType': _detectedPestCategory,
        'status': status,
        'timestamp': FieldValue.serverTimestamp(),
      });

      setState(() => _shareStatus = 'Shared to $communityId ($status)');
      _showSnack('Shared to community', color: Colors.green);
    } catch (e) {
      debugPrint('Share error: $e');
      setState(() => _shareStatus = 'Share failed: $e');
      _showSnack('Failed to share', color: Colors.red);
    }

    setState(() => _isSharing = false);
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  /// Splits "Mosquito -> Aedes" into type = "Mosquito", category = "Aedes"
  (String, String) _splitResult(String raw) {
    final cleaned = raw.replaceFirst(RegExp(r'^Result:\s*', caseSensitive: false), '');

    // Handle both ASCII and Unicode arrows
    final parts = cleaned.contains('→')
        ? cleaned.split('→')
        : cleaned.split('->');

    if (parts.length >= 2) {
      return (parts[0].trim(), parts[1].trim());
    }
    return ('Unknown', cleaned.trim());
  }

  String _formatKey(String key) {
    return key
        .replaceAllMapped(RegExp(r'[_\-]'), (_) => ' ')
        .replaceAllMapped(RegExp(r'([A-Z])'), (m) => ' ${m.group(0)}')
        .trim()
        .split(' ')
        .where((w) => w.isNotEmpty)
        .map((w) => '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDFBE7),
      appBar: AppBar(
        title: const Text('Pest Detection'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
        child: Column(
          children: [
            _buildImageCard(),
            const SizedBox(height: 20),
            if (_isAnalyzing) _buildAnalyzingCard(),
            if (_errorMessage != null && !_isAnalyzing) _buildErrorCard(),
            if (_rawResult != null && !_isAnalyzing && _extractCategory(_rawResult!) == null)
              _buildNoResultCard(),
            if (_shareStatus != null && !_isAnalyzing) _buildShareStatusCard(),
            const SizedBox(height: 20),
            _buildActionButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildShareStatusCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.green.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.share, color: Colors.green),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _shareStatus ?? '',
              style: const TextStyle(color: Colors.black87, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageCard() {
    return Container(
      width: double.infinity,
      height: 280,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.green, width: 2),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 12)
        ],
      ),
      child: _selectedImage != null
          ? ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Image.file(_selectedImage!, fit: BoxFit.cover),
            )
          : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.image_search, size: 80, color: Colors.grey[400]),
                const SizedBox(height: 12),
                Text(
                  'Tap below to upload an insect image',
                  style: TextStyle(color: Colors.grey[500], fontSize: 14),
                ),
              ],
            ),
    );
  }

  Widget _buildAnalyzingCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.green.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 26,
            height: 26,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: Colors.green,
            ),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Analyzing image...',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                  fontSize: 15,
                ),
              ),
              Text(
                'Sending to WingTrace AI model',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildErrorCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.red),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _errorMessage!,
              style: const TextStyle(color: Colors.red, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoResultCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
      decoration: BoxDecoration(
        color: Colors.orange[50],
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Column(
        children: [
          Icon(Icons.search_off_rounded, color: Colors.orange[700], size: 48),
          const SizedBox(height: 12),
          Text(
            'No Pest Detected',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 17,
              color: Colors.orange[800],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'The model could not identify a pest in this image.\nTry a clearer, well-lit photo with the insect in focus.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Colors.orange[700], height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _isAnalyzing ? null : _showPickerOptions,
        icon: const Icon(Icons.add_a_photo_rounded, color: Colors.white),
        label: Text(
          _selectedImage == null
              ? 'Start Identification'
              : 'Analyse Another Image',
          style: const TextStyle(color: Colors.white, fontSize: 15),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green,
          disabledBackgroundColor: Colors.green.withOpacity(0.45),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          elevation: 2,
        ),
      ),
    );
  }
}
