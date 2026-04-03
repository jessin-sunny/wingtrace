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

  Future<Map<String, dynamic>?> _loadUserContext() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;
    final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    if (!doc.exists) return null;
    final data = doc.data();
    if (data == null) return null;
    return {
      'uid': uid,
      'role': data['role']?.toString(),
      'name': data['name']?.toString(),
      'communityId': data['communityID']?.toString() ?? data['communityId']?.toString(),
    };
  }

  Future<void> _showOfficerPostDialog(BuildContext context, String communityId, String authorId, String? authorName) async {
    final TextEditingController pestController = TextEditingController();
    final TextEditingController noteController = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Post to Community'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: pestController,
              decoration: const InputDecoration(labelText: 'Title / Pest Type'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: noteController,
              decoration: const InputDecoration(labelText: 'Message'),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final title = pestController.text.trim();
              if (title.isEmpty) return;
              await FirebaseFirestore.instance
                  .collection('communities')
                  .doc(communityId)
                  .collection('posts')
                  .add({
                'authorID': authorId,
                'authorName': authorName,
                'pestType': title,
                'note': noteController.text.trim(),
                'status': 'verified',
                'timestamp': FieldValue.serverTimestamp(),
              });
              if (context.mounted) Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Post', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    return Scaffold(
      backgroundColor: const Color(0xFFFDFBE7),
      appBar: AppBar(
        title: const Text('Community Feed'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: FutureBuilder<Map<String, dynamic>?>(
        future: _loadUserContext(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final userContext = snapshot.data;
          final communityId = userContext?['communityId']?.toString();
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

              final currentUserId = userContext?['uid']?.toString();
              return Stack(
                children: [
                  ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
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
                  final authorId = data['authorID']?.toString();
                  final authorName = data['authorName']?.toString();
                  final note = data['note']?.toString();
                  final isMe = authorId != null && authorId == currentUserId;

                  final senderLabel = isMe
                      ? 'You'
                      : (authorName?.isNotEmpty == true
                          ? authorName!
                          : 'Member ${authorId?.substring(0, 6) ?? 'unknown'}');

                  return Align(
                    alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 320),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isMe ? Colors.green[200] : Colors.white,
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(18),
                          topRight: const Radius.circular(18),
                          bottomLeft: Radius.circular(isMe ? 18 : 4),
                          bottomRight: Radius.circular(isMe ? 4 : 18),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.06),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          )
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            senderLabel,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isMe ? Colors.green[900] : Colors.green[800],
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            pestType,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          if (pestName != null || category != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              [pestName, category].whereType<String>().where((v) => v.isNotEmpty).join(' • '),
                              style: const TextStyle(color: Colors.black54, fontSize: 12),
                            ),
                          ],
                          if (note != null && note.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(note, style: const TextStyle(color: Colors.black87)),
                          ],
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              Chip(
                                label: Text(status.toUpperCase()),
                                backgroundColor: status == 'verified'
                                    ? Colors.green[100]
                                    : Colors.orange[100],
                                labelStyle: const TextStyle(fontSize: 11),
                                padding: const EdgeInsets.symmetric(horizontal: 6),
                              ),
                              if (confidence is num)
                                Chip(
                                  label: Text('Conf ${(confidence * 100).toStringAsFixed(0)}%'),
                                  backgroundColor: Colors.blue[50],
                                  labelStyle: const TextStyle(fontSize: 11),
                                  padding: const EdgeInsets.symmetric(horizontal: 6),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'No exact house location shared',
                                style: TextStyle(color: Colors.grey, fontSize: 10),
                              ),
                              Text(
                                _timeAgoFromTimestamp(timestamp),
                                style: const TextStyle(color: Colors.grey, fontSize: 10),
                              ),
                            ],
                          )
                        ],
                      ),
                    ),
                  );
                    },
                  ),
                  if (userContext?['role'] == 'officer')
                    Positioned(
                      bottom: 20,
                      right: 20,
                      child: FloatingActionButton.extended(
                        onPressed: () => _showOfficerPostDialog(
                          context,
                          communityId,
                          userContext?['uid']?.toString() ?? '',
                          userContext?['name']?.toString(),
                        ),
                        backgroundColor: Colors.green,
                        icon: const Icon(Icons.edit, color: Colors.white),
                        label: const Text('New Post', style: TextStyle(color: Colors.white)),
                      ),
                    ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
