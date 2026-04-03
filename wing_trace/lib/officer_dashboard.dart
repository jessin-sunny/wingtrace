import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'community_feed_screen.dart';
import 'login_screen.dart';
import 'profile_screen.dart';

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
      backgroundColor: const Color(0xFFFDFBE7),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(FirebaseAuth.instance.currentUser?.uid)
            .snapshots(),
        builder: (context, snapshot) {
          final userData = snapshot.data?.data() as Map<String, dynamic>?;
          final communityId = userData?['communityID']?.toString() ?? userData?['communityId']?.toString();
          final officerName = userData?['name']?.toString() ?? 'Officer';
          final profilePic = userData?['profile_pic']?.toString() ?? userData?['profilePic']?.toString() ?? '';

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
              final officerType = userData?['officerType']?.toString();
              final officers = communityData?['officers'] is Map
                  ? Map<String, dynamic>.from(communityData?['officers'])
                  : <String, dynamic>{};
              final otherType = officerType == 'health' ? 'agriculture' : 'health';
              final otherOfficerId = officers[otherType]?.toString();

              return SingleChildScrollView(
                child: Column(
                  children: [
                    _buildHeader(officerName, profilePic),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 10),
                          _buildProfileSection(
                            officerName: officerName,
                            officerType: officerType,
                            email: userData?['emailid']?.toString(),
                            phone: userData?['phoneno']?.toString(),
                          ),
                          const SizedBox(height: 16),
                          _buildOfficerInfoCard(
                            officerType: officerType,
                            communityName: communityName,
                            district: district,
                            otherType: otherType,
                            otherOfficerId: otherOfficerId,
                          ),
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
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              _statCardStream(
                                title: "Total Users",
                                color: Colors.blue,
                                stream: _totalUsersStream(communityId),
                              ),
                              _statCardStream(
                                title: "Active Alerts",
                                color: Colors.red,
                                stream: _activeAlertsStream(communityId),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              _statCardStream(
                                title: "Detections/Day",
                                color: Colors.green,
                                stream: _detectionsTodayStream(communityId),
                              ),
                              _statCardStream(
                                title: "High Risk",
                                color: Colors.orange,
                                stream: _highRiskStream(communityId),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          const Text("Active Alerts", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          _buildAlertsList(communityId),
                          const SizedBox(height: 22),
                          const Text("Regional Activity Heatmap", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 10),
                          _buildHeatmap(communityId),
                          const SizedBox(height: 80),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildHeader(String name, String profilePicAsset) {
    return Stack(
      children: [
        Container(
          height: 200,
          decoration: const BoxDecoration(
            color: Colors.green,
            borderRadius: BorderRadius.only(bottomLeft: Radius.circular(100), bottomRight: Radius.circular(100)),
          ),
        ),
        Positioned(
          top: 40,
          right: 12,
          child: IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: () => Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const LoginPage()),
            ),
          ),
        ),
        Positioned(
          top: 60,
          left: 0,
          right: 0,
          child: Column(
            children: [
              CircleAvatar(
                radius: 45,
                backgroundColor: Colors.white,
                child: CircleAvatar(
                  radius: 42,
                  backgroundColor: Colors.grey[200],
                  backgroundImage: profilePicAsset.isNotEmpty ? AssetImage(profilePicAsset) : null,
                  child: profilePicAsset.isEmpty ? const Icon(Icons.person, size: 50, color: Colors.grey) : null,
                ),
              ),
              const SizedBox(height: 10),
              Text(name, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProfileSection({
    required String officerName,
    String? officerType,
    String? email,
    String? phone,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.green, width: 1),
        color: Colors.white,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.person_outline, color: Colors.green),
              const SizedBox(width: 8),
              const Text('Profile', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const Spacer(),
              TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ProfileScreen()),
                ),
                child: const Text('View'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(officerName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          if (officerType != null && officerType.isNotEmpty)
            Text(officerType, style: const TextStyle(color: Colors.grey)),
          if (email != null && email.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(
                children: [
                  const Icon(Icons.email, size: 16, color: Colors.green),
                  const SizedBox(width: 8),
                  Expanded(child: Text(email)),
                ],
              ),
            ),
          if (phone != null && phone.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(
                children: [
                  const Icon(Icons.call, size: 16, color: Colors.green),
                  const SizedBox(width: 8),
                  Expanded(child: Text(phone)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildOfficerInfoCard({
    required String communityName,
    required String district,
    required String otherType,
    required String? otherOfficerId,
    String? officerType,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.green, width: 1),
        color: Colors.white,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.verified_user, color: Colors.green),
              const SizedBox(width: 8),
              const Text('Officer Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          const SizedBox(height: 10),
          Text("Community: $communityName", style: const TextStyle(color: Colors.black87)),
          Text("District: $district", style: const TextStyle(color: Colors.black87)),
          const SizedBox(height: 12),
          _buildCounterpartCard(otherType, otherOfficerId),
        ],
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

  Widget _buildCounterpartCard(String otherType, String? otherOfficerId) {
    if (otherOfficerId == null || otherOfficerId.isEmpty) {
      return Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Text("No $otherType officer assigned", style: const TextStyle(color: Colors.grey)),
        ),
      );
    }

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(otherOfficerId).get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 6),
            child: LinearProgressIndicator(),
          );
        }

        final data = snapshot.data?.data() as Map<String, dynamic>?;
        final name = data?['name']?.toString() ?? otherOfficerId;
        final phone = data?['phoneno']?.toString();
        final email = data?['emailid']?.toString();

        return Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("$otherType officer", style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.person, size: 18, color: Colors.green),
                    const SizedBox(width: 8),
                    Expanded(child: Text(name)),
                  ],
                ),
                if (phone != null && phone.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Row(
                      children: [
                        const Icon(Icons.call, size: 18, color: Colors.green),
                        const SizedBox(width: 8),
                        Expanded(child: Text(phone)),
                      ],
                    ),
                  ),
                if (email != null && email.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Row(
                      children: [
                        const Icon(Icons.email, size: 18, color: Colors.green),
                        const SizedBox(width: 8),
                        Expanded(child: Text(email)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Stream<int> _totalUsersStream(String? communityId) {
    if (communityId == null || communityId.isEmpty) {
      return Stream<int>.value(0);
    }

    return FirebaseFirestore.instance.collection('users').snapshots().map((snapshot) {
      return snapshot.docs.where((doc) {
        final data = doc.data();
        final id = data['communityID']?.toString() ?? data['communityId']?.toString();
        final role = data['role']?.toString().toLowerCase();
        return id == communityId && role != 'officer' && role != 'admin';
      }).length;
    });
  }

  Stream<int> _activeAlertsStream(String? communityId) {
    if (communityId == null || communityId.isEmpty) {
      return Stream<int>.value(0);
    }

    return FirebaseFirestore.instance
        .collection('alerts')
        .where('communityID', isEqualTo: communityId)
        .where('status', isEqualTo: 'active')
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  Stream<int> _detectionsTodayStream(String? communityId) {
    if (communityId == null || communityId.isEmpty) {
      return Stream<int>.value(0);
    }

    final since = Timestamp.fromDate(DateTime.now().subtract(const Duration(hours: 24)));
    return FirebaseFirestore.instance
        .collection('communities')
        .doc(communityId)
        .collection('posts')
        .where('timestamp', isGreaterThanOrEqualTo: since)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  Stream<int> _highRiskStream(String? communityId) {
    if (communityId == null || communityId.isEmpty) {
      return Stream<int>.value(0);
    }

    return FirebaseFirestore.instance
        .collection('communities')
        .doc(communityId)
        .collection('posts')
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.where((doc) {
            final data = doc.data();
            final risk = data['risk']?.toString().toLowerCase();
            final defaultRisk = data['default_risk']?.toString().toLowerCase();
            return risk == 'high' || defaultRisk == 'high';
          }).length;
        });
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

  Widget _statCardStream({
    required String title,
    required Color color,
    required Stream<int> stream,
  }) {
    return Expanded(
      child: Card(
        elevation: 4,
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: StreamBuilder<int>(
            stream: stream,
            builder: (context, snapshot) {
              final value = snapshot.data?.toString() ?? '—';
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
                ],
              );
            },
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