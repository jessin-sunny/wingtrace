import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class CommunityFeedScreen extends StatelessWidget {
  const CommunityFeedScreen({super.key});

  Future<String?> _loadCommunityId() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;

    final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    if (!doc.exists) return null;

    final data = doc.data();
    return data?['communityID']?.toString() ?? data?['communityId']?.toString();
  }

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
      appBar: AppBar(
        title: const Text('Community Feed'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: FutureBuilder<String?>(
        future: _loadCommunityId(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final communityId = snapshot.data;
          if (communityId == null || communityId.isEmpty) {
            return const Center(child: Text('No community assigned.'));
          }

          final postsQuery = FirebaseFirestore.instance
              .collection('communities')
              .doc(communityId)
              .collection('posts')
              .orderBy('timestamp', descending: true);

          return StreamBuilder<QuerySnapshot>(
            stream: postsQuery.snapshots(),
            builder: (context, postSnapshot) {
              if (postSnapshot.hasError) {
                final message = postSnapshot.error?.toString() ?? 'Failed to load posts.';
                return Center(child: Text(message));
              }
              if (postSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

                  final docs = postSnapshot.data?.docs ?? [];
              if (docs.isEmpty) {
                return const Center(child: Text('No posts yet.'));
              }

              return ListView.separated(
                padding: const EdgeInsets.all(20),
                itemCount: docs.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final data = docs[index].data() as Map<String, dynamic>;
                  final pestType = data['pestType']?.toString() ?? 'Unknown Pest';
                  final pestName = data['pest_name']?.toString();
                  final category = data['category']?.toString();
                  final confidence = data['confidence'];
                  final status = data['status']?.toString() ?? 'pending';
                  final timestamp = data['timestamp'];

                  return Card(
                    elevation: 3,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            pestType,
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          if (pestName != null || category != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              [pestName, category].whereType<String>().where((v) => v.isNotEmpty).join(' • '),
                              style: const TextStyle(color: Colors.black54),
                            ),
                          ],
                          const SizedBox(height: 6),
                          Text(
                            _timeAgoFromTimestamp(timestamp),
                            style: const TextStyle(color: Colors.grey),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Chip(
                                label: Text(status.toUpperCase()),
                                backgroundColor: status == 'verified'
                                    ? Colors.green[100]
                                    : Colors.orange[100],
                              ),
                              const SizedBox(width: 8),
                              if (confidence is num)
                                Chip(
                                  label: Text('Conf ${(confidence * 100).toStringAsFixed(0)}%'),
                                  backgroundColor: Colors.orange[100],
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Shared without exact house location.',
                            style: TextStyle(color: Colors.grey, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
