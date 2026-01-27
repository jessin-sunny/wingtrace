import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class PestChatbotScreen extends StatefulWidget {
  const PestChatbotScreen({super.key});

  @override
  State<PestChatbotScreen> createState() => _PestChatbotScreenState();
}

class _PestChatbotScreenState extends State<PestChatbotScreen> {
  final TextEditingController _controller = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _isLoading = false;
  String? _userProfilePic; // 🔹 Added to store user image path

  static const String _apiKey = String.fromEnvironment('API_KEY');
  static const String _baseUrl = "https://api.groq.com/openai/v1/chat/completions";

  @override
  void initState() {
    super.initState();
    _fetchUserAvatar(); // 🔹 Fetch the profile pic on startup
  }

  // 🔹 Logic to fetch the real profile pic path from Firestore
  Future<void> _fetchUserAvatar() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    try {
      final userDoc = await _firestore.collection('users').doc(uid).get();
      if (userDoc.exists) {
        setState(() {
          // Matches your new DB field "profilePic"
          _userProfilePic = userDoc.data()?['profile_pic']; 
        });
      }
    } catch (e) {
      debugPrint("Error fetching avatar: $e");
    }
  }

  Future<void> _saveToFirebase(String role, String text) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    await _firestore.collection('users').doc(uid).collection('chats').add({
      "role": role,
      "text": text,
      "timestamp": FieldValue.serverTimestamp(),
    });
  }

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty) return;
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    _controller.clear();
    setState(() => _isLoading = true);

    try {
      await _saveToFirebase("user", text);
      final historySnap = await _firestore
          .collection('users')
          .doc(uid)
          .collection('chats')
          .orderBy('timestamp', descending: true)
          .limit(6)
          .get();

      final history = historySnap.docs.reversed.map((doc) => {
        "role": doc['role'] == 'user' ? 'user' : 'assistant',
        "content": doc['text']
      }).toList();

      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'Authorization': 'Bearer $_apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          "model": "llama-3.1-8b-instant",
          "messages": [
            {"role": "system", "content": "You are Tracy, a friendly pest expert for WingTrace."},
            ...history
          ],
        }),
      );

      if (response.statusCode == 200) {
        final botResponse = jsonDecode(response.body)['choices'][0]['message']['content'];
        await _saveToFirebase("bot", botResponse);
      }
    } catch (e) {
      debugPrint("Chat Error: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteChatHistory() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    try {
      final chatCollection = _firestore.collection('users').doc(uid).collection('chats');
      final snapshots = await chatCollection.get();
      WriteBatch batch = _firestore.batch();
      for (var doc in snapshots.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Memory cleared!")));
    } catch (e) {
      debugPrint("Delete Error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = _auth.currentUser?.uid;

    return Scaffold(
      backgroundColor: const Color(0xFFFDFBE7),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Tracy", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
            Text("AI Pest Assistant", style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.8))),
          ],
        ),
        backgroundColor: Colors.green[700],
        foregroundColor: Colors.white,
        elevation: 4,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep_rounded),
            onPressed: () => _showDeleteConfirmation(),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: uid == null 
              ? const Center(child: Text("Login to chat with Tracy"))
              : StreamBuilder<QuerySnapshot>(
                  stream: _firestore
                      .collection('users')
                      .doc(uid)
                      .collection('chats')
                      .orderBy('timestamp', descending: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Colors.green));
                    final docs = snapshot.data!.docs;
                    return ListView.builder(
                      reverse: true,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                      itemCount: docs.length,
                      itemBuilder: (context, index) {
                        final data = docs[index].data() as Map<String, dynamic>;
                        return _buildChatBubble(data['text'] ?? "", data['role'] == 'user');
                      },
                    );
                  },
                ),
          ),
          if (_isLoading) 
            const Padding(
              padding: EdgeInsets.only(bottom: 10),
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.green),
            ),
          _buildQuickActions(),
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildChatBubble(String text, bool isUser) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) 
            const CircleAvatar(
              radius: 14, 
              backgroundColor: Colors.green, 
              child: Icon(Icons.smart_toy_rounded, size: 16, color: Colors.white)
            ),
          const SizedBox(width: 8),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isUser ? Colors.green[600] : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20),
                  topRight: const Radius.circular(20),
                  bottomLeft: Radius.circular(isUser ? 20 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  )
                ],
              ),
              child: Text(
                text,
                style: TextStyle(
                  color: isUser ? Colors.white : Colors.black87,
                  fontSize: 15,
                  height: 1.4,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          if (isUser) 
            CircleAvatar(
              radius: 14, 
              backgroundColor: Colors.grey[300], 
              // 🔹 Logic: Use the fetched asset image or a default icon
              backgroundImage: (_userProfilePic != null && _userProfilePic!.isNotEmpty) 
                  ? AssetImage(_userProfilePic!) 
                  : null,
              child: (_userProfilePic == null || _userProfilePic!.isEmpty) 
                  ? const Icon(Icons.person, size: 16, color: Colors.black54) 
                  : null,
            ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    final questions = ["Aedes Prevention?", "Dengue Symptoms?", "Repellents?"];
    return SizedBox(
      height: 45,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: questions.map((q) => Padding(
          padding: const EdgeInsets.only(right: 8),
          child: ActionChip(
            backgroundColor: Colors.white,
            side: const BorderSide(color: Colors.green),
            label: Text(q, style: const TextStyle(fontSize: 12, color: Colors.green, fontWeight: FontWeight.bold)),
            onPressed: () => _sendMessage(q),
          ),
        )).toList(),
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 30),
      decoration: const BoxDecoration(color: Colors.transparent),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, -2))
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(left: 15),
                child: TextField(
                  controller: _controller,
                  decoration: const InputDecoration(
                    hintText: "Type a message...",
                    border: InputBorder.none,
                  ),
                  onSubmitted: (val) => _sendMessage(val),
                ),
              ),
            ),
            GestureDetector(
              onTap: () => _sendMessage(_controller.text),
              child: CircleAvatar(
                radius: 20,
                backgroundColor: Colors.green[700],
                child: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Reset Conversation?"),
        content: const Text("This will permanently wipe Tracy's memory of this chat."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Keep it")),
          ElevatedButton(
            onPressed: () { _deleteChatHistory(); Navigator.pop(context); },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text("Clear"),
          ),
        ],
      ),
    );
  }
}