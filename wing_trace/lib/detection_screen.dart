// import 'package:flutter/material.dart';

// class DetectionScreen extends StatefulWidget {
//   const DetectionScreen({super.key});

//   @override
//   State<DetectionScreen> createState() => _DetectionScreenState();
// }

// class _DetectionScreenState extends State<DetectionScreen> {
//   bool _isScanning = false;

//   void _toggleScan() {
//     setState(() {
//       _isScanning = !_isScanning;
//     });
    
//     // Simulate finding a pest after 2 seconds
//     if (_isScanning) {
//       Future.delayed(const Duration(seconds: 2), () {
//         if (mounted) {
//           _showResultDialog();
//         }
//       });
//     }
//   }

//   void _showResultDialog() {
//     showDialog(
//       context: context,
//       builder: (context) => AlertDialog(
//         title: const Text("Pest Identified!"),
//         content: const Text("Type: Aedes Aegypti\nConfidence: 98%"),
//         actions: [
//           TextButton(onPressed: () => Navigator.pop(context), child: const Text("OK")),
//         ],
//       ),
//     );
//     setState(() => _isScanning = false);
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: const Text("Live Detection"), backgroundColor: Colors.green),
//       body: Column(
//         children: [
//           Expanded(
//             child: Container(
//               margin: const EdgeInsets.all(20),
//               decoration: BoxDecoration(
//                 color: Colors.black12,
//                 borderRadius: BorderRadius.circular(20),
//                 border: Border.all(color: Colors.green, width: 2),
//               ),
//               child: Stack(
//                 alignment: Alignment.center,
//                 children: [
//                   const Icon(Icons.camera_alt, size: 100, color: Colors.grey),
//                   if (_isScanning) 
//                     const CircularProgressIndicator(color: Colors.green),
//                 ],
//               ),
//             ),
//           ),
//           Padding(
//             padding: const EdgeInsets.only(bottom: 50),
//             child: ElevatedButton.icon(
//               onPressed: _toggleScan,
//               icon: Icon(_isScanning ? Icons.stop : Icons.play_arrow),
//               label: Text(_isScanning ? "Stop Scan" : "Start Identification"),
//               style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
//             ),
//           )
//         ],
//       ),
//     );
//   }
// }
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class DetectionScreen extends StatefulWidget {
  const DetectionScreen({super.key});

  @override
  State<DetectionScreen> createState() => _DetectionScreenState();
}

class _DetectionScreenState extends State<DetectionScreen> {
  File? _selectedImage; // This stores the captured/uploaded image
  final ImagePicker _picker = ImagePicker();

  // Function to pick image from source
  Future<void> _pickImage(ImageSource source) async {
    final XFile? pickedFile = await _picker.pickImage(source: source);

    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
      });
      _simulateIdentification();
    }
  }

  void _simulateIdentification() {
    // Show a loading snackbar while "processing"
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Identifying pest..."), duration: Duration(seconds: 2)),
    );
  }

  void _showPickerOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Colors.green),
              title: const Text('Take a Photo'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Colors.green),
              title: const Text('Upload from Gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDFBE7),
      appBar: AppBar(title: const Text("Pest Detection"), backgroundColor: Colors.green),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.green, width: 2),
              ),
              child: _selectedImage != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: Image.file(_selectedImage!, fit: BoxFit.cover),
                    )
                  : const Icon(Icons.image_search, size: 80, color: Colors.grey),
            ),
            const SizedBox(height: 30),
            ElevatedButton.icon(
              onPressed: _showPickerOptions,
              icon: const Icon(Icons.add_a_photo, color: Colors.white),
              label: const Text("Start Identification", style: TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
              ),
            ),
          ],
        ),
      ),
    );
  }
}