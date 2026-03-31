import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import 'login_screen.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  final String _serverUrl = "https://wingtrace.onrender.com";
  final ImagePicker _imagePicker = ImagePicker();

  final TextEditingController _adminKeyController = TextEditingController();

  // Device controls
  final TextEditingController _deviceIdController = TextEditingController();
  final TextEditingController _deviceNameController = TextEditingController();
  final TextEditingController _deviceFirmwareController = TextEditingController();

  final TextEditingController _statusDeviceIdController = TextEditingController();
  Map<String, dynamic>? _statusPayload;
  List<dynamic> _devices = [];

  // Category controls
  String _categoryType = "mosquito";
  final Map<String, TextEditingController> _categoryFields = {};
  final List<XFile> _categoryImages = [];

  bool _isLoadingDevices = false;
  bool _isSubmittingDevice = false;
  bool _isSubmittingCategory = false;
  bool _isFetchingStatus = false;

  @override
  void initState() {
    super.initState();
    _buildCategoryControllers();
    _categoryFields["category"]?.text = _categoryType;
  }

  @override
  void dispose() {
    _adminKeyController.dispose();
    _deviceIdController.dispose();
    _deviceNameController.dispose();
    _deviceFirmwareController.dispose();
    _statusDeviceIdController.dispose();
    for (final controller in _categoryFields.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _buildCategoryControllers() {
    for (final controller in _categoryFields.values) {
      controller.dispose();
    }
    _categoryFields.clear();
    final fields = _categoryType == "mosquito" ? _mosquitoFields : _pestFields;
    for (final field in fields) {
      _categoryFields[field] = TextEditingController();
    }
  }

  List<String> get _mosquitoFields => [
        "name",
        "category",
        "default_risk",
        "diseases",
        "bite_time",
        "common_name",
        "scientific_name",
        "breeding_sites",
        "subspecies",
        "risk_radius",
        "public_actions",
        "control_methods",
      ];

  List<String> get _pestFields => [
        "name",
        "category",
        "default_risk",
        "crops_affected",
        "active_period",
        "habitat",
        "damage_symptoms",
        "subspecies",
        "common_name",
        "scientific_name",
        "public_actions",
        "control_methods",
      ];

  String get _adminKey => _adminKeyController.text.trim();

  Map<String, String> _adminHeaders() {
    return {
      "Content-Type": "application/json",
      if (_adminKey.isNotEmpty) "X-ADMIN-KEY": _adminKey,
    };
  }

  void _showSnack(String message, {Color? color}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color),
    );
  }

  Future<void> _loadDevices() async {
    setState(() => _isLoadingDevices = true);
    try {
      final resp = await http.get(Uri.parse("$_serverUrl/devices"), headers: _adminHeaders());
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        setState(() {
          if (data is List) {
            _devices = data;
          } else if (data is Map && data.containsKey("devices")) {
            _devices = data["devices"] is List ? data["devices"] : [];
          } else if (data is Map) {
            _devices = data.keys.toList();
          } else {
            _devices = [];
          }
        });
      } else {
        _showSnack("Failed to load devices", color: Colors.red);
      }
    } catch (e) {
      _showSnack("Server unreachable", color: Colors.red);
    }
    setState(() => _isLoadingDevices = false);
  }

  Future<void> _fetchStatus() async {
    if (_statusDeviceIdController.text.trim().isEmpty) {
      _showSnack("Enter a device ID", color: Colors.orange);
      return;
    }

    setState(() {
      _isFetchingStatus = true;
      _statusPayload = null;
    });

    try {
      final resp = await http.post(
        Uri.parse("$_serverUrl/status"),
        headers: _adminHeaders(),
        body: jsonEncode({"deviceId": _statusDeviceIdController.text.trim()}),
      );
      if (resp.statusCode == 200) {
        setState(() => _statusPayload = jsonDecode(resp.body) as Map<String, dynamic>);
      } else {
        _showSnack("Status not found", color: Colors.red);
      }
    } catch (e) {
      _showSnack("Server unreachable", color: Colors.red);
    }

    setState(() => _isFetchingStatus = false);
  }

  Future<void> _addDevice() async {
    if (_deviceIdController.text.trim().isEmpty ||
        _deviceNameController.text.trim().isEmpty ||
        _deviceFirmwareController.text.trim().isEmpty) {
      _showSnack("Fill all device fields", color: Colors.orange);
      return;
    }

    setState(() => _isSubmittingDevice = true);

    try {
      final resp = await http.post(
        Uri.parse("$_serverUrl/addDevice"),
        headers: _adminHeaders(),
        body: jsonEncode({
          "deviceId": _deviceIdController.text.trim(),
          "deviceName": _deviceNameController.text.trim(),
          "firmwareVersion": _deviceFirmwareController.text.trim(),
          "createdAt": DateTime.now().toIso8601String(),
        }),
      );

      if (resp.statusCode == 201) {
        _showSnack("Device added", color: Colors.green);
        _deviceIdController.clear();
        _deviceNameController.clear();
        _deviceFirmwareController.clear();
        await _loadDevices();
      } else {
        final error = jsonDecode(resp.body);
        _showSnack(error["error"]?.toString() ?? "Add device failed", color: Colors.red);
      }
    } catch (e) {
      _showSnack("Server unreachable", color: Colors.red);
    }

    setState(() => _isSubmittingDevice = false);
  }

  Future<void> _pickCategoryImages() async {
    final images = await _imagePicker.pickMultiImage();
    if (images.isEmpty) return;
    setState(() => _categoryImages.addAll(images));
  }

  Future<void> _submitCategory({required bool isUpdate}) async {
    final nameController = _categoryFields["name"];
    if (nameController == null || nameController.text.trim().isEmpty) {
      _showSnack("Name is required", color: Colors.orange);
      return;
    }

    setState(() => _isSubmittingCategory = true);

    try {
      final endpoint = isUpdate ? "updateCategory" : "insertCategory";
      final request = http.MultipartRequest("POST", Uri.parse("$_serverUrl/$endpoint"));

      request.headers.addAll({
        if (_adminKey.isNotEmpty) "X-ADMIN-KEY": _adminKey,
      });

      for (final entry in _categoryFields.entries) {
        final value = entry.value.text.trim();
        if (value.isEmpty) continue;
        request.fields[entry.key] = value;
      }

      request.fields.putIfAbsent("category", () => _categoryType);

      for (final image in _categoryImages) {
        final bytes = await image.readAsBytes();
        request.files.add(http.MultipartFile.fromBytes(
          "images",
          bytes,
          filename: image.name,
        ));
      }

      final response = await request.send();
      final responseBody = await response.stream.bytesToString();

      if (response.statusCode == 200 || response.statusCode == 201) {
        _showSnack(isUpdate ? "Category updated" : "Category inserted", color: Colors.green);
        _categoryImages.clear();
        for (final controller in _categoryFields.values) {
          controller.clear();
        }
      } else {
        final error = jsonDecode(responseBody);
        _showSnack(error["error"]?.toString() ?? "Category request failed", color: Colors.red);
      }
    } catch (e) {
      _showSnack("Server unreachable", color: Colors.red);
    }

    setState(() => _isSubmittingCategory = false);
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFFFDFBE7),
        appBar: AppBar(
          title: const Text("Admin Control Center"),
          actions: [
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () => Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const LoginPage()),
              ),
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: "Devices"),
              Tab(text: "Categories"),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildDevicesTab(),
            _buildCategoriesTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildDevicesTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle("Admin Access"),
          _adminKeyCard(),
          const SizedBox(height: 20),
          _sectionTitle("Device Registry"),
          _addDeviceCard(),
          const SizedBox(height: 20),
          _sectionTitle("Devices"),
          _devicesCard(),
          const SizedBox(height: 20),
          _sectionTitle("Device Status"),
          _statusCard(),
        ],
      ),
    );
  }

  Widget _buildCategoriesTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle("Admin Access"),
          _adminKeyCard(),
          const SizedBox(height: 20),
          _sectionTitle("Species Catalog"),
          _categoryTypeSelector(),
          const SizedBox(height: 10),
          _categoryForm(),
        ],
      ),
    );
  }

  Widget _adminKeyCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Admin Key", style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            TextField(
              controller: _adminKeyController,
              obscureText: true,
              decoration: const InputDecoration(
                hintText: "Enter X-ADMIN-KEY",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              "Stored locally for this session only.",
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _addDeviceCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Add New Device", style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            TextField(
              controller: _deviceIdController,
              decoration: const InputDecoration(
                labelText: "Device ID",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _deviceNameController,
              decoration: const InputDecoration(
                labelText: "Device Name",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _deviceFirmwareController,
              decoration: const InputDecoration(
                labelText: "Firmware Version",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSubmittingDevice ? null : _addDevice,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green[700]),
                child: _isSubmittingDevice
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Text("Add Device", style: TextStyle(color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _devicesCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text("Registered Devices", style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                TextButton.icon(
                  onPressed: _isLoadingDevices ? null : _loadDevices,
                  icon: _isLoadingDevices
                      ? const SizedBox(
                          height: 14,
                          width: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh, size: 18),
                  label: const Text("Refresh"),
                ),
              ],
            ),
            if (_devices.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text("No devices loaded", style: TextStyle(color: Colors.grey)),
              )
            else
              Column(
                children: _devices
                    .map(
                      (device) => ListTile(
                        leading: const Icon(Icons.developer_board, color: Colors.green),
                        title: Text(device.toString()),
                        onTap: () {
                          _statusDeviceIdController.text = device.toString();
                        },
                      ),
                    )
                    .toList(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _statusCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Check Device Status", style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            TextField(
              controller: _statusDeviceIdController,
              decoration: const InputDecoration(
                labelText: "Device ID",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isFetchingStatus ? null : _fetchStatus,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green[700]),
                child: _isFetchingStatus
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Text("Fetch Status", style: TextStyle(color: Colors.white)),
              ),
            ),
            if (_statusPayload != null) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.withOpacity(0.4)),
                ),
                child: Text(const JsonEncoder.withIndent("  ").convert(_statusPayload)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _categoryTypeSelector() {
    return Row(
      children: [
        Expanded(
          child: DropdownButtonFormField<String>(
            value: _categoryType,
            items: const [
              DropdownMenuItem(value: "mosquito", child: Text("Mosquito")),
              DropdownMenuItem(value: "pest", child: Text("Pest")),
            ],
            onChanged: (value) {
              if (value == null) return;
              setState(() {
                _categoryType = value;
                _buildCategoryControllers();
                _categoryFields["category"]?.text = value;
              });
            },
            decoration: const InputDecoration(
              labelText: "Category",
              border: OutlineInputBorder(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _categoryForm() {
    final fields = _categoryType == "mosquito" ? _mosquitoFields : _pestFields;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Insert or Update Category", style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text(
              "List fields accept JSON arrays (e.g. [\"item\", \"item2\"]).",
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(height: 12),
            ...fields.map((field) => _buildCategoryField(field)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: _categoryImages
                  .map(
                    (image) => Chip(
                      label: Text(image.name),
                      onDeleted: () => setState(() => _categoryImages.remove(image)),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: _pickCategoryImages,
                  icon: const Icon(Icons.photo_library),
                  label: const Text("Add Images"),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green[200], foregroundColor: Colors.black),
                ),
                const Spacer(),
                ElevatedButton(
                  onPressed: _isSubmittingCategory ? null : () => _submitCategory(isUpdate: false),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green[700]),
                  child: _isSubmittingCategory
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Text("Insert", style: TextStyle(color: Colors.white)),
                ),
                const SizedBox(width: 10),
                OutlinedButton(
                  onPressed: _isSubmittingCategory ? null : () => _submitCategory(isUpdate: true),
                  child: const Text("Update"),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryField(String field) {
    final isJsonField = {
      "diseases",
      "bite_time",
      "breeding_sites",
      "subspecies",
      "public_actions",
      "control_methods",
      "crops_affected",
      "active_period",
      "habitat",
      "damage_symptoms",
    }.contains(field);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: _categoryFields[field],
        maxLines: isJsonField ? 3 : 1,
        decoration: InputDecoration(
          labelText: field.replaceAll("_", " "),
          hintText: isJsonField ? "JSON array" : null,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold));
  }
}
