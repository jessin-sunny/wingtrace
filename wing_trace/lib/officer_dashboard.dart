import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'community_feed_screen.dart';
import 'login_screen.dart';

class OfficerDashboard extends StatefulWidget {
  const OfficerDashboard({super.key});

  @override
  State<OfficerDashboard> createState() => _OfficerDashboardState();
}

class _OfficerDashboardState extends State<OfficerDashboard> {
  static const LatLng _fallbackCenter = LatLng(9.5916, 76.5222);

  String _timeAgoFromTimestamp(dynamic timestamp) {
    DateTime? time;

    if (timestamp is Timestamp) {
      time = timestamp.toDate();
    } else if (timestamp is String) {
      time = DateTime.tryParse(timestamp);
    }

    if (time == null) return "Just now";

    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return "Just now";
    if (diff.inMinutes < 60) return "${diff.inMinutes} mins ago";
    if (diff.inHours < 24) return "${diff.inHours} hours ago";
    if (diff.inDays < 7) return "${diff.inDays} days ago";

    return "${time.day}/${time.month}/${time.year}";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text("Officer Command Center"),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => Navigator.pushReplacement(
              context, MaterialPageRoute(builder: (context) => const LoginPage())
            ),
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(FirebaseAuth.instance.currentUser?.uid)
            .snapshots(),
        builder: (context, snapshot) {
          final userData = snapshot.data?.data() as Map<String, dynamic>?;
          final communityId = userData?['communityID']?.toString();

          return StreamBuilder<DocumentSnapshot>(
            stream: communityId == null
                ? null
                : FirebaseFirestore.instance
                    .collection('communities')
                    .doc(communityId)
                    .snapshots(),
            builder: (context, communitySnapshot) {
              final communityData = communitySnapshot.data?.data() as Map<String, dynamic>?;
              final communityName = communityData?['name']?.toString() ?? 'Community';
              final district = communityData?['district']?.toString() ?? 'Unknown district';

              return SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Regional Overview", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                    Text("Community: $communityName", style: const TextStyle(color: Colors.grey)),
                    Text("District: $district", style: const TextStyle(color: Colors.grey)),
                    const SizedBox(height: 16),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: communityId == null
                        ? null
                        : () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const CommunityFeedScreen()),
                            ),
                    icon: const Icon(Icons.people_alt_outlined, color: Colors.white),
                    label: const Text('Open Community Feed', style: TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                Row(
                  children: [
                    _statCard("Total Users", "—", Colors.blue),
                    _statCard("Active Alerts", "—", Colors.red),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _statCard("Detections/Day", "—", Colors.green),
                    _statCard("High Risk", "—", Colors.orange),
                  ],
                ),
                const SizedBox(height: 26),

                const Text("Active Alerts", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                _buildAlertsList(communityId),

                const SizedBox(height: 26),

                const Text("Regional Activity Heatmap", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                    _buildHeatmap(communityId),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildAlertsList(String? communityId) {
    if (communityId == null || communityId.isEmpty) {
      return const Text("No community linked", style: TextStyle(color: Colors.grey));
    }

    final query = FirebaseFirestore.instance
        .collection('alerts')
        .where('communityID', isEqualTo: communityId)
        .orderBy('timestamp', descending: true)
        .limit(5);

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(12),
            child: LinearProgressIndicator(),
          );
        }

        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return const Text("No active alerts", style: TextStyle(color: Colors.grey));
        }

        return Column(
          children: docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final title = data['title']?.toString() ?? data['pestType']?.toString() ?? 'Alert';
            final subtitle = data['message']?.toString() ?? 'New detection reported';
            final time = _timeAgoFromTimestamp(data['timestamp']);
            return _alertItem(title, subtitle, time);
          }).toList(),
        );
      },
    );
  }

  Widget _buildHeatmap(String? communityId) {
    if (communityId == null || communityId.isEmpty) {
      return _heatmapPlaceholder("No community linked");
    }

    final postsQuery = FirebaseFirestore.instance
        .collection('communities')
        .doc(communityId)
        .collection('posts')
        .orderBy('timestamp', descending: true)
        .limit(200);

    return StreamBuilder<QuerySnapshot>(
      stream: postsQuery.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _heatmapPlaceholder("Loading map...");
        }

        final docs = snapshot.data?.docs ?? [];
        final markers = <Marker>{};

        for (final doc in docs) {
          final data = doc.data() as Map<String, dynamic>;
          final lat = data['lat'];
          final lng = data['lng'];
          if (lat is num && lng is num) {
            final position = LatLng(lat.toDouble(), lng.toDouble());
            markers.add(
              Marker(
                markerId: MarkerId(doc.id),
                position: position,
                infoWindow: InfoWindow(title: data['pestType']?.toString()),
              ),
            );
          }
        }

        if (markers.isEmpty) {
          return _heatmapPlaceholder("No geo-tagged detections yet");
        }

        return ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: SizedBox(
            height: 220,
            child: GoogleMap(
              initialCameraPosition: const CameraPosition(
                target: _fallbackCenter,
                zoom: 12,
              ),
              markers: markers,
              zoomControlsEnabled: false,
              myLocationButtonEnabled: false,
            ),
          ),
        );
      },
    );
  }

  Widget _heatmapPlaceholder(String message) {
    return Container(
      height: 200,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.green.withOpacity(0.5)),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.map_outlined, size: 50, color: Colors.green),
            Text(message, style: const TextStyle(color: Colors.green)),
          ],
        ),
      ),
    );
  }

  // Widget for Statistic Cards
  Widget _statCard(String title, String value, Color color) {
    return Expanded(
      child: Card(
        elevation: 4,
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey)),
              Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
            ],
          ),
        ),
      ),
    );
  }

  // Widget for Individual Alerts
  Widget _alertItem(String title, String subtitle, String time) {
    return Card(
      color: Colors.red[50],
      child: ListTile(
        leading: const Icon(Icons.warning_amber_rounded, color: Colors.red),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
        subtitle: Text(subtitle),
        trailing: Text(time, style: const TextStyle(fontSize: 10)),
      ),
    );
  }
}