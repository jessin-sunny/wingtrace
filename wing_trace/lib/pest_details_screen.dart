import 'dart:io';
import 'package:flutter/material.dart';
import 'pest_chatbot_screen.dart';

class PestDetailsScreen extends StatelessWidget {
  final File? imageFile; // Nullable for audio detection
  final String pestType;
  final String pestCategory;
  final Map<String, dynamic>? pestInfo;

  const PestDetailsScreen({
    super.key,
    this.imageFile, // Changed to optional
    required this.pestType,
    required this.pestCategory,
    this.pestInfo,
  });

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDFBE7),
      appBar: AppBar(
        title: const Text('Pest Identified'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Image Section (only show if image exists)
            if (imageFile != null)
              Container(
                height: 300,
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.1), blurRadius: 8)
                  ],
                ),
                child: Image.file(imageFile!, fit: BoxFit.cover),
              ),

            // Audio detection indicator (if no image)
            if (imageFile == null)
              Container(
                height: 200,
                margin: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.green.withOpacity(0.3)),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.graphic_eq_rounded,
                          size: 80, color: Colors.green[600]),
                      const SizedBox(height: 12),
                      Text(
                        'Detected via Audio Analysis',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.green[700],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Identification Badge
            Container(
              margin: const EdgeInsets.all(20),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.green[700]!, Colors.green[500]!],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.green.withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  )
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.check_circle_rounded,
                      color: Colors.white,
                      size: 40,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'IDENTIFIED AS',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          pestCategory.toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            height: 1.1,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          pestType,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Pest Information Section
            if (pestInfo != null) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Text(
                  'Pest Information',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.green[800],
                  ),
                ),
              ),
              _buildInfoCard(),
            ],

            // Action Buttons
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // Ask Tracy Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PestChatbotScreen(
                            initialMessage: 'Tell me about $pestCategory',
                          ),
                        ),
                      ),
                      icon: const Icon(Icons.smart_toy_outlined,
                          color: Colors.white),
                      label: const Text(
                        'Ask Tracy About This Pest',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 3,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Done Button
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon:
                          const Icon(Icons.arrow_back, color: Colors.green),
                      label: const Text(
                        'Analyze Another Image',
                        style: TextStyle(
                          color: Colors.green,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.green, width: 2),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
    if (pestInfo == null) return const SizedBox.shrink();

    // Define the fields we want to show, in order
    final fieldOrder = [
      'common_name',
      'category',
      'name',
      'bite_time',
      'breeding_sites',
      'diseases',
      'control_methods',
      'public_actions',
      'risk_radius',
    ];

    final displayedFields = <MapEntry<String, dynamic>>[];

    for (final fieldKey in fieldOrder) {
      if (pestInfo!.containsKey(fieldKey)) {
        final value = pestInfo![fieldKey];
        if (value != null && value.toString().trim().isNotEmpty) {
          displayedFields.add(MapEntry(fieldKey, value));
        }
      }
    }

    if (displayedFields.isEmpty) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.orange[50],
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.orange.shade200),
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline, color: Colors.orange[700]),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'No detailed information available for this pest.',
                style: TextStyle(fontSize: 14),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.green.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: displayedFields.map((e) => _buildInfoRow(e.key, e.value)).toList(),
      ),
    );
  }

  Widget _buildInfoRow(String key, dynamic value) {
    // Check if this field should be formatted as bullet points
    final needsBulletPoints = [
      'control_methods',
      'public_actions',
      'breeding_sites',
    ].contains(key);

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  _getIconForKey(key),
                  size: 18,
                  color: Colors.green[700],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _formatKey(key),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: Colors.green[800],
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: needsBulletPoints
                ? _buildBulletPoints(value.toString())
                : Text(
                    value.toString(),
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.black87,
                      height: 1.5,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildBulletPoints(String text) {
    // Split by common delimiters: newlines, semicolons, or numbered lists
    final items = text
        .split(RegExp(r'[\n;]|(?:\d+\.)'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    if (items.length <= 1) {
      // Not a list, display as normal text
      return Text(
        text,
        style: const TextStyle(
          fontSize: 14,
          color: Colors.black87,
          height: 1.5,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: items.map((item) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 6),
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: Colors.green[600],
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  item,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.black87,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  IconData _getIconForKey(String key) {
    final lowerKey = key.toLowerCase();
    if (lowerKey.contains('name')) return Icons.label;
    if (lowerKey.contains('category')) return Icons.category;
    if (lowerKey.contains('bite') || lowerKey.contains('time')) return Icons.schedule;
    if (lowerKey.contains('breed')) return Icons.water_drop;
    if (lowerKey.contains('disease')) return Icons.coronavirus;
    if (lowerKey.contains('control') || lowerKey.contains('treatment'))
      return Icons.medical_services;
    if (lowerKey.contains('public') || lowerKey.contains('action'))
      return Icons.people;
    if (lowerKey.contains('risk') || lowerKey.contains('radius'))
      return Icons.warning;
    if (lowerKey.contains('desc')) return Icons.description;
    if (lowerKey.contains('symptom')) return Icons.healing;
    if (lowerKey.contains('prevent')) return Icons.shield;
    if (lowerKey.contains('habitat') || lowerKey.contains('location'))
      return Icons.location_on;
    if (lowerKey.contains('size')) return Icons.straighten;
    return Icons.info;
  }
}
